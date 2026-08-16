#!/bin/bash

set -euo pipefail

sudo systemctl disable --now framework-privacy-cache.service || true
sudo rm -f \
  /etc/systemd/system/framework-privacy-cache.service \
  /usr/local/libexec/framework-privacy-cache
sudo systemctl daemon-reload

echo "Framework microphone privacy cache was removed."
echo "Remove the shell plugin separately with: omarchy plugin remove chalkers.framework-microphone"
