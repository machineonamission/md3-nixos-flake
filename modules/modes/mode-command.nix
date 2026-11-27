# `mode` — show / switch the boot mode (all modes). See the help text below.
{ pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "mode" ''
      set -euo pipefail
      sys=/nix/var/nix/profiles/system
      current() { basename "$(readlink -f /run/current-system)" | grep -oE -- '-(saver|headless)-' | tr -d - || echo normal; }
      path() { if [ "$1" = normal ]; then echo "$sys"; else echo "$sys/specialisation/$1"; fi; }
      case "''${1:-}" in
        "") echo "current: $(current)"; exit 0 ;;
        normal|saver|headless) target=$1; how=test ;;
        boot|once) target=''${2:?usage: mode $1 normal|saver|headless}; how=$1 ;;
        *) cat <<'USAGE'
      usage:
        mode                       show the running mode
        mode normal|saver|headless switch live now (not kept across reboot)
        mode once <mode>           boot into <mode> on the NEXT boot only
        mode boot <mode>           make <mode> the default boot entry
      USAGE
           exit 1 ;;
      esac
      [ -e "$(path "$target")" ] || { echo "unknown mode: $target" >&2; exit 1; }
      if [ "$how" = test ]; then
        exec sudo "$(path "$target")/bin/switch-to-configuration" test
      fi
      gen=$(readlink "$sys" | grep -oE '[0-9]+')
      entry="nixos-generation-$gen.conf"
      [ "$target" = normal ] || entry="nixos-generation-$gen-specialisation-$target.conf"
      if [ "$how" = once ]; then exec sudo bootctl set-oneshot "$entry"; else exec sudo bootctl set-default "$entry"; fi
    '')
  ];
}
