// cbjitter — measure the frame-callback cadence a Wayland compositor
// delivers to a continuously-committing client.
//
// The client is deliberately trivial: two wl_shm buffers, repaint (memset)
// and commit on every frame callback, log CLOCK_MONOTONIC at each callback.
// No GL, no text shaping, no pty — whatever jitter shows up here is the
// compositor's scheduling, not the app's. Output: count, mean, p50, p95,
// p99, max interval in ms, plus the effective fps.
//
//   cc -O2 -o cbjitter cbjitter.c xdg-shell-protocol.c -lwayland-client -lrt
//   ./cbjitter <seconds> [width height]
#define _POSIX_C_SOURCE 200809L
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include "xdg-shell-client-protocol.h"

static struct wl_compositor *comp;
static struct wl_shm *shm;
static struct xdg_wm_base *wm;
static struct wl_surface *surf;
static struct xdg_surface *xsurf;
static struct xdg_toplevel *top;
static int W = 960, H = 600;
static int configured, running = 1;
static uint8_t *pix[2];
static struct wl_buffer *buf[2];
static int cur;
static double *samples;
static size_t nsamples, capsamples;
static struct timespec t_prev;

static void noop() {}
static void tl_bounds(void *d, struct xdg_toplevel *t, int32_t w, int32_t h) {}
static void tl_caps(void *d, struct xdg_toplevel *t, struct wl_array *c) {}
static void reg_remove(void *d, struct wl_registry *r, uint32_t name) {}

static void ping(void *d, struct xdg_wm_base *w, uint32_t serial) {
  xdg_wm_base_pong(w, serial);
}
static const struct xdg_wm_base_listener wm_lis = { ping };

static void xconf(void *d, struct xdg_surface *s, uint32_t serial) {
  xdg_surface_ack_configure(s, serial);
  configured = 1;
}
static const struct xdg_surface_listener xs_lis = { xconf };

static void tconf(void *d, struct xdg_toplevel *t, int32_t w, int32_t h,
                  struct wl_array *st) {}
static void tclose(void *d, struct xdg_toplevel *t) { running = 0; }
static const struct xdg_toplevel_listener tl_lis = { tconf, tclose, tl_bounds, tl_caps };

static void reg(void *d, struct wl_registry *r, uint32_t name,
                const char *iface, uint32_t ver) {
  if (!strcmp(iface, "wl_compositor"))
    comp = wl_registry_bind(r, name, &wl_compositor_interface, 4);
  else if (!strcmp(iface, "wl_shm"))
    shm = wl_registry_bind(r, name, &wl_shm_interface, 1);
  else if (!strcmp(iface, "xdg_wm_base"))
    wm = wl_registry_bind(r, name, &xdg_wm_base_interface, 1);
}
static const struct wl_registry_listener reg_lis = { reg, reg_remove };

static struct wl_buffer *mkbuf(int i) {
  int stride = W * 4, size = stride * H;
  char tmpl[] = "/tmp/cbjitter-XXXXXX";
  int fd = mkstemp(tmpl);
  unlink(tmpl);
  if (ftruncate(fd, size) < 0) { perror("ftruncate"); exit(1); }
  pix[i] = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, size);
  struct wl_buffer *b = wl_shm_pool_create_buffer(
      pool, 0, W, H, stride, WL_SHM_FORMAT_XRGB8888);
  wl_shm_pool_destroy(pool);
  close(fd);
  return b;
}

static void frame_done(void *d, struct wl_callback *cb, uint32_t ms);
static const struct wl_callback_listener frame_lis = { frame_done };

static void submit(void) {
  cur ^= 1;
  // full-surface repaint: alternate shade so every frame carries real damage
  memset(pix[cur], cur ? 0x30 : 0x60, (size_t)W * H * 4);
  wl_surface_attach(surf, buf[cur], 0, 0);
  wl_surface_damage(surf, 0, 0, W, H);
  struct wl_callback *cb = wl_surface_frame(surf);
  wl_callback_add_listener(cb, &frame_lis, NULL);
  wl_surface_commit(surf);
}

static void frame_done(void *d, struct wl_callback *cb, uint32_t ms) {
  wl_callback_destroy(cb);
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  if (t_prev.tv_sec) {
    double dt = (now.tv_sec - t_prev.tv_sec) * 1e3 +
                (now.tv_nsec - t_prev.tv_nsec) / 1e6;
    if (nsamples == capsamples) {
      capsamples *= 2;
      samples = realloc(samples, capsamples * sizeof(double));
    }
    samples[nsamples++] = dt;
  }
  t_prev = now;
  submit();
}

static int cmpd(const void *a, const void *b) {
  double x = *(const double *)a, y = *(const double *)b;
  return (x > y) - (x < y);
}

int main(int argc, char **argv) {
  double secs = argc > 1 ? atof(argv[1]) : 30.0;
  if (argc > 3) { W = atoi(argv[2]); H = atoi(argv[3]); }
  capsamples = 1 << 16;
  samples = malloc(capsamples * sizeof(double));

  struct wl_display *dpy = wl_display_connect(NULL);
  if (!dpy) { fprintf(stderr, "no wayland display\n"); return 1; }
  struct wl_registry *r = wl_display_get_registry(dpy);
  wl_registry_add_listener(r, &reg_lis, NULL);
  wl_display_roundtrip(dpy);
  if (!comp || !shm || !wm) { fprintf(stderr, "missing globals\n"); return 1; }
  xdg_wm_base_add_listener(wm, &wm_lis, NULL);

  surf = wl_compositor_create_surface(comp);
  xsurf = xdg_wm_base_get_xdg_surface(wm, surf);
  xdg_surface_add_listener(xsurf, &xs_lis, NULL);
  top = xdg_surface_get_toplevel(xsurf);
  xdg_toplevel_add_listener(top, &tl_lis, NULL);
  xdg_toplevel_set_title(top, "cbjitter");
  xdg_toplevel_set_app_id(top, "cbjitter");
  wl_surface_commit(surf);
  while (!configured && wl_display_dispatch(dpy) != -1) {}

  buf[0] = mkbuf(0);
  buf[1] = mkbuf(1);
  submit();

  struct timespec start, now;
  clock_gettime(CLOCK_MONOTONIC, &start);
  while (running && wl_display_dispatch(dpy) != -1) {
    clock_gettime(CLOCK_MONOTONIC, &now);
    if (now.tv_sec - start.tv_sec >= (time_t)secs) break;
  }

  if (nsamples < 32) { fprintf(stderr, "too few samples (%zu)\n", nsamples); return 1; }
  // drop the first second: mapping/first-frame transients
  size_t skip = 0; double acc = 0;
  while (skip < nsamples && acc < 1000.0) acc += samples[skip++];
  double *s = samples + skip; size_t n = nsamples - skip;
  qsort(s, n, sizeof(double), cmpd);
  double sum = 0; for (size_t i = 0; i < n; i++) sum += s[i];
  printf("n=%zu mean=%.2fms fps=%.1f p50=%.2f p90=%.2f p95=%.2f p99=%.2f max=%.2f\n",
         n, sum / n, 1000.0 / (sum / n),
         s[n / 2], s[(size_t)(n * 0.90)], s[(size_t)(n * 0.95)],
         s[(size_t)(n * 0.99)], s[n - 1]);
  return 0;
}
