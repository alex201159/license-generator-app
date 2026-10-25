#!/bin/sh
set -eu

app_bundle="${TARGET_BUILD_DIR:?}/${WRAPPER_NAME:?}"
if [ ! -d "$app_bundle" ]; then
  exit 0
fi

# Copied or synced bundles can carry metadata that macOS code signing rejects.
# Restrict cleanup to the generated app and preserve all other attributes.
/usr/bin/xattr -dr com.apple.FinderInfo "$app_bundle"
/usr/bin/xattr -dr com.apple.ResourceFork "$app_bundle"
