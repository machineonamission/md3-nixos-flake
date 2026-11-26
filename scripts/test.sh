#!/usr/bin/env bash
# Build the whole system (all 3 boot modes) into ./result without root.
# Pass --update to bump flake.lock first.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
if [ "${1:-}" = --update ]; then nix flake update; fi
nixos-rebuild build --flake .#MelDesktop3
ls result/specialisation
