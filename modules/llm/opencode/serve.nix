# `opencode serve --service` as a user unit, started with melody's session (every mode; headless autologins on the TTY).
# Host/port/CORS/password come from opencode's own service config (`opencode service get` / `set`), not from here.
{ config, ... }:
{
  home-manager.users.melody.systemd.user.services.opencode = {
    Unit.Description = "opencode server";
    Service = {
      WorkingDirectory = "%h";
      ExecStart = "${config.home-manager.users.melody.programs.opencode.package}/bin/opencode serve --service";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
