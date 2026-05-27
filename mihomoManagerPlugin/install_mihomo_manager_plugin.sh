#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mihomoManagerPlugin"
DST_DIR="$HOME/.config/DankMaterialShell/plugins/mihomoManager"

if [[ ! -d "$SRC_DIR" ]]; then
    echo "找不到插件源码目录：$SRC_DIR" >&2
    exit 1
fi

mkdir -p "$HOME/.config/DankMaterialShell/plugins"
rm -rf "$DST_DIR"
cp -r "$SRC_DIR" "$DST_DIR"

echo "已安装到：$DST_DIR"

if command -v dms >/dev/null 2>&1; then
    dms ipc call plugins reload mihomoManager || true
    echo "已尝试热重载插件。若未显示，请执行：dms restart"
else
    echo "未找到 dms 命令。请确认 dms-shell 已安装。"
fi
