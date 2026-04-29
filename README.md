# pier-tools

Curated tool catalog for [Pier](https://github.com/KenTaniguchi-R/pier).

Each tool lives under `tools/<id>/`:
- `pier-tool.yaml` — Aqua-shaped manifest (id, version, permissions, params)
- `tool.sh` for shell tools, OR
- `main.go` + `go.mod` + `.goreleaser.yaml` for Go tools

CI on tagged release builds, signs, and notarizes Go binaries via GoReleaser, then publishes a signed `catalog.json` to Cloudflare R2.

## Adding a tool

1. Create `tools/<id>/pier-tool.yaml`
2. Add the implementation
3. Open a PR

Tools are reviewed before publication.

## License

MIT
