// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

// A DMA-BUF-backed external texture for the GTK host: the GTK-embedder
// equivalent of GpuDmaBufRenderer's external-texture registry. An app hands
// over a dma-buf fd per frame (flgtk_dmabuf_texture_update, any thread); the
// engine's raster thread later calls populate() with the GL context current,
// where the buffer is imported once as an EGLImage bound to a GL texture —
// after that, frames in the same buffer need no GL work at all, because the
// imported image aliases the producer's GPU memory. Buffers are recognized
// across frames by (st_dev, st_ino), the same identity trick the desktop
// shell's LinuxTextureRegistry uses.

#define FLUTTER_LINUX_COMPILATION
#include "flutter_linux/fl_engine.h"
#include "flutter_linux/fl_texture_gl.h"
#include "flutter_linux/fl_texture_registrar.h"
#include "flutter_linux/fl_view.h"

#include <EGL/egl.h>
#include <sys/stat.h>
#include <unistd.h>

#include "DmaBufBridge.h"

#define FLGTK_GL_TEXTURE_2D 0x0DE1

// Provided by flgtk_host.c; the host struct itself stays private to it.
typedef struct FlGtkHost FlGtkHost;
extern FlView* flgtk_host_get_view(FlGtkHost* host);

// Imported buffers kept alive for reuse. A producer triple-buffers, and a
// video switch briefly overlaps two pools.
#define SLOT_COUNT 8

typedef struct {
  uint64_t dev;
  uint64_t ino;
  void* egl_image;
  uint32_t gl_name;
} BufferSlot;

struct _FlGtkDmaBufTexture {
  FlTextureGL parent_instance;

  GMutex mutex;
  // Pending frame, handed over by update(); owned fd, -1 when consumed.
  int pending_fd;
  int32_t pending_width;
  int32_t pending_height;
  int32_t pending_stride;
  uint32_t pending_fourcc;
  uint64_t pending_modifier;
  gboolean dirty;

  // What populate() last resolved (raster thread only).
  uint32_t current_name;
  int32_t current_width;
  int32_t current_height;

  BufferSlot slots[SLOT_COUNT];
  int slot_count;
  int evict_cursor;

  FlTextureRegistrar* registrar;
};

typedef struct _FlGtkDmaBufTexture FlGtkDmaBufTexture;

typedef struct {
  FlTextureGLClass parent_class;
} FlGtkDmaBufTextureClass;

G_DEFINE_TYPE(FlGtkDmaBufTexture,
              fl_gtk_dmabuf_texture,
              fl_texture_gl_get_type())

static gboolean fl_gtk_dmabuf_texture_populate(FlTextureGL* texture,
                                               uint32_t* target,
                                               uint32_t* name,
                                               uint32_t* width,
                                               uint32_t* height,
                                               GError** error) {
  (void)error;
  FlGtkDmaBufTexture* self = (FlGtkDmaBufTexture*)texture;

  g_mutex_lock(&self->mutex);
  gboolean dirty = self->dirty;
  int fd = -1;
  int32_t w = self->pending_width;
  int32_t h = self->pending_height;
  int32_t stride = self->pending_stride;
  uint32_t fourcc = self->pending_fourcc;
  uint64_t modifier = self->pending_modifier;
  if (dirty) {
    fd = self->pending_fd;
    self->pending_fd = -1;
    self->dirty = FALSE;
  }
  g_mutex_unlock(&self->mutex);

  if (dirty && fd >= 0) {
    uint64_t dev = 0, ino = 0;
    struct stat st;
    if (fstat(fd, &st) == 0) {
      dev = (uint64_t)st.st_dev;
      ino = (uint64_t)st.st_ino;
    }

    int found = -1;
    for (int i = 0; i < self->slot_count; i++) {
      if (self->slots[i].dev == dev && self->slots[i].ino == ino) {
        found = i;
        break;
      }
    }

    if (found < 0) {
      // The GL context is current here — safe to evict and to import.
      void* display = eglGetCurrentDisplay();
      int slot;
      if (self->slot_count < SLOT_COUNT) {
        slot = self->slot_count++;
      } else {
        slot = self->evict_cursor;
        self->evict_cursor = (self->evict_cursor + 1) % SLOT_COUNT;
        if (self->slots[slot].egl_image != NULL) {
          dmabuf_destroy_egl_image(display, self->slots[slot].egl_image);
        }
        if (self->slots[slot].gl_name != 0) {
          dmabuf_delete_gl_texture(self->slots[slot].gl_name);
        }
      }
      void* image = NULL;
      uint32_t tex = dmabuf_import_as_gl_texture(display, fd, w, h, stride,
                                                 fourcc, modifier, &image);
      if (tex != 0) {
        self->slots[slot].dev = dev;
        self->slots[slot].ino = ino;
        self->slots[slot].egl_image = image;
        self->slots[slot].gl_name = tex;
        found = slot;
      } else {
        if (self->slot_count == slot + 1) self->slot_count--;
      }
    }

    close(fd);

    if (found >= 0) {
      self->current_name = self->slots[found].gl_name;
      self->current_width = w;
      self->current_height = h;
    }
  }

  if (self->current_name == 0) {
    return FALSE;
  }
  *target = FLGTK_GL_TEXTURE_2D;
  *name = self->current_name;
  *width = (uint32_t)self->current_width;
  *height = (uint32_t)self->current_height;
  return TRUE;
}

