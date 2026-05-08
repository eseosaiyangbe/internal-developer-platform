#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/platform-identity.sh"

LABEL="com.${IDP_PLATFORM_SLUG}.k3s-platform-recovery"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="${HOME}/Library/Logs"
OUT_LOG="${LOG_DIR}/${IDP_PLATFORM_SLUG}-k3s-platform-recovery.out.log"
ERR_LOG="${LOG_DIR}/${IDP_PLATFORM_SLUG}-k3s-platform-recovery.err.log"
RUNTIME_ROOT="${HOME}/.local/share/${IDP_PLATFORM_SLUG}/k3s-platform-recovery"
RUNTIME_SCRIPTS_DIR="${RUNTIME_ROOT}/scripts"

mkdir -p "${HOME}/Library/LaunchAgents" "${LOG_DIR}" "${RUNTIME_SCRIPTS_DIR}"

cp "${SCRIPT_DIR}/platform-identity.sh" "${RUNTIME_SCRIPTS_DIR}/platform-identity.sh"
cp "${SCRIPT_DIR}/bootstrap-k3s-vault-secrets.sh" "${RUNTIME_SCRIPTS_DIR}/bootstrap-k3s-vault-secrets.sh"
cp "${SCRIPT_DIR}/recover-k3s-vault.sh" "${RUNTIME_SCRIPTS_DIR}/recover-k3s-vault.sh"
cp "${SCRIPT_DIR}/recover-k3s-platform.sh" "${RUNTIME_SCRIPTS_DIR}/recover-k3s-platform.sh"
cp "${ROOT_DIR}/scripts/vault-k3s-values.yaml" "${RUNTIME_SCRIPTS_DIR}/vault-k3s-values.yaml"
chmod +x \
  "${RUNTIME_SCRIPTS_DIR}/bootstrap-k3s-vault-secrets.sh" \
  "${RUNTIME_SCRIPTS_DIR}/recover-k3s-vault.sh" \
  "${RUNTIME_SCRIPTS_DIR}/recover-k3s-platform.sh"

cat > "${PLIST_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-lc</string>
    <string>export PATH="$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"; cd '${RUNTIME_ROOT}' &amp;&amp; '${RUNTIME_SCRIPTS_DIR}/recover-k3s-platform.sh' --quiet</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${RUNTIME_ROOT}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>60</integer>
  <key>StandardOutPath</key>
  <string>${OUT_LOG}</string>
  <key>StandardErrorPath</key>
  <string>${ERR_LOG}</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)" "${PLIST_PATH}" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "${PLIST_PATH}"
launchctl kickstart -k "gui/$(id -u)/${LABEL}" >/dev/null

echo "Installed LaunchAgent ${LABEL}"
echo "Plist: ${PLIST_PATH}"
echo "Runtime bundle: ${RUNTIME_ROOT}"
echo "Logs:"
echo "  ${OUT_LOG}"
echo "  ${ERR_LOG}"
