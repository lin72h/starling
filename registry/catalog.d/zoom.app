[Starling App]
Id=zoom
Name=Zoom
Kind=host
Order=100
Glyph=videoCall
Color=4E8AD8
Exec=zoom
Install=zoom
Bins=/opt/zoom/ZoomLauncher
DesktopEntry=Zoom;zoom
# Qt/xcb on the in-tree X server (ZoomLauncher hardcodes QT_QPA_PLATFORM=xcb),
# so its window never carries a Wayland app_id — title is all there is.
TitleMatch=Zoom
DebUrl=https://zoom.us/client/latest/zoom_amd64.deb
DebMarker=opt/zoom/ZoomLauncher
Category=Work
Publisher=Zoom Communications
Subtitle=Video meetings and chat
Size=285 MB
Description=Zoom Workplace — meetings, team chat and screen sharing, installed from Zoom's official package.
