{
  pkgs,
  inputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  opencodePkgs = inputs.opencode.packages.${system};
in
{
  environment.systemPackages = [
    opencodePkgs.opencode
    opencodePkgs.opencode-desktop
  ];
}
