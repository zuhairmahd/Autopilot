#!/usr/bin/env bash
set -euo pipefail

# This script installs the latest release of PowerShell for Linux
# 1. Download latest tarball
# 2. Extract to /usr/local/share/powershell
# 3. Symlink /usr/local/bin/pwsh
# 4. Verify installation

RELEASE_URL="https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
DOWNLOAD_URL=$(curl -sL "$RELEASE_URL" | grep -oE 'https://[^" ]+linux-x64.tar.gz' | head -n 1)

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "Failed to find download URL for PowerShell" >&2
  exit 1
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

curl -L "$DOWNLOAD_URL" -o "$tmpdir/powershell.tar.gz"

install_dir="/usr/local/share/powershell"
mkdir -p "$install_dir"

tar -xzf "$tmpdir/powershell.tar.gz" -C "$install_dir"

ln -sf "$install_dir/pwsh" /usr/local/bin/pwsh

pwsh --version
