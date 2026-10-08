{
  config,
  pkgs,
  inputs,
  pkgs-llama,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    pkgs-llama.llama-cpp-cuda
  ];
}
