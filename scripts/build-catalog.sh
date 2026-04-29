#!/bin/sh
# Build catalog.json from tools/<id>/pier-tool.yaml manifests.
#
# This is a v0 stub. Real implementation needs to:
# - Walk tools/, read each pier-tool.yaml
# - For shell tools, inline the script content into the catalog entry
# - For binary tools, attach platform asset URLs (computed from RELEASE_TAG and tool id)
#   plus computed sha256 from the build artifact
# - Validate against the catalogSchemaVersion=1 schema (mirror src-tauri/src/domain/library.rs)
# - Emit catalog.json + sign with minisign
#
# Required tools: yq (mikefarah/yq v4+), jq, sha256sum, minisign.
# Required env: RELEASE_TAG, MINISIGN_KEY_PATH, MINISIGN_PASSWORD.
#
# Wire-up to follow once the first tag is cut and the binary URLs are real.
set -eu

echo "TODO: implement catalog builder. See script header for spec."
exit 1
