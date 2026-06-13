#!/bin/bash
set -euo pipefail

#####################################
# CONFIG
#####################################
CHECK_URL="https://raw.githubusercontent.com/codexchangee/rhel10-exam-env-setup-all/refs/heads/main/check.sh"
INSTALL_PATH="/usr/bin/paper-check"

#####################################
# PRECHECKS
#####################################
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run this script as root"
  exit 1
fi

#####################################
# INSTALL
#####################################
echo "[paper-check] Downloading checker script..."
curl -fsSL "$CHECK_URL" -o "$INSTALL_PATH" \
  || { echo "Failed to download check.sh"; exit 1; }

chmod 755 "$INSTALL_PATH"

#####################################
# VERIFY
#####################################
if command -v paper-check >/dev/null 2>&1; then
  echo "[paper-check] Installed successfully at $INSTALL_PATH"
else
  echo "[paper-check] Installation failed"
  exit 1
fi

echo "[paper-check] Done. You can now run:"
echo "  paper-check"
