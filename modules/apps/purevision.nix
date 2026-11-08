# Pure Vision — real-time on-device (NSFW) censoring overlay by PuryFi.
#
# This is an NVIDIA-only desktop app (v1.6.0). It bundles almost its entire
# dependency stack inside its own AppDir (GTK3, GStreamer, ONNX Runtime, CUDA
# 12.9, ICU, fonts, …) and only needs a handful of system libraries that are
# already in the nix-ld set (libstdc++, libGL, libwayland, pipewire, fontconfig)
# PLUS the NVIDIA driver's NVML (libnvidia-ml.so.1), which is added to
# `programs.nix-ld.libraries` in portable.nix.
#
# The upstream download is membership Early Access (no public URL), so we bundle
# the user's locally-downloaded NVIDIA AppImage. If you move the file, update
# `purevisionAppImage` below.

{
  config,
  pkgs,
  lib,
  ...
}:

let
  purevisionVersion = "1.6.0";

  # Local NVIDIA-build AppImage (no public download URL — membership Early Access).
  # `writeBinFile` copies the bytes into the Nix store at eval time (impure, outside
  # the build sandbox) so the sandboxed build can read it — a bare path or file://
  # fetch would fail with "cannot stat"/"curl could not open file".
  # If you move the file, update this path and run `nix flake check` to refresh the store copy.
  purevisionAppImage = pkgs.writeBinFile {
    name = "PureVision-Nvidia(2).AppImage";
    content = builtins.readFile "/home/melody/Downloads/PureVision-Nvidia(2).AppImage";
  };

  purevision =
    pkgs.runCommand "purevision-${purevisionVersion}"
      {
        buildInputs = [
          pkgs.p7zip
          pkgs.coreutils
          pkgs.findutils
          pkgs.diffutils
        ];
      }
      ''
        set -euo pipefail

        mkdir -p "$out/bin" "$out/share/applications"

        tmp="$(mktemp -d)"
        cp "${purevisionAppImage}" "$tmp/purevision.AppImage"
        cd "$tmp"

        # Type-2 AppImage: an ELF loader + an embedded 7z payload. Extraction is flat
        # — AppRun / AppRun.wrapped / usr/ land directly at the top level.
        ${pkgs.p7zip}/bin/7z x -bd -y purevision.AppImage >/dev/null

        # Copy the self-contained AppDir into $out. --no-preserve=mode keeps the
        # archived exec bits off; we re-enable them explicitly below.
        cp -a --no-preserve=mode ./ "$out/"

        # 7z strips the exec bits; restore them on the app's own binaries.
        chmod +x \
          "$out/AppRun" \
          "$out/AppRun.wrapped" \
          "$out/usr/bin/pure_vision"

        # Clean launcher (keeps $out clean and gives us a stable command name).
        cat > "$out/bin/purevision" <<'EOF'
        #!/bin/bash
        # Pure Vision self-locates via /proc/self/exe and sets up its bundled
        # LD_LIBRARY_PATH, so this just forwards to its AppRun bootstrap.
        exec "$out/AppRun" "$@"
        EOF
        chmod +x "$out/bin/purevision"

        # Desktop entry so it shows up in the app menu / search.
        install -m0644 "Pure Vision.desktop" "$out/share/applications/purevision.desktop"
      '';

in
{
  options.apps.purevision.enable = lib.mkEnableOption ''
    Pure Vision real-time censoring overlay (PuryFi, NVIDIA build).
  '';

  config = lib.mkIf config.apps.purevision.enable {
    environment.systemPackages = with pkgs; [
      purevision
    ];
  };
}
