# opencode (agent CLI + desktop app) from nixpkgs.
# The previous workaround for the upstream flake's broken node_modules hash
# (anomalyco/opencode#59882) is in git history: `git show 26d3a9e^:"modules/opencode copy.nix"`.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    opencode
    opencode-desktop
  ];
}
