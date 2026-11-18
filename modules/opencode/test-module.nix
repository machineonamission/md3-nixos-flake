# Standalone validation harness for modules/opencode/opencode.nix.
# Evaluates the home-manager module with stubbed inputs (no network, no real
# opencode build) and extracts the generated opencode.jsonc text.
let
  pkgs = import <nixpkgs> { };
  lib = pkgs.lib;

  # Stub the opencode input so the module evaluates without a real build.
  fakeDerivation = {
    override = _: {
      overrideAttrs = _: {
        name = "fake";
        buildPhase = "";
      };
    };
  };
  inputs = {
    opencode = {
      packages = {
        x86_64-linux = {
          opencode = fakeDerivation;
          opencode-desktop = fakeDerivation;
        };
      };
    };
  };

  module = import ./opencode.nix {
    inherit inputs pkgs lib;
    config = {
      programs = {
        opencode = {
          enable = true;
        };
      };
    };
    home = { };
  };

  # When enabled, the module returns home.file.<path> = lib.genText {...}.
  jsonc = module.home.file.".config/opencode/opencode.jsonc";
in
jsonc.text
