This is the full NixOS-unstable Flake config for MelDesktop3.

this repo is not in /etc/nixos, but it has a tracked github upstream, and /etc/nixos tracks the same upstream repo. so i can keep this testing repo and deploying separately.

to test configurations, run nixos-build targeting the root directory of the repo:

eg `nixos-rebuild build --flake .`

once the configuration is verified and working, permanent "deploying" is done by the user, and is basically

```bash
cd /etc/nixos

sudo nixos-rebuild switch
# or, the not live version
sudo nixos-rebuild boot
sudo reboot now
```

`nix flake update` is the command to regenerate flake.lock, ie "system update". there's a ton pinned to "latest" that this could update, eg kernel, drivers, programs, os itself, so be careful