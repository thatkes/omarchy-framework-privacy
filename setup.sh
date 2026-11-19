#!/bin/bash
# One-file installer/uninstaller for the Framework privacy bar widget.
# Safe to run more than once: install converges on the same state every time.

set -euo pipefail

PLUGIN_ID="thatkes.framework-privacy"
ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
CLI_LINK="$HOME/.local/bin/framework-privacy"

usage() {
  cat <<EOF
Usage: ${0##*/} [install|uninstall|status]

  install     (default) install the cache service, CLI link and bar widget
  uninstall   remove the service, CLI link, bar entry and disable the plugin
  status      show what is currently installed
EOF
}

fail() {
  echo "${0##*/}: $*" >&2
  exit 1
}

# Remove every bar entry for this plugin, leaving all other widgets untouched.
bar_without_plugin() {
  jq --arg id "$PLUGIN_ID" '
    if (.bar and .bar.layout and (.bar.layout | type) == "object") then
      .bar.layout |= with_entries(
        .value |= map(select((if (.id | type) == "string" then .id else "" end) != $id))
      )
    else . end
  ' "$SHELL_CONFIG"
}

require_framework() {
  grep -qis framework /sys/class/dmi/id/{sys_vendor,product_name,board_vendor} \
    || fail "this system does not identify itself as a Framework computer"
}

do_install() {
  require_framework
  command -v jq >/dev/null || fail "jq is required"
  [[ -f $SHELL_CONFIG ]] || fail "missing $SHELL_CONFIG"

  omarchy pkg add framework-system

  sudo install -Dm755 \
    "$ROOT_DIR/system/framework-privacy-cache" \
    /usr/local/libexec/framework-privacy-cache
  sudo install -Dm644 \
    "$ROOT_DIR/system/framework-privacy-cache.service" \
    /etc/systemd/system/framework-privacy-cache.service
  sudo systemctl daemon-reload
  sudo systemctl enable --now framework-privacy-cache.service

  mkdir -p "$HOME/.local/bin"
  ln -sfn "$ROOT_DIR/framework-privacy" "$CLI_LINK"

  omarchy plugin enable "$PLUGIN_ID" >/dev/null 2>&1 || true
  sleep 0.5

  # Exactly one bar instance now shows both privacy icons.
  tmp=$(mktemp)
  bar_without_plugin > "$tmp"
  jq --arg id "$PLUGIN_ID" '.bar.layout.centerEnd += [{"id": $id}]' "$tmp" > "$tmp.next"
  mv "$tmp.next" "$SHELL_CONFIG"
  rm -f "$tmp"

  echo "Framework privacy indicators installed and enabled."
  do_status
}

do_uninstall() {
  sudo systemctl disable --now framework-privacy-cache.service || true
  sudo rm -f \
    /etc/systemd/system/framework-privacy-cache.service \
    /usr/local/libexec/framework-privacy-cache
  sudo systemctl daemon-reload || true

  rm -f "$CLI_LINK"

  if [[ -f $SHELL_CONFIG ]]; then
    tmp=$(mktemp)
    bar_without_plugin > "$tmp"
    mv "$tmp" "$SHELL_CONFIG"
  fi
  omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1 || true

  echo "Framework privacy indicators uninstalled."
}

do_status() {
  printf 'cache service: %s\n' "$(systemctl is-active framework-privacy-cache.service 2>/dev/null || echo inactive)"
  if [[ -L $CLI_LINK ]]; then
    printf 'cli: %s -> %s\n' "$CLI_LINK" "$(readlink "$CLI_LINK")"
  else
    printf 'cli: not linked\n'
  fi
  if [[ -f $SHELL_CONFIG ]]; then
    printf 'bar instances: %s\n' "$(jq -r --arg id "$PLUGIN_ID" '
      [.bar.layout[]?[]? | select((if (.id | type) == "string" then .id else "" end) == $id)] | length
    ' "$SHELL_CONFIG")"
  fi
  if command -v framework-privacy >/dev/null 2>&1; then
    framework-privacy status || true
  fi
}

case "${1:-install}" in
  install)   do_install ;;
  uninstall) do_uninstall ;;
  status)    do_status ;;
  -h|--help) usage ;;
  *)         usage >&2; exit 2 ;;
esac
