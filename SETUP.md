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

The app needs the xray binary, it is not bundled:

```bash
cd /tmp
curl -fsSL -o xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
mkdir -p v2rayN/v2rayN.Desktop/bin/Debug/net10.0/bin/xray
unzip -o xray.zip xray geoip.dat geosite.dat \
  -d ~/Desktop/v2rayN/v2rayN/v2rayN.Desktop/bin/Debug/net10.0/bin/xray
chmod +x ~/Desktop/v2rayN/v2rayN/v2rayN.Desktop/bin/Debug/net10.0/bin/xray/xray
```

Without this you get: `The Core file (file name: xray) was not found` and delay always `-1 ms`.

## 3. Run the app

```bash
./setup.sh --run --no-restore
```

Or the built binary directly (faster startup):

```bash
~/Desktop/v2rayN/v2rayN/v2rayN.Desktop/bin/Debug/net10.0/v2rayN
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

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `xray was not found` | core missing | step 2 |
| delay `-1 ms` | core missing or dead node | step 2, or pick another node |
| IP still shows real location | system proxy off | step 4.5 |
| Firefox not proxied | ignores system proxy | step 5 browser notes |
