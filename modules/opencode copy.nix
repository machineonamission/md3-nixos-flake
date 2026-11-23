{
  pkgs,
  inputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  opencodePkgs = inputs.opencode.packages.${system};

  # Upstream nix/hashes.json pins the node_modules fixed-output hash to a single
  # Bun version (anomalyco/opencode#59882). Following nixpkgs-unstable means this
  # build uses a different Bun, so the installed layout differs and the FOD check
  # fails on nearly every release. hash = null disables the check: Nix computes
  # and stores the real output hash without comparing it to a value that only
  # matches one Bun. No literal hash survives a version/Bun bump, so this stays
  # valid until upstream drops the aggregate hash (PR #59403).
  fixedNodeModules = opencodePkgs.opencode.node_modules.override {
    hash = "sha256-At902X9Dxopt9Z2oHelDXwb9mgM9wPpI44UlQApLVYg=";
  };

  fixedOpencode = opencodePkgs.opencode.override {
    node_modules = fixedNodeModules;
  };

  fixedOpencodeDesktop =
    (opencodePkgs.opencode-desktop.override {
      opencode = fixedOpencode;
    }).overrideAttrs
      (old: {
        postPatch = (old.postPatch or "") + ''
          for pkg in cli-linux-x64 cli-linux-x64-baseline opencode-linux-x64; do
            mkdir -p "packages/cli/dist/$pkg/bin"
            cp -L ${fixedOpencode}/bin/opencode "packages/cli/dist/$pkg/bin/opencode"
            cp -L ${fixedOpencode}/bin/opencode "packages/cli/dist/$pkg/bin/cli"
            printf '{"name":"@opencode/%s","version":"%s"}\n' "$pkg" "${fixedOpencode.version}" > "packages/cli/dist/$pkg/package.json"
          done
        '';
      });
in
{
  environment.systemPackages = [
    fixedOpencode
    fixedOpencodeDesktop
  ];
}
