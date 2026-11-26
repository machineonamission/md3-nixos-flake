# Shared values for the rest of the config, defined once.
{ lib, pkgs, ... }:
{
  options.meldesktop.intelIcd = lib.mkOption {
    readOnly = true;
    type = lib.types.str;
    # Must be the x86_64 JSON: the i686 one declares library_arch "32" and the
    # 64-bit Vulkan loader silently rejects it, so the iGPU never shows up.
    default = "${pkgs.mesa}/share/vulkan/icd.d/intel_icd.x86_64.json";
    description = "Vulkan ICD manifest of the Intel iGPU.";
  };
}
