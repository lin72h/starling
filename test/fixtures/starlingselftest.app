# A fake app, used only by test/functional.py. It is overlaid onto a COPY of
# the real catalog at test time (test/functional.sh) and never ships.
#
# It exists so the install/remove loop can be tested without a vendor, a
# download, or anything on the machine worth breaking — the loop under test is
# ours (a record appears, the launcher and dock move), not apt's. Testing that
# against a real app means uninstalling real software to prove a button works,
# which is how the author of this file uninstalled the user's GIMP.
[Starling App]
Id=starlingselftest
Name=Starling Self Test
Kind=host
Order=9000
Glyph=externalApp
Color=808080
Exec=starlingselftest
# The binary is a copy of `sleep`, and keeps that NAME on purpose:
# coreutils here is uutils' multi-call binary, which dispatches on
# argv[0], so a copy called anything else exits immediately.
Bins=/tmp/starling-selftest/bin/sleep
Category=System
Publisher=Starling
Subtitle=Not a real app
Description=A placeholder used by the functional test suite.
