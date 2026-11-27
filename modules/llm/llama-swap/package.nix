# llama-swap newer than nixpkgs-unstable (which sits at v268).
#
# Needed for the `fit` selector strategy + `capacity` router (v273+), which the
# HA `voice` selector uses. Drop this file once nixpkgs ships >= that.
#
# Bump: set `version`, then put lib.fakeHash in all three hashes and run
# `nixos-rebuild build --flake .`; each failure prints the right hash
# (src, then the Go vendor dir, then the UI's npm deps).
{ pkgs }:
pkgs.llama-swap.overrideAttrs (
  finalAttrs: old: {
    version = "277";
    src = old.src.override {
      tag = "v${finalAttrs.version}";
      hash = "sha256-OlP8gzI7vtv4zCrtHLJ7zeWoXtIkRV/QKwdA/LbxBHU=";
    };
    vendorHash = "sha256-ESaG4DYGGlK+tPM9qHMcDSI0TLkg+DdMC6E8ik0jxIw=";
    # upstream doc generators added after v268; nixpkgs' installPhase rejects
    # executables it doesn't sort into an output
    excludedPackages = old.excludedPackages ++ [
      "docbot/gensource"
      "docs/gen"
    ];
    passthru = old.passthru // {
      # npmDeps is built eagerly from npmDepsHash, so setting the hash alone
      # is not enough: rebuild the fetcher too.
      ui = old.passthru.ui.overrideAttrs (
        ui: _: {
          npmDeps = pkgs.fetchNpmDeps {
            inherit (ui) src sourceRoot;
            name = "${ui.pname}-${ui.version}-npm-deps";
            hash = "sha256-GQiBiP5UvrCJeiiHf6JA+PcKhg/SSCQIyECvIsr2/KM=";
          };
        }
      );
    };
  }
)
