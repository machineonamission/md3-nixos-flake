{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  environment.systemPackages = [
    inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode
    (inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode-desktop
    )
  ];
}
