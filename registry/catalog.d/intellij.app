[Starling App]
Id=intellij
Name=IntelliJ IDEA
Kind=host
Order=180
Glyph=vscode
Color=8A62C8
Exec=intellij
Install=intellij
Bins=/opt/idea/bin/idea;/usr/bin/idea
DesktopEntry=jetbrains-idea;jetbrains-idea-ce;idea
# The official tarball ships no .desktop entry (the IDE writes one itself, on
# first run, only if you ask it to), so there is no StartupWMClass on the host
# to read. This is what the JetBrains Runtime's Wayland toolkit actually sets.
WmClass=jetbrains-idea
# And this is the icon, since there is no theme entry pointing at one either.
Icon=/opt/idea/bin/idea.png
Category=Develop
Publisher=JetBrains
Subtitle=The Java and Kotlin IDE
Size=4.1 GB
Description=JetBrains' IDE for Java, Kotlin and the JVM — refactoring, debugging and build-tool integration. Runs on the JetBrains Runtime's Wayland toolkit as a software client. Installs the free Community feature set; since 2025.3 JetBrains ships one distribution, and a licence unlocks the Ultimate features in place rather than needing a different download. A large install — it bundles its own Java runtime and shared indexes.
