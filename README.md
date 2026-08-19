# Minimized Window Previews

A compact MacOS-like Plasma 6.7 widget that shows minimized windows as stable live previews. It
also shows one preview for each non-current virtual desktop containing exactly
one fullscreen task window.

Keep KDE's native Icons-only Task Manager in the panel, then add this widget directly after it.

```bash
chmod +x install.sh uninstall.sh
./install.sh
systemctl --user restart plasma-plasmashell.service
```

Remove the old `Icons-only Task Manager with Minimized Previews` widget from the panel and add `Minimized Window Previews`.

<img width="782" height="78" alt="image" src="https://github.com/user-attachments/assets/54bcd48b-a867-44cb-9dbc-4485a4616e07" />

The widget remains an applet in Plasma's native panel; it does not create a
panel, dock, KWin script, service, or system file. Installation is local under
`~/.local/share/plasma/plasmoids/`.

On Wayland, thumbnails use Plasma 6.7's `ScreencastingRequest` and the stable
KWin window UUID exposed as `WinIdList`. Plasma controls whether an application
permits capture, so protected windows can fall back to their application icon.
The task model intentionally excludes skip-taskbar windows (panels, desktop,
popups and similar shell surfaces). Virtual desktops are global; previews are
not filtered per monitor.
