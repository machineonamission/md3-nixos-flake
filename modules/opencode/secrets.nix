# Git-ignored OpenCode secrets for Melody.
#
# Kept OUT of git so tokens never land in the tracked Nix source. The module
# (opencode.nix) reads this file at build time and bakes the values into the
# generated ~/.config/opencode/opencode.jsonc (which lives in the private Nix
# store, same as the old hand-written config).
#
# Rotate/revoke in the Home Assistant UI if this file is ever compromised.
{
  # Bearer token for the `home_assistant` MCP server (https://ha.melhome.me).
  # Regenerate at Home Assistant → Profile → Long-Lived Access Tokens.
  haToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI1MzU5MGQyY2UxMjE0MjViOWM5MTYxN2YzZmZkNTlhNCIsImlhdCI6MTc5MTU3MTUzMSwiZXhwIjoyMTA2OTMxNTMxfQ.Q9uKp3F9lduMW2ilOV-v2EaI2Ma9xM0XwO6z3wnEWKc";
}
