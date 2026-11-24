{
  pkgs,
  inputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  opencodePkgs = inputs.opencode.packages.${system};

  fixedNodeModules = opencodePkgs.opencode.node_modules.override {
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
