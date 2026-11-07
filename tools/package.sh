#!/usr/bin/env bash
# Builds the distributable addon zip and verifies that it loads as shipped.
# Usage: tools/package.sh <version>   (writes RogueAssistant-<version>.zip)
set -euo pipefail

version="${1:?usage: tools/package.sh <version>}"
addon="RogueAssistant"
zipfile="${addon}-${version}.zip"
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT

fail() {
  echo "package: $*" >&2
  exit 1
}

# Stage a clean copy so the working tree is never modified.
cp -R "$addon" "$build/$addon"
find "$build" \( -name ".DS_Store" -o -name ".git*" \) -exec rm -rf {} +

toc="$build/$addon/$addon.toc"
sed "s/@project-version@/${version}/g" "$toc" >"$toc.tmp" && mv "$toc.tmp" "$toc"
grep -q "@project-version@" "$toc" && fail "version placeholder left in TOC"

# Every file the client loads must be present in the package.
check_file() {
  [[ -f "$build/$addon/$1" ]] || fail "missing $1 (referenced by $2)"
}

while IFS= read -r line; do
  line="${line%$'\r'}"
  [[ -z "$line" || "$line" == \#* ]] && continue
  check_file "${line//\\//}" "$addon.toc"
done <"$toc"

# embeds.xml only exists once the addon bundles libraries.
if [[ -f "$build/$addon/embeds.xml" ]]; then
  grep -o 'file="[^"]*"' "$build/$addon/embeds.xml" | sed 's/^file="//; s/"$//' |
    while IFS= read -r file; do
      check_file "${file//\\//}" "embeds.xml"
    done
fi

icon="$(sed -n 's/^## IconTexture: Interface\\AddOns\\RogueAssistant\\//p' "$toc" | tr -d '\r')"
[[ -n "$icon" ]] && check_file "${icon//\\//}.tga" "IconTexture"

rm -f "$zipfile"
(cd "$build" && zip -qr - "$addon") >"$zipfile"
echo "package: built $zipfile ($(unzip -l "$zipfile" | tail -1 | awk '{print $2}') files)"
