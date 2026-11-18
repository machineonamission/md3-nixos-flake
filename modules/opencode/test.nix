let
  pkgs = import <nixpkgs> { };
  lib = pkgs.lib;
  models = import ./models.nix { inherit lib; };
  perms = import ./permissions.nix { inherit lib; };
  secrets = import ./secrets.nix;
  out = models.prettyJson {
    providers = models.providers;
    permissions = perms.globalPermissions;
    agents = perms.agents;
    haToken = secrets.haToken;
  };
in
out
