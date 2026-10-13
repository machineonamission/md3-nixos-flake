#!bash

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Elevating privileges..."
    exec run0 "$0" "$@"
fi
cd /etc/nixos