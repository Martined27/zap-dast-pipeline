#!/usr/bin/env bash
set -euo pipefail

echo "[install-addons] Pre-installing ZAP Automation Framework add-ons..."
/zap/zap.sh -cmd -silent \
  -addoninstall automation \
  -addoninstall spiderAjax \
  -addoninstall reports \
  -addoninstall replacer \
  -addoninstall graphql \
  -addoninstall requestor
echo "[install-addons] Add-ons installed successfully."
