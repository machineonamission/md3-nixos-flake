{ ... }:
{
  # Spotify via flatpak (pkgs.spotify removed from nixpkgs 26.11).
  #
  # This module is imported ONLY in desktop mode (normal / saver) — see the
  # flake's makeSystem helper. In headless mode the flatpak home module is not
  # imported, so the `services.flatpak` option does not exist and this
  # declaration would fail the build. Keeping it in a separate, conditionally
  # imported file (rather than guarding it with mkIf inside the shared home
  # config) is what makes headless mode flatpak-free without any `config` reads.
  services.flatpak.packages = [
    {
      appId = "com.spotify.Client";
      origin = "flathub";
    }
  ];
}
