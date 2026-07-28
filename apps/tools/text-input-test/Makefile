# Minimal zwp_text_input_v3 test client — maps an SHM toplevel on the
# shell's compositor and prints every IME event (enter/preedit/commit).
# Usage:
#   make
#   sudo runuser -u $USER -- env XDG_RUNTIME_DIR=/run/user/1000 \
#     WAYLAND_DISPLAY=/run/user/1000/wayland-0 ./ti_client
PROTO_DIR := /usr/share/wayland-protocols

ti_client: ti_client.c text-input-v3-client.c xdg-shell-client.c
	gcc -o $@ $^ -lwayland-client

text-input-v3-client.h:
	wayland-scanner client-header $(PROTO_DIR)/unstable/text-input/text-input-unstable-v3.xml $@
text-input-v3-client.c: text-input-v3-client.h
	wayland-scanner private-code $(PROTO_DIR)/unstable/text-input/text-input-unstable-v3.xml $@
xdg-shell-client.h:
	wayland-scanner client-header $(PROTO_DIR)/stable/xdg-shell/xdg-shell.xml $@
xdg-shell-client.c: xdg-shell-client.h
	wayland-scanner private-code $(PROTO_DIR)/stable/xdg-shell/xdg-shell.xml $@

ti_client.c: text-input-v3-client.h xdg-shell-client.h

clean:
	rm -f ti_client *-client.c *-client.h
