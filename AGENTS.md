This is the full NixOS-unstable flake config for MelDesktop3 (single host).

This repo is not /etc/nixos, but both track the same GitHub upstream, so this
copy is for testing and /etc/nixos for deploying. Deploying needs root and is
done by the user.

## Layout

```
flake.nix               inputs + the one nixosConfigurations.MelDesktop3
configuration.nix       host entry point (imports, a few host vars, stateVersion)
hardware-configuration.nix   generated, do not edit
modules/
  default.nix           imports every module (all modes)
  meldesktop.nix        boot modes (specialisations), meldesktop.* options
  nix.nix               nix daemon settings, substituters, nixpkgs.config
  desktop.nix           SDDM/Plasma/Xorg/flatpak/xrdp/run-on-igpu   (mkIf desktop)
  headless.nix          TTY autologin + NVIDIA-for-CUDA without Xorg (mkIf headless)
  base.nix hardware.nix networking.nix services.nix packages.nix
  portable.nix          nix-ld library set + run-portable wrapper
  icon-fix.nix          /usr/share/{fonts,icons,themes} bindfs mounts
  llm/                  THE model list (plain data, not a module), shared by
                        llama/ and opencode/: models.nix (models keyed by routing
                        group, with tags), profiles.nix (model sets picked by tag
                        query), presets.nix (defaults), default.nix (resolves it)
  llama/                llama-swap: helpers.nix (spec -> llama-server flags)
  opencode/             opencode packages + generated ~/.config/opencode/opencode.json
                        (home-manager programs.opencode): settings.nix,
                        providers.nix (models from llm/), permissions.nix
home/                   home-manager (melody.nix, spotify.nix)
docs/                   reference: llama-server --help, llama-swap example config
scripts/                test.sh (build), deploy.sh (rsync to /etc/nixos + switch)
```

## Boot modes = specialisations

One system, three boot-menu entries:
- `normal` (default): full desktop, everything on the dGPU, no llama-swap.
- `saver`: desktop + llama-swap; all userspace Vulkan/GL renders on the iGPU
  (VK_ICD_FILENAMES + GALLIUM_DRIVER) to save VRAM.
- `headless`: raw TTY, autologin; llama-swap, `opencode serve` (localhost:4096,
  reach via `ssh -L 4096:localhost:4096`), openrgb all start at boot.

`meldesktop.mode` is set per specialisation in modules/meldesktop.nix; modules
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
sudo /run/current-system/specialisation/headless/bin/switch-to-configuration test   # same, from the running system
bootctl list                                                   # find the entry ids
sudo bootctl set-oneshot nixos-generation-<N>-specialisation-headless.conf && sudo reboot
readlink /run/current-system           # name ends in -saver / -headless when in that mode
```

## Models: one list, two consumers

Add/change a model or profile ONLY in modules/llm. It becomes a llama-swap model
or selector AND an OpenCode model `llama-swap/<id>` (variants low/medium/high/
noreasoning are generated; llama-swap discovery in OpenCode is off on purpose).
Profiles pick targets by tag (`match = [ "dense" "!unsafe" ]`, `prefer = [...]`
first); see the header of modules/llm/profiles.nix. Show what a profile resolves to:
`nix eval .#nixosConfigurations.MelDesktop3.config.specialisation.saver.configuration.services.llama-swap.settings.selectors.<id>.targets`

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
modules/llm, modules/llama or modules/opencode. To check a change to the llama
side alone, diff `nix eval --json ...specialisation.saver.configuration.services.llama-swap.settings`
before/after.
