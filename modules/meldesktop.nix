# Boot modes + shared values.
#
# ONE system, three systemd-boot entries (NixOS specialisations):
#   normal   (default entry) — full desktop, everything on the dGPU, no local LLM
#   saver    "NixOS (saver)" — same desktop, but userspace renders on the iGPU
#            (Vulkan + GL) so the dGPU's VRAM stays free for llama-swap
#   headless "NixOS (headless)" — raw TTY only; llama-swap, opencode serve,
#            openrgb etc. start at boot. Meant for: ssh in, switch, use remotely
#
# Each specialisation re-evaluates the whole config with `meldesktop.mode`
# changed, and modules switch on it with `lib.mkIf` (desktop.nix,
# headless.nix). Reading `config` inside mkIf is fine; it's only `imports` that
# can't depend on config.
#
#   sudo nixos-rebuild switch --flake .   # install: all 3 entries, activates normal
#   mode                                  # which mode am I in?
#   mode saver | mode headless | mode normal   # live switch
#   mode once headless / mode boot headless    # next boot only / default boot
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.meldesktop) mode;
in
{
  options.meldesktop = {
    mode = lib.mkOption {
      type = lib.types.enum [
        "normal"
        "saver"
        "headless"
      ];
      default = "normal";
      description = "Boot mode. Set per specialisation; never set it by hand.";
    };
    desktop = lib.mkOption {
      readOnly = true;
      type = lib.types.bool;
      default = mode != "headless";
      description = "Whether this mode has a graphical desktop.";
    };
    llm = lib.mkOption {
      readOnly = true;
      type = lib.types.bool;
      default = mode != "normal";
      description = "Whether local LLM serving (llama-swap) runs in this mode.";
    };
    intelIcd = lib.mkOption {
      readOnly = true;
      type = lib.types.str;
      # Must be the x86_64 JSON: the i686 one declares library_arch "32" and the
      # 64-bit Vulkan loader silently rejects it, so the iGPU never shows up.
      default = "${pkgs.mesa}/share/vulkan/icd.d/intel_icd.x86_64.json";
      description = "Vulkan ICD manifest of the Intel iGPU.";
    };
    # Tested 2026-11-26 (eglinfo, nvidia-smi, /proc/<pid>/fd):
    #   * Vulkan apps        -> iGPU via VK_ICD_FILENAMES
    #   * GL/EGL apps        -> iGPU only with BOTH the EGL vendor forced to
    #     (Firefox, Qt)         Mesa AND DRI_PRIME naming the Intel card
    #                           (GALLIUM_DRIVER alone does nothing: NVIDIA's EGL wins)
    #   * Chromium/Electron  -> its GPU process can't init (it insists on the
    #     (VS Code, Discord)    compositor's NVIDIA render node), crash-loops for
    #                           ~1 s, then renders in SOFTWARE. Zero VRAM, as wanted.
    igpuEnv = lib.mkOption {
      readOnly = true;
      type = lib.types.attrsOf lib.types.str;
      default = {
        VK_ICD_FILENAMES = config.meldesktop.intelIcd;
        __EGL_VENDOR_LIBRARY_FILENAMES = "${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json";
        __GLX_VENDOR_LIBRARY_NAME = "mesa";
        DRI_PRIME = "pci-0000_00_02_0"; # the Intel iGPU (lspci 00:02.0)
      };
      description = "Environment that keeps an app off the NVIDIA dGPU (saver session, run-on-igpu).";
    };
  };

  config = {
    # `mode` — show / switch the boot mode. See the help text below.
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

    specialisation = lib.genAttrs [ "saver" "headless" ] (m: {
      configuration.meldesktop.mode = m;
    });

    # Store path / `readlink /run/current-system` says which mode is running.
    system.name = "MelDesktop3" + lib.optionalString (mode != "normal") "-${mode}";
  };
}
