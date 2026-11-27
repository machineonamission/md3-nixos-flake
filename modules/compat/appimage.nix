# AppImages + FHS sandboxes for non-Nix apps. Library set: compat/portable.nix.
{ pkgs, ... }:
{
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  environment.systemPackages = with pkgs; [
    appimage-run

    # FHS-compatible runner for weird apps nix-ld can't handle alone
    # (apps that hardcode /usr/lib paths, bundle their own loader, or need a
    # traditional library layout). `bwrap` sets up a bind-mount FHS sandbox.
    bubblewrap

    # AppImages that shell out to KDE/glib CLI tools (- needs `gdbus`
    # + `kwriteconfig6` for its KWin "effects" feature). kwriteconfig6 ships in
    # the base system; gdbus lives in glib's -bin output.
    glib
  ];
}
