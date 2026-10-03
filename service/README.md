# Start v2rayN automatically

The default installer starts the **full desktop app** after you log in to your
Linux desktop. It also adds v2rayN to your applications menu.

```bash
./service/install.sh
```

If you installed the previous background proxy service, switch to desktop startup
with this command in your terminal:

```bash
sudo ./service/install.sh
```

This disables and stops `v2rayn-proxy.service` to release the proxy ports, installs
desktop startup for the user who invoked sudo, and opens the app as that user.
If v2rayN is already running, use its tray icon to open its window.

The desktop app needs a logged-in graphical session. With automatic desktop
login configured on your device, it launches after the device boots and logs in.
The app controls its proxy core and system proxy settings as usual. If you want
the window visible on startup, turn off **Start minimized to tray** in the app.

Build the app first with `./setup.sh --build` if necessary. The installer defaults
to `v2rayN/v2rayN.Desktop/bin/Debug/net10.0` in this checkout. For another build:

```bash
./service/install.sh --app-dir /path/to/v2rayN
```

Use `--no-start` to configure startup without opening the app now. When running
as root directly, specify your normal desktop account with `--user USER`.

The installer creates these files (using XDG directories when run as your user):

- `~/.config/autostart/v2rayN.desktop`: starts the app after login.
- `~/.local/share/applications/v2rayN.desktop`: applications menu entry.
- `~/.local/share/v2rayN/start.sh`: launcher that sets `DOTNET_ROOT` when the
  user-local .NET installation from `setup.sh` is present.

Keep the app directory available and re-run the installer after moving it.
Disable desktop startup by deleting `~/.config/autostart/v2rayN.desktop`.

## Optional background proxy

For a proxy that runs before desktop login, the Xray installer remains available:

```bash
sudo ./service/install.sh --proxy
```

Quit v2rayN and disable its desktop autostart first. Select an Xray server and
start its proxy once beforehand to generate `binConfigs/config.json`. This mode
uses that config and the core in `bin/xray/`. It supports Xray proxy mode;
sing-box, TUN mode, subscription updates, and desktop system proxy settings need
separate setup. Configure applications to use the local proxy port.

```bash
systemctl status v2rayn-proxy
sudo journalctl -u v2rayn-proxy -f
sudo systemctl restart v2rayn-proxy
sudo systemctl disable --now v2rayn-proxy
```

An existing `xray.service` has a separate name. Services and the desktop app
cannot share the same listening ports. The default desktop installer stops only
the `v2rayn-proxy.service` installed by these scripts.

References: [desktop autostart specification](https://specifications.freedesktop.org/autostart/latest/),
[systemd service documentation](https://github.com/systemd/systemd/blob/main/man/systemd.service.xml),
and [Xray environment variables](https://xtls.github.io/en/config/env.html).
