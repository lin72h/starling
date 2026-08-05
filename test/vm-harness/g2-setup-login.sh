#!/usr/bin/env bash
# STEP 2 — the gap fix + a faithful sign-in. Installs GDM (Ubuntu's default,
# Wayland-capable, lists /usr/share/wayland-sessions), boots to graphical, and
# logs the user into the Starling session. Autologin is used only to drive the
# sign-in non-interactively; it still goes DM -> PAM -> logind seat -> the shipped
# /usr/libexec/starling-session, exactly like a manual "pick Starling, sign in".
set -u
line(){ echo; echo "===== $* ====="; }

line "GAP FIX: install a login manager (gdm3)"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gdm3
echo "gdm3 install exit: $?"

line "boot to graphical + reproduce the sign-in (autologin into Starling)"
sudo systemctl set-default graphical.target
sudo install -d -m 755 /etc/gdm3
sudo tee /etc/gdm3/custom.conf >/dev/null <<'EOF'
[daemon]
WaylandEnable=true
AutomaticLoginEnable=true
AutomaticLogin=tester
EOF
# tell accountsservice the user's chosen session is Starling
sudo install -d -m 755 /var/lib/AccountsService/users
sudo tee /var/lib/AccountsService/users/tester >/dev/null <<'EOF'
[User]
Session=starling
SystemAccount=false
EOF
echo "session menu now offers:"; ls /usr/share/wayland-sessions/
echo "configured. (caller will reboot and wait for the session)"
line "DONE-STEP2"
