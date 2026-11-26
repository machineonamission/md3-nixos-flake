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
  opencode.nix
  llama/                llama-swap: helpers.nix (flag builders), models.nix
                        (models keyed by routing group), profiles.nix (selectors)
home/                   home-manager (melody.nix, spotify.nix)
docs/                   reference: llama-server --help, llama-swap example config
scripts/                test.sh (build), deploy.sh (rsync to /etc/nixos + switch)
```

## Boot modes = specialisations

One system, three boot-menu entries: `normal` (default), `saver`, `headless`.
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

## Verifying refactors

Pure refactors must not change `nix eval --raw .#nixosConfigurations.MelDesktop3.config.system.build.toplevel.drvPath`.
That single drv covers all three modes (the specialisations are inputs of it).
llama-swap settings are validated against its schema at build time, so run a
real `nixos-rebuild build`, not just eval, after touching modules/llama.
