#!/bin/bash
# Build a signed catalog.json from tools/<id>/pier-tool.yaml manifests.
#
# Output schema mirrors pier/src-tauri/src/domain/library.rs (catalogSchemaVersion=1).
# Two flavors of tool are supported:
#
#   - Shell tool: directory has tool.sh, no .goreleaser.yaml. We inline the
#     script body into the catalog entry's `script` field. No `platforms`.
#   - Go tool:    directory has .goreleaser.yaml. The CI workflow has already
#     run goreleaser + codesign + notarize and uploaded a universal binary
#     named "<id>-darwin-universal" to the GitHub Release for $RELEASE_TAG.
#     We attach the same {url, sha256} to BOTH "darwin-arm64" and
#     "darwin-amd64" platform keys because GoReleaser's universal_binaries
#     setting (replace: true) fuses the two arch builds into one fat Mach-O.
#
# Required env: RELEASE_TAG, MINISIGN_KEY_PATH, MINISIGN_PASSWORD.
# Required tools: yq (mikefarah v4+), jq, minisign, and either
# `shasum` (macOS) or `sha256sum` (Linux).
#
# Bash (not /bin/sh) because we use arrays and process substitution.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# --- env validation ---------------------------------------------------------
: "${RELEASE_TAG:?RELEASE_TAG must be set (e.g. v0.1.0)}"
: "${MINISIGN_KEY_PATH:?MINISIGN_KEY_PATH must be set}"
: "${MINISIGN_PASSWORD:?MINISIGN_PASSWORD must be set}"

if [ ! -f "$MINISIGN_KEY_PATH" ]; then
  echo "error: minisign key not found at $MINISIGN_KEY_PATH" >&2
  exit 1
fi

# --- tool detection ---------------------------------------------------------
# Pick a sha256 implementation. macOS ships shasum; most Linux distros ship
# sha256sum. We normalize both to "<hex>  <path>" output and parse field 1.
if command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
elif command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum "$1" | awk '{print $1}'; }
else
  echo "error: need shasum or sha256sum on PATH" >&2
  exit 1
fi

for bin in yq jq minisign; do
  command -v "$bin" >/dev/null 2>&1 || { echo "error: $bin not found on PATH" >&2; exit 1; }
done

ASSET_BASE="https://github.com/KenTaniguchi-R/pier-tools/releases/download/${RELEASE_TAG}"
PUBLISHED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Find the universal binary for a Go tool. GoReleaser writes it to a
# directory whose name embeds the universal_binaries id; the canonical path
# is dist/<id>-darwin-universal_<id>-universal_darwin_all/<id>, but we fall
# back to a recursive find in case GoReleaser's layout shifts.
find_go_binary() {
  local id="$1"
  local primary="tools/${id}/dist/${id}-darwin-universal_${id}-universal_darwin_all/${id}"
  if [ -x "$primary" ]; then
    echo "$primary"
    return 0
  fi
  # Fallback: any executable named exactly $id under dist/, excluding
  # goreleaser's metadata/artifacts/config sidecar dirs.
  local found
  found=$(find "tools/${id}/dist" -type f -name "$id" \
    -not -path "*/metadata/*" \
    -not -path "*/artifacts/*" \
    -not -path "*/config/*" \
    2>/dev/null | head -n 1 || true)
  if [ -n "$found" ] && [ -x "$found" ]; then
    echo "$found"
    return 0
  fi
  return 1
}

# --- per-tool entry construction -------------------------------------------
TOOLS_JSON_ARRAY="[]"

for dir in tools/*/; do
  manifest="${dir}pier-tool.yaml"
  if [ ! -f "$manifest" ]; then
    echo "warn: skipping $dir (no pier-tool.yaml)" >&2
    continue
  fi

  id="$(yq -r '.id' "$manifest")"
  echo "building entry for: $id"

  # Convert the YAML manifest to JSON once; downstream we patch in script /
  # platforms. yq -o=json emits the full doc; jq massages it.
  base_json="$(yq -o=json '.' "$manifest")"

  if [ -f "${dir}.goreleaser.yaml" ]; then
    # --- Go tool: attach platforms, no script ---
    bin_path="$(find_go_binary "$id" || true)"
    if [ -z "${bin_path:-}" ]; then
      echo "error: no built binary for $id under tools/${id}/dist/ — did goreleaser run?" >&2
      exit 1
    fi
    bin_sha="$(sha256 "$bin_path")"
    asset_url="${ASSET_BASE}/${id}-darwin-universal"

    entry="$(jq -n \
      --argjson base "$base_json" \
      --arg url "$asset_url" \
      --arg sha "$bin_sha" \
      '$base + {
        platforms: {
          "darwin-arm64": { url: $url, sha256: $sha },
          "darwin-amd64": { url: $url, sha256: $sha }
        }
      } | del(.script)')"
  else
    # --- Shell tool: inline script, no platforms ---
    sh_path="${dir}tool.sh"
    if [ ! -f "$sh_path" ]; then
      echo "error: $id has neither .goreleaser.yaml nor tool.sh" >&2
      exit 1
    fi
    script_body="$(cat "$sh_path")"
    entry="$(jq -n \
      --argjson base "$base_json" \
      --arg script "$script_body" \
      '$base + { script: $script } | del(.platforms)')"
  fi

  TOOLS_JSON_ARRAY="$(jq -n \
    --argjson arr "$TOOLS_JSON_ARRAY" \
    --argjson e "$entry" \
    '$arr + [$e]')"
done

# --- write top-level catalog ------------------------------------------------
jq -n \
  --argjson tools "$TOOLS_JSON_ARRAY" \
  --arg publishedAt "$PUBLISHED_AT" \
  '{
    catalogSchemaVersion: 1,
    publishedAt: $publishedAt,
    tools: $tools
  }' > catalog.json

echo "wrote catalog.json ($(wc -c < catalog.json) bytes, $(jq '.tools | length' catalog.json) tools)"

# --- sign -------------------------------------------------------------------
# minisign reads MINISIGN_PASSWORD from env when key is encrypted, but support
# is inconsistent across versions. Piping the password on stdin works
# everywhere: minisign treats stdin lines as the password prompt response.
rm -f catalog.json.minisig
printf '%s\n' "$MINISIGN_PASSWORD" | minisign -S -s "$MINISIGN_KEY_PATH" -m catalog.json

echo "signed catalog.json -> catalog.json.minisig"
