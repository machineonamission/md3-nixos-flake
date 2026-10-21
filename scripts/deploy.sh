#!bash

# Deploy the NixOS config: sync the git repo into /etc/nixos, then rebuild.
# Usage: bash scripts/deploy.sh

set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$(id -u)" -ne 0 ]; then
    echo "Elevating privileges..."
    exec run0 "$0" "$@"
fi

# We're root now: sync the repo into the deployed config dir, then rebuild.
echo "Syncing ${REPO} -> /etc/nixos ..."
rsync -a --exclude='.git' --exclude='.git/*' "${REPO}/" /etc/nixos/
cd /etc/nixos
echo "Building and switching to the new system..."
nixos-rebuild switch
