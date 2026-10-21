#!bash

set -euo pipefail

# cd to script parent dir, flake dir
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
# this changes flake.lock
nix flake update
# add and commit
git add -A
git commit -m "test.sh"
nixos-build test --flake .