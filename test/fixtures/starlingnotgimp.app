# A decoy, used only by test/functional.py, overlaid onto a copy of the real
# catalog. It claims GIMP's binary as its own — the path the kernel reports
# for the Flathub GIMP, /app/bin/gimp-3.2 inside its sandbox — but declares a
# window class that matches nothing.
#
# It is what keeps the identity check honest. "GIMP's window was attributed to
# gimp" proves little on its own — the shell could be attributing any window to
# any running app and the assertion would still pass. With this decoy sharing
# the process, the shell must report process=true (its Bins match the live
# exe) and window=false (its app_id does not). That difference is the whole
# mechanism.
#
# /usr/bin/true is listed only so the record counts as installed; a host record
# is installed when one of its Bins exists, and the sandbox paths never do on
# the host. Kind stays host: a catalog record of kind flatpak with GIMP's id
# would replace the discovered GIMP record, and the check needs both.
[Starling App]
Id=starlingnotgimp
Name=Not GIMP
Kind=host
Order=9001
Glyph=externalApp
Color=808080
Exec=gimp
Bins=/usr/bin/true;/app/bin/gimp-3.2;/app/bin/gimp
WmClass=starling-decoy-matches-nothing
Category=System
Publisher=Starling
Subtitle=Not a real app
Description=A decoy used by the functional test suite.
