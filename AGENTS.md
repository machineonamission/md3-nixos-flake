This is the full NixOS-unstable flake config for MelDesktop3 (single host).

This repo is not /etc/nixos, but both track the same GitHub upstream, so this
copy is for testing and /etc/nixos for deploying. Deploying needs root and is
done by the user.

## Layout

```
flake.nix               inputs + the one nixosConfigurations.MelDesktop3
configuration.nix       host entry point (imports, a few host vars, stateVersion)
hardware-configuration.nix   generated, do not edit
modules/                one concern per file; the file name says what's in it.
  default.nix           imports every module (all modes), grouped + annotated
  modes/                boot modes (see below)
    specialisations.nix   meldesktop.mode/desktop/llm options + the specialisations
    mode-command.nix      the `mode` show/switch CLI
    saver.nix             (saver) session env off the dGPU, KWin exempt
    headless.nix          (headless) TTY autologin + NVIDIA-for-CUDA without Xorg
  system/               nix.nix (daemon, substituters, nixpkgs.config), boot.nix
                        (bootloader, kernel, kernel modules), users, locale, fonts,
                        networking (hostname/NM/firewall/ssh/warp), audio (pipewire)
  hardware/             nvidia.nix, igpu.nix (meldesktop.igpuEnv/intelIcd options,
                        run-on-igpu), firmware, storage (ntfs/fuse), bluetooth,
                        printing, openrgb, vr (wivrn), face-unlock (howdy),
                        disks.nix (the 3 internal disks: smartd, btrfs tools, mounts)
  desktop/              (mkIf desktop) plasma.nix (SDDM + aurora theme in sddm/,
                        Plasma, Xorg, kwallet), flatpak.nix, remote-desktop.nix (xrdp)
  programs/             cli-tools.nix (systemPackages), git.nix (system git identity),
                        apps.nix (firefox, steam, kdeconnect, onedrive)
  compat/               non-Nix software: portable.nix (nix-ld + run-portable),
                        appimage.nix, usr-share-mounts.nix (bindfs for flatpak)
  llm/
    models/             THE model list (plain data, not a module), shared by
                        llama-swap/ and opencode/: models.nix (models keyed by routing
                        group, with tags), profiles.nix (model sets picked by tag
                        query), presets.nix (defaults), default.nix (resolves it)
    llama-swap/         (mkIf meldesktop.llm) helpers.nix (spec -> llama-server flags)
    opencode/           opencode packages + generated ~/.config/opencode/opencode.json
                        (home-manager programs.opencode): settings.nix,
                        providers.nix (models from models/), permissions.nix,
                        serve.nix (headless: `opencode serve` at boot)
home/                   home-manager (melody.nix, spotify.nix)
docs/                   reference: llama-server --help, llama-swap example config,
                        storage-migration.md (disk layout + in-progress btrfs migration runbook)
scripts/                test.sh (build), deploy.sh (rsync to /etc/nixos + switch)
```

## Boot modes = specialisations

One system, three boot-menu entries:
- `normal` (default): full desktop, everything on the dGPU, no llama-swap.
- `saver`: desktop + llama-swap; all userspace Vulkan/GL renders on the iGPU
  (meldesktop.igpuEnv in hardware/igpu.nix: Vulkan/GL on the iGPU, Electron in software; KWin exempt)
  to save VRAM. Takes effect at login: after a live `mode saver`, log out + in.
- `headless`: raw TTY, autologin; llama-swap, `opencode serve` (localhost:4096,
  reach via `ssh -L 4096:localhost:4096`), openrgb all start at boot.

`meldesktop.mode` is set per specialisation in modules/modes/specialisations.nix; modules
branch on it with `lib.mkIf` (never in `imports`, that would recurse).
`config.meldesktop.desktop` is the shorthand for "not headless".

## Commands

```bash
# no root
nixos-rebuild build --flake .          # builds all 3 modes into ./result
ls result/specialisation               # saver headless
nix flake update                       # bump all inputs (llama.cpp CUDA rebuilds!)

# root
sudo nixos-rebuild switch --flake .                            # activate normal, all 3 in boot menu
sudo nixos-rebuild test --flake . --specialisation saver       # live-switch to saver (no boot entry change)
# deploy while RUNNING saver/headless: plain `switch` would bounce you through normal
# mode (llama-swap stops). This sets the boot default AND activates saver live:
sudo nixos-rebuild switch --flake . --specialisation saver
sudo /run/current-system/specialisation/headless/bin/switch-to-configuration test   # same, from the running system
bootctl list                                                   # find the entry ids
sudo bootctl set-oneshot nixos-generation-<N>-specialisation-headless.conf && sudo reboot
readlink /run/current-system           # name ends in -saver / -headless when in that mode
```

## Models: one list, two consumers

Add/change a model or profile ONLY in modules/llm/models. It becomes a llama-swap model
or selector AND an OpenCode model `llama-swap/<id>` (variants low/medium/high/
noreasoning are generated; llama-swap discovery in OpenCode is off on purpose).
Profiles pick targets by tag (`match = [ "dense" "!unsafe" ]`, `prefer = [...]`
first); see the header of modules/llm/models/profiles.nix. Show what a profile resolves to:
`nix eval .#nixosConfigurations.MelDesktop3.config.specialisation.saver.configuration.services.llama-swap.settings.selectors.<id>.targets`
`fallback = [...]` puts ids last.

### Home Assistant voice (`voice` selector)
Home Assistant's voice agent sends model `voice` (thinking on, `reasoning_effort: low`).
The routing groups are `vram` (coders + `voice-gpu-Qwen3.5-4B`, one at a time), `igpu`
(title models) and `cpu` (`voice-Qwen3.5-4B`, persistent). Both voice models are preloaded
(`hooks.on_startup.preload`) and run `-rea off`. The warm order is GPU voice model → whatever
coder is loaded → CPU voice model, so voice never causes a swap. Coders are reasoning-mandatory
(Tiel fakes tool calls with thinking off), hence the low-effort thinking. Benchmarks and the
eval harness live in `~/Projects/home-assistant-server/voice/` (see its AGENTS.md). The iGPU is
slower than the CPU for this, so it's deliberately unused. Coder `fitt` defaults were raised to
768/1024 MiB after Tiel OOM'd on the first request with 128.

## OpenCode config

~/.config/opencode/opencode.json is generated (read-only store symlink) and
validated against opencode's own v2 schema at build time. Do NOT leave an
opencode.jsonc there: OpenCode prefers it and the generated file silently loses.
This repo is PUBLIC: secrets go in ~/.config/opencode/secrets/<name> (gitignored,
outside the store) and are referenced as `{file:...}` (settings.nix). Inspect the
loaded config with `opencode debug config --standalone` (without --standalone it
asks the already-running background server, which has the old config cached).
~/.config/opencode is also its own private git repo (machineonamission/opencode)
for the files that are still hand-edited (AGENTS.md, dcp.jsonc, skills, memory).

## Verifying refactors

Pure refactors must not change `nix eval --raw .#nixosConfigurations.MelDesktop3.config.system.build.toplevel.drvPath`.
That single drv covers all three modes (the specialisations are inputs of it).
llama-swap settings and opencode.json are validated against their schemas at
build time, so run a real `nixos-rebuild build`, not just eval, after touching
anything under modules/llm. To check a change to the llama
side alone, diff `nix eval --json ...specialisation.saver.configuration.services.llama-swap.settings`
before/after.
