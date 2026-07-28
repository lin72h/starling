CC = gcc
CFLAGS = -Wall -I/usr/include/libdrm
LDFLAGS = -ldrm -lgbm -lEGL -lGLESv2

all: drm_screenshot

drm_screenshot: drm_screenshot.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f drm_screenshot

.PHONY: all clean
