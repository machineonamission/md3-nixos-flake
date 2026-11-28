#!/usr/bin/env bash
# Bump package.nix to the newest claude-desktop in Anthropic's apt repo.
set -euo pipefail
cd "$(dirname "$0")"
pkgs="$(curl -fsSL https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages)"
latest="$(awk 'BEGIN{RS="";FS="\n"} /Package: claude-desktop\n/ {v="";h=""; for(i=1;i<=NF;i++){if($i~/^Version: /)v=substr($i,10); if($i~/^SHA256: /)h=substr($i,9)} if(v!=""&&h!="")print v"\t"h}' <<<"$pkgs" | sort -V | tail -n1)"
version="${latest%%$'\t'*}"
hash="$(nix hash convert --hash-algo sha256 --to sri "${latest#*$'\t'}")"
VERSION="$version" HASH="$hash" perl -0pi -e '
  s{version = "[^"]+";}{version = "$ENV{VERSION}";} or die;
  s{hash = "[^"]+";}{hash = "$ENV{HASH}";} or die;
' package.nix
echo "claude-desktop -> $version"
