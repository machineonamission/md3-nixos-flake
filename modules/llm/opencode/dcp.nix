# dcp.nix — ~/.config/opencode/dcp.jsonc for the Dynamic Context Pruning plugin
# (@tarquinen/opencode-dcp), generated like opencode.json.
#
# DCP nudges the model to compress its own context (`compress` tool) between
# minContextLimit and maxContextLimit (stronger above max). A "%" there is of the
# model's limit.context, but what a session may really grow to before OpenCode's
# native compaction (the failsafe, settings.nix) is limit.input minus the buffer.
# For models whose limit.input is below ctx (presets.nix tieredModel: the server
# keeps thinking + answer room on top), the same percentages are applied to
# limit.input instead and emitted as per-model token counts, so DCP still fires
# well before native compaction.
{ lib, catalog }:
let
  maxPct = 80;
  minPct = 50;

  ids = catalog.models // lib.mapAttrs (_: p: p.spec) catalog.profiles;
  reduced = lib.filterAttrs (_: s: (s.inputLimit or s.ctx) < s.ctx) ids;
  perModel =
    pct:
    lib.mapAttrs' (
      id: s: lib.nameValuePair "llama-swap/${id}" (s.inputLimit * pct / 100)
    ) reduced;
in
{
  "$schema" =
    "https://raw.githubusercontent.com/Opencode-DCP/opencode-dynamic-context-pruning/master/dcp.schema.json";
  compress = {
    maxContextLimit = "${toString maxPct}%";
    minContextLimit = "${toString minPct}%";
    modelMaxLimits = perModel maxPct;
    modelMinLimits = perModel minPct;
  };
}
