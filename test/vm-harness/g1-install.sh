#!/usr/bin/env bash
# STEP 1 — run the DOCUMENTED install instruction verbatim, then check whether a
# user could actually reach the Starling session from here. Surfaces gaps.
set -u
DEB="${1:?usage: g1-install.sh <deb>}"
line(){ echo; echo "===== $* ====="; }

line "GUEST"; . /etc/os-release; echo "$PRETTY_NAME  kernel $(uname -r)"

line "DOCUMENTED STEP:  sudo apt install ./$DEB"
sudo apt-get update -qq 2>/dev/null
sudo apt-get install -y "./$DEB"
echo "apt install exit: $?"
sudo apt-get check 2>&1 | tail -2

line "CAN THE USER REACH THE SESSION? (gap check)"
echo "-- session entry the .deb registered:"; ls /usr/share/wayland-sessions/ 2>/dev/null
echo "-- display manager present?"; \
  dpkg -l 2>/dev/null | grep -iE '^ii +(gdm3|lightdm|sddm)\b' | awk '{print "   "$2, $3}' || true
if ! dpkg -l 2>/dev/null | grep -qiE '^ii +(gdm3|lightdm|sddm)\b'; then
  echo "   NONE — no login manager installed"
fi
echo "-- default systemd target: $(systemctl get-default 2>/dev/null)"
echo "-- graphical.target reachable now? $(systemctl is-active graphical.target 2>/dev/null)"
echo
echo ">> GAP: the instruction says 'log out, choose Starling from the session menu,"
echo ">>      and sign in' — but a fresh server/cloud image has no display manager,"
echo ">>      so there is no login screen and no session menu to choose from."
line "DONE-STEP1"
