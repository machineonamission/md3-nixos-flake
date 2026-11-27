# The master model list, shared by modules/llm/llama-swap (llama-swap) and
# modules/llm/opencode (OpenCode providers). Plain data: `import ./. { inherit lib; }`.
# It is NOT a NixOS module (modules/default.nix doesn't import it).
#
#   presets.nix  — model / valV3 / titleModel: fill in defaults -> full spec
#   models.nix   — the models, keyed by device group (cpu / vram / igpu), with tags
#   profiles.nix — model sets picked by tag queries (llama-swap selectors)
#
# Returns:
#   groups   — { vram = { <id> = spec; }; igpu = ...; }
#   models   — all groups merged: { <id> = spec; }
#   profiles — { <id> = profile // { targets; spec; }; } with `targets` resolved
#              from match/prefer, and `spec` a virtual model spec derived from
#              them (smallest ctx, image only if every target has it, ...), so
#              OpenCode can list a profile like a model
#   port     — llama-swap's port
{ lib }:
let
  presets = import ./presets.nix { inherit lib; };

  # Tags anyone could work out from the spec, so models.nix never repeats them.
  derivedTags =
    group: s:
    [
      s.kind # coder | title
      group # vram | igpu
    ]
    ++ lib.optional (s.mtp or null != null) "mtp"
    ++ lib.optional s.image "image"
    ++ lib.optional (lib.hasInfix "NanoPlus" (s.quant or "")) "nanoplus";

  groups = lib.mapAttrs (
    group: lib.mapAttrs (_: s: s // { tags = lib.unique (s.tags ++ derivedTags group s); })
  ) (import ./models.nix presets);
  models = lib.mergeAttrsList (lib.attrValues groups);

  # "tag" must be present, "!tag" must be absent
  matches =
    query: s:
    lib.all (
      q: if lib.hasPrefix "!" q then !lib.elem (lib.removePrefix "!" q) s.tags else lib.elem q s.tags
    ) query;

  minOf = f: specs: lib.foldl' lib.min (f (lib.head specs)) (map f specs);

  profile =
    id: p:
    let
      fail = msg: throw "llm/profiles.nix: profile '${id}' ${msg}";
      known = t: if models ? ${t} then t else fail "names unknown model '${t}'";
      matched = lib.optionals (p ? match) (lib.attrNames (lib.filterAttrs (_: matches p.match) models));
      ids = map known (p.prefer or [ ] ++ p.targets or [ ] ++ matched ++ p.fallback or [ ]);
      targets = if ids == [ ] then fail "matches no models" else lib.unique ids;
      specs = map (t: models.${t}) targets;
      # reasoning_effort levels a model accepts (presets.nix `efforts`)
      effortsOf =
        s:
        s.efforts or [
          "low"
          "medium"
          "high"
        ];
      # The levels this selector OFFERS: the union of every target's `efforts`,
      # in weakest-to-strongest order. A variant the currently routed target
      # doesn't accept is rejected by its chat template (e.g. "high" on the
      # EfficientThink family, which only knows xhigh), hence the default below.
      efforts = lib.filter (e: lib.any (s: lib.elem e (effortsOf s)) specs) [
        "low"
        "medium"
        "high"
        "xhigh"
      ];
      # The DEFAULT effort must be accepted by the first (preferred) target, the
      # one `warm` routes to: keep profiles.nix's choice if it is, else that
      # target's strongest level (a "high" selector on an xhigh-family target
      # defaults to xhigh instead of an effort the template rejects).
      firstEfforts = effortsOf (lib.head specs);
      effort = if p ? effort && lib.elem p.effort firstEfforts then p.effort else lib.last firstEfforts;
    in
    {
      strategy = "warm";
    }
    // removeAttrs p [
      "match"
      "prefer"
      "fallback"
    ]
    // {
      inherit targets;
      spec = {
        kind = "profile";
        inherit (p) name;
        inherit efforts effort;
        # ctx: context window OpenCode advertises. Set per selector in
        # profiles.nix; falls back to the smallest target's ctx so no target is
        # ever handed a prompt it can't take.
        ctx = p.ctx or (minOf (s: s.ctx) specs);
        maxOutput = minOf (s: s.maxOutput) specs;
        reasoningBudget = minOf (s: s.reasoningBudget) specs;
        image = lib.all (s: s.image) specs;
        tools = lib.all (s: s.tools) specs;
      };
    };

  profiles = lib.mapAttrs profile (import ./profiles.nix);

  # Every id is a model name on the same llama-swap endpoint, so they must be unique.
  ids = lib.concatMap lib.attrNames (lib.attrValues groups) ++ lib.attrNames profiles;
  dupes = lib.unique (lib.filter (id: lib.count (x: x == id) ids > 1) ids);
in
assert lib.assertMsg (
  dupes == [ ]
) "llm: ids used more than once (across groups/profiles): ${toString dupes}";
{
  inherit groups models profiles;
  port = 9930;
}