static void fl_gtk_dmabuf_texture_dispose(GObject* object) {
  FlGtkDmaBufTexture* self = (FlGtkDmaBufTexture*)object;
  g_mutex_lock(&self->mutex);
  if (self->pending_fd >= 0) {
    close(self->pending_fd);
    self->pending_fd = -1;
  }
  g_mutex_unlock(&self->mutex);
  // EGLImages / GL names need the raster context to free; they are instead
  // recycled through the eviction cursor while the texture lives. A handful
  // leak at teardown — bounded by SLOT_COUNT per texture object.
  G_OBJECT_CLASS(fl_gtk_dmabuf_texture_parent_class)->dispose(object);
}

static void fl_gtk_dmabuf_texture_class_init(FlGtkDmaBufTextureClass* klass) {
  FL_TEXTURE_GL_CLASS(klass)->populate = fl_gtk_dmabuf_texture_populate;
  G_OBJECT_CLASS(klass)->dispose = fl_gtk_dmabuf_texture_dispose;
}

static void fl_gtk_dmabuf_texture_init(FlGtkDmaBufTexture* self) {
  g_mutex_init(&self->mutex);
  self->pending_fd = -1;
}

// ─── Public surface (opaque in FlutterGTKBridge.h) ─────────────────────────

FlGtkDmaBufTexture* flgtk_host_create_dmabuf_texture(FlGtkHost* host) {
  FlView* view = flgtk_host_get_view(host);
  if (view == NULL) return NULL;
  FlEngine* engine = fl_view_get_engine(view);
  if (engine == NULL) return NULL;
  FlTextureRegistrar* registrar = fl_engine_get_texture_registrar(engine);
  if (registrar == NULL) return NULL;

  FlGtkDmaBufTexture* texture =
      g_object_new(fl_gtk_dmabuf_texture_get_type(), NULL);
  texture->registrar = g_object_ref(registrar);
  if (!fl_texture_registrar_register_texture(registrar, FL_TEXTURE(texture))) {
    g_object_unref(texture->registrar);
    g_object_unref(texture);
    return NULL;
  }
  return texture;
}

int64_t flgtk_dmabuf_texture_get_id(FlGtkDmaBufTexture* texture) {
  return fl_texture_get_id(FL_TEXTURE(texture));
}

void flgtk_dmabuf_texture_update(FlGtkDmaBufTexture* texture,
                                 int fd,
                                 int32_t width,
                                 int32_t height,
                                 int32_t stride,
                                 uint32_t fourcc,
                                 uint64_t modifier) {
  g_mutex_lock(&texture->mutex);
  if (texture->pending_fd >= 0) {
    close(texture->pending_fd);
  }
  texture->pending_fd = fd;
  texture->pending_width = width;
  texture->pending_height = height;
  texture->pending_stride = stride;
  texture->pending_fourcc = fourcc;
  texture->pending_modifier = modifier;
  texture->dirty = TRUE;
  g_mutex_unlock(&texture->mutex);

  fl_texture_registrar_mark_texture_frame_available(texture->registrar,
                                                    FL_TEXTURE(texture));
}

void flgtk_dmabuf_texture_destroy(FlGtkDmaBufTexture* texture) {
  fl_texture_registrar_unregister_texture(texture->registrar,
                                          FL_TEXTURE(texture));
  g_object_unref(texture->registrar);
  g_object_unref(texture);
}
