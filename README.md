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

PearDock requests blur only behind its visible background. When Glass has
**Ignore content blur region** or forced decoration blur enabled, Glass must
exclude the window titled `PearDock` from those overrides and honor its declared
blur region. The [PearDock Glass build](https://github.com/LoneDev6/kwin-glass-peardock)
contains both exceptions; access to that private repository is required.

Keep Plasma out of Glass's excluded window classes so the Start menu can also
blur, and disable the stock Blur effect when using Glass. After upgrading Glass,
log out and log back in: unloading and reloading the effect can leave the old
library in KWin's memory.

The larger transparent dock surface remains available for magnified icons.
Hover previews use separate popup windows, while icon zoom stays in the dock
surface. Upgrading PearDock with `./install.sh` preserves the existing applet
configuration and launchers.

## Remove

```bash
./uninstall.sh
systemctl --user restart plasma-plasmashell.service
```

Wave Task Manager remains credited under GPL-2.0-or-later in the package metadata.
