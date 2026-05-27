# Mihomo Manager for Dank Material Shell

A local Dank Material Shell widget for managing a user-level `mihomo.service`.

## Features

- Show mihomo service state in DankBar.
- Show TUN status by checking the `mihomo` network interface.
- Start, stop, and restart `mihomo.service`.
- Test mixed-port proxy connectivity and TUN direct connectivity.
- Read mihomo REST API from `external-controller`.
- Show current proxy group and current node.
- Search and page through all nodes.
- Switch node for a `select` proxy group.
- Read subscription quota from `subscription-userinfo`.
- Show current node latency in DankBar and popout.
- Test latency for the current node or all nodes on the current page.

## Default Assumptions

```yaml
mixed-port: 7890
external-controller: 127.0.0.1:9090
tun:
  device: mihomo
```

The plugin does not modify `~/.config/mihomo/config.yaml`.

## Installation

```bash
mkdir -p ~/.config/DankMaterialShell/plugins
cp -r mihomoManagerPlugin ~/.config/DankMaterialShell/plugins/mihomoManager

dms ipc call plugins reload mihomoManager
```

If runtime reload does not work, restart DMS:

```bash
dms restart
```

Then open DMS Settings → Plugins, enable `Mihomo Manager`, and add it to DankBar or Control Center.

## Requirements

- `dms-shell`
- `mihomo`
- `curl`
- `python3`
- user service named `mihomo.service`
- `external-controller: 127.0.0.1:9090` in mihomo config

## Latency Display

Version 1.1.2 adds latency display. The bar shows current-node latency after the first automatic delay test. The popout provides:

- `当前延迟`: test the currently selected node.
- `本页测速`: test all nodes currently visible after search/pagination.

The default delay test URL is:

```text
https://www.gstatic.com/generate_204
```

You can change `Delay Test URL`, `Delay Timeout Ms`, `Auto Delay Test`, and `Show Delay In Bar` in plugin settings.

## Node Switching Notes

Only `select` proxy groups are suitable for manual switching. `url-test` and `fallback` groups are normally managed by mihomo automatically.

If the plugin shows the wrong proxy group, open plugin settings and change `Proxy Group` to the actual group name in your mihomo config, for example:

- `default`
- `自动选择`
- `故障转移`

## Subscription Traffic Notes

Remaining traffic is not mihomo's real-time traffic. The plugin reads quota from:

```text
subscription-userinfo: upload=1234; download=2234; total=1024000; expire=2218532293
```

`expire=` may be empty. In that case the plugin still shows used/remaining/total traffic and displays `无到期信息`.

Manual check:

```bash
curl -fsSIL -A 'clash.meta' '你的订阅链接' | grep -i subscription-userinfo
```

## Troubleshooting

Check mihomo API:

```bash
curl -s http://127.0.0.1:9090/proxies
```

Check delay endpoint manually:

```bash
NODE='你的节点名' python3 - <<'PY'
import os, urllib.parse
node = os.environ.get('NODE', '')
print('http://127.0.0.1:9090/proxies/' + urllib.parse.quote(node, safe='') + '/delay?url=https%3A%2F%2Fwww.gstatic.com%2Fgenerate_204&timeout=5000')
PY
```

Check user service:

```bash
systemctl --user status mihomo.service
```

Check TUN interface:

```bash
ip link show mihomo
```


## Outbound Traffic Display

Version 1.2.1 adds an optional external/proxy traffic display. It reads mihomo `/connections` and estimates active external traffic by excluding connections whose chain contains `DIRECT`, `REJECT`, `REJECT-DROP`, or `PASS`.

The display is tied to mihomo service state:

- If `mihomo.service` is active and the option is enabled, DankBar may show `外网 N条 ↑... ↓...`.
- If you stop mihomo from the plugin or from systemd, the plugin clears that text and stops refreshing external traffic.
- If the option is set to `false`, no external traffic text is shown in DankBar.

Settings:

- `Show External Traffic In Bar`: `true` / `false`.
- `External Traffic Refresh Ms`: default `3000`.

This is runtime active-connection traffic, not subscription quota. Subscription quota still comes from `subscription-userinfo`.
