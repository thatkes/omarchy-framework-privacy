#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ ! -e /sys/class/dmi/id/product_name ]] || ! grep -qi framework /sys/class/dmi/id/product_name; then
  echo "This system does not identify itself as a Framework computer." >&2
  exit 1
fi

omarchy pkg add framework-system

sudo install -Dm755 \
  "$ROOT_DIR/system/framework-privacy-cache" \
  /usr/local/libexec/framework-privacy-cache
sudo install -Dm644 \
  "$ROOT_DIR/system/framework-privacy-cache.service" \
  /etc/systemd/system/framework-privacy-cache.service
sudo systemctl daemon-reload
sudo systemctl enable --now framework-privacy-cache.service

echo "Framework microphone privacy cache is installed and active."
