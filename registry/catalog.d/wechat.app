[Starling App]
Id=wechat
Name=WeChat
Kind=x11
Order=190
Glyph=externalApp
Color=4CB271
Exec=wechat-run
Bins=/opt/wechat/wechat;/usr/bin/wechat
DesktopEntry=wechat
# X11-only Qt app, so it lives alone inside a rootful Xwayland which is what
# actually talks to our compositor: one Wayland window for the whole X screen,
# app_id "Xwayland", title "Xwayland on :N". RenameWindows puts the app's real
# name back in the title bar and the window list.
WmClass=Xwayland
TitleMatch=Xwayland on;WeChat;Weixin
RenameWindows=1
Category=Work
Publisher=Tencent
Subtitle=Messaging and social
Description=The WeChat desktop client. Installed on the host; runs in its own rootful Xwayland because its embedded Chromium cannot present through the in-tree X server.
