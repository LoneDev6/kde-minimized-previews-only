# Minimized Window Previews

A compact Plasma 6.7 widget that shows only minimized windows as live previews.

Keep KDE's native Icons-only Task Manager in the panel, then add this widget directly after it.

```bash
chmod +x install.sh uninstall.sh
./install.sh
systemctl --user restart plasma-plasmashell.service
```

Remove the old `Icons-only Task Manager with Minimized Previews` widget from the panel and add `Minimized Window Previews`.
