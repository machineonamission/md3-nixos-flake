{
  config,
  pkgs,
  inputs,
  pkgs-unstable,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    pkgs-unstable.llama-cpp-cuda
  ];
}
