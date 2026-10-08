{
  config,
  pkgs,
  inputs,
  ...
}:

{
  environment.systemPackages = [
    # Pulls the CLI from the github input
    inputs.opencode.packages.${pkgs.system}.opencode

    # Pulls the Desktop GUI from the github input
    inputs.opencode.packages.${pkgs.system}.opencode-desktop
  ];
}
