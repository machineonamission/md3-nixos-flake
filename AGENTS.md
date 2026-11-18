This is the full NixOS-unstable Flake config for MelDesktop3.

this repo is not in /etc/nixos, but it has a tracked github upstream, and /etc/nixos tracks the same upstream repo. so i can keep this testing repo and deploying separately.

to test configurations, run `nixos-rebuild build --flake .`, which doesnt require root, and builds the full system into the `result` directory.

once the configuration is verified and working, permanent "deploying" is done by the user, because it requires root perms.

adding `--flake .` to the end of a nixos-rebuild command can cause it to target the dir `.` (or replace `.` with any other dir) instead of the default `/etc/nixos` (which is root owned)

relevant commands:

```bash
# does not require root:

# acts on cwd by default i think?
# updates all flake.nix inputs to the latest versions and bakes into flake.lock
nix flake update
# build, do not apply
nixos-rebuild build

# requires root:

# add as boot option and activate live
sudo nixos-rebuild switch
# activate live but do not add to boot
# "activate live" means swapping active symlinks from nix store to linux dir, can cause a weird hybrid state if programs stay on old config
sudo nixos-rebuild test
# add to boot but do not activate live (non destructive to running system)
sudo nixos-rebuild boot

# reboot system now
sudo reboot now
```
