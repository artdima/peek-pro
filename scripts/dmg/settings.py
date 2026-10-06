# dmgbuild settings for the release DMG; make-dmg.sh passes the paths with -D.
app = defines["app"]

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}
hide_extensions = ["Peek Pro.app"]
icon = app + "/Contents/Resources/AppIcon.icns"
background = defines["background"]

# The bounds take in the 32 pt title bar, leaving 640 × 360 for the background;
# it runs 16 pt lower, so a shorter title bar leaves no gap.
window_rect = ((200, 160), (640, 392))
icon_size = 128
# Over a picture Finder draws the names black, whatever the theme. The white
# names are in the background; Finder's own, small, fall into the dark under them.
text_size = 10
icon_locations = {"Peek Pro.app": (170, 150), "Applications": (470, 150)}
