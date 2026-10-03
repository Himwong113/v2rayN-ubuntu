# v2rayN Setup Guide (Linux)

From repo clone to working VPN. Tested on Ubuntu/Debian, .NET 10 SDK.

## 1. Build & install

```bash
./setup.sh --install-system-deps --build
```

This installs system deps, .NET 10 SDK (to `~/.dotnet`), and builds the Avalonia desktop app.

### Common errors

**`E: Could not get lock /var/lib/apt/lists/lock`**
Another apt process is running. Check with `pgrep -a apt`. If a stale `apt update` is hung:

```bash
sudo kill <pid>
sudo rm -f /var/lib/apt/lists/lock /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend
sudo dpkg --configure -a
```

Only remove lock files **after** the stale process is dead.

**`error NETSDK1100: To build a project targeting Windows...`**
The full solution contains a Windows-only WPF project. `setup.sh` already works around this by restoring only the Desktop project — make sure you have the latest `setup.sh`.

## 2. Install Xray core (required)

The app needs the xray binary, it is not bundled. `setup.sh` installs it automatically
(to skip: `./setup.sh --no-xray`). It places:

- `xray` binary → `v2rayN/v2rayN.Desktop/bin/Debug/net10.0/bin/xray/` (executable)
- `geoip.dat` + `geosite.dat` → **both** `bin/xray/` **and** `bin/`

The `bin/` copy is required: the app runs xray with working dir = `bin/`, and xray
resolves geo files from there. Missing it gives:
`failed to load geosite: GOOGLE > ... failed to open file: geosite.dat`.

Without the core you get: `The Core file (file name: xray) was not found` and delay always `-1 ms`.

### Manual install (if setup.sh download fails)

```bash
cd /tmp
# bypass proxy env vars — local proxy isn't running yet, that's what we're fixing
env -u http_proxy -u https_proxy -u all_proxy \
  curl -fsSL -o xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
BIN=~/Desktop/v2rayN-ubuntu/v2rayN/v2rayN.Desktop/bin/Debug/net10.0/bin
mkdir -p "$BIN/xray"
unzip -o xray.zip xray geoip.dat geosite.dat -d "$BIN/xray"
chmod +x "$BIN/xray/xray"
cp "$BIN/xray/"{geoip.dat,geosite.dat} "$BIN/"
```

## 3. Run the app

```bash
./setup.sh --run --no-restore
```

Or the built binary directly (faster startup):

```bash
~/Desktop/v2rayN-ubuntu/v2rayN/v2rayN.Desktop/bin/Debug/net10.0/v2rayN
```

Kill an old instance first if restarting:

```bash
pkill -x v2rayN
```

## 4. In-app settings

1. **Add a server** — Servers → import from clipboard / subscription URL, or add manually (VLESS, VMess, etc.).
2. **Select server** — click the node, press Enter to set active.
3. **Restart core** — right-click tray icon → Restart core (needed after adding xray binary).
4. **Test delay** — select server, press `Ctrl+T` (or right-click → test). Must show real ms, not `-1`. `-1` = core missing or dead node.
5. **Enable system proxy** — tray icon right-click → System proxy → **Set system proxy**. Without this your traffic bypasses the proxy and your real IP still shows.

## 5. Verify

```bash
# system proxy on?
gsettings get org.gnome.system.proxy mode   # should print 'manual'

# proxy working?
curl -s --socks5 127.0.0.1:10808 https://api.ip.sb/geoip   # should show server country, not yours
```

Browser notes:
- **Chrome/Chromium**: uses system proxy automatically.
- **Firefox**: Settings → Network Settings → "Use system proxy settings".

## 6. Start on login (optional)

Enable desktop startup with `./service/install.sh`. If you previously installed
the background proxy service, run `sudo ./service/install.sh` to switch to the
desktop app. See [service/README.md](service/README.md) for options.

Autostart file created at `~/.config/autostart/v2rayN.desktop` — app launches on login.

In-app settings worth enabling (Settings → Option setting):
- **Auto start / start on boot** — if offered by app
- **Set system proxy on start** — so proxy is active without manual tray click
- **Start minimized to tray**

Disable autostart: delete `~/.config/autostart/v2rayN.desktop`.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `xray was not found` | core missing | step 2 |
| delay `-1 ms` | core missing or dead node | step 2, or pick another node |
| `failed to open file: geosite.dat` | dat files missing from `bin/` (not just `bin/xray/`) | step 2 `cp` line |
| curl `Failed to connect to 127.0.0.1 port 10808` during download | stale proxy env vars, proxy not running yet | prefix download with `env -u http_proxy -u https_proxy -u all_proxy` |
| IP still shows real location | system proxy off | step 4.5 |
| Firefox not proxied | ignores system proxy | step 5 browser notes |
