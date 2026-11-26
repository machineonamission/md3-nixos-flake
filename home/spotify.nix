# Spotify via flatpak (pkgs.spotify was removed in nixpkgs 26.11).
# Inactive in headless mode, where the system flatpak service is off.
{
  services.flatpak.packages = [
    {
      appId = "com.spotify.Client";
      origin = "flathub";
    }
  ];
}
