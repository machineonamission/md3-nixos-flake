# WiVRn: Quest 3 inside-out tracking. (Not SteamVR lighthouse: there are no
# base stations, and pointing Monado at that driver segfaults.)
{
  services.wivrn = {
    enable = true;
    openFirewall = true;
    steam.importOXRRuntimes = true;
  };
}
