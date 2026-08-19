# PearDock

A Plasma 6.7 dock based on Wave Task Manager, combining macOS-style
magnification with stable live previews for minimized windows. Fullscreen windows
on non-current virtual desktops are also shown when they are the desktop's only
window.

All launchers, running applications, and previews share one layout, so the icon
under the pointer and its neighbours animate as a single continuous dock.
Magnified icons are rendered in a transparent dock surface above normal windows,
so they can extend beyond the Plasma panel without increasing its thickness.

## Requirements

- KDE Plasma 6.7
- Wave Task Manager's KDE QML plugin (`org.vicko.wavetask`)
- Wayland for live window thumbnails

## Install

```bash
chmod +x install.sh uninstall.sh
./install.sh
systemctl --user restart plasma-plasmashell.service
```

Add **PearDock** to the desktop, then remove the separate
task-manager and preview widgets. WaveTask's QML sources are included directly in
this package; installation does not copy or patch another plasmoid.

## KWin Glass compatibility

If [KWin Glass](https://github.com/4v3ngR/kwin-effects-glass) is installed,
add `org.kde.plasmashell` to **Window classes** in the Glass settings and select
**Blur all except matching**. This prevents Glass from filling PearDock's
transparent zoom area. Keep any classes already present in that list. If the
list is empty, the equivalent command is:

```bash
kwriteconfig6 --file kwinrc --group Effect-blurplus \
  --key WindowClasses org.kde.plasmashell
```

Disable and re-enable the Glass desktop effect after applying the change. Glass
will remain enabled for other applications.

## Remove

```bash
./uninstall.sh
systemctl --user restart plasma-plasmashell.service
```

Wave Task Manager remains credited under GPL-2.0-or-later in the package metadata.
