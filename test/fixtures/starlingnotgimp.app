# A decoy, used only by test/functional.py, overlaid onto a copy of the real
# catalog. It shares GIMP's binary but declares a window class that matches
# nothing.
#
# It is what keeps the identity check honest. "GIMP's window was attributed to
# gimp" proves little on its own — the shell could be attributing any window to
# any running app and the assertion would still pass. With this decoy running
# on the same process, the shell must report process=true (its Bins match) and
# window=false (its app_id does not). That difference is the whole mechanism.
[Starling App]
Id=starlingnotgimp
Name=Not GIMP
Kind=host
Order=9001
Glyph=externalApp
Color=808080
Exec=gimp
Bins=/usr/bin/gimp-3.2;/usr/bin/gimp
WmClass=starling-decoy-matches-nothing
Category=System
Publisher=Starling
Subtitle=Not a real app
Description=A decoy used by the functional test suite.
