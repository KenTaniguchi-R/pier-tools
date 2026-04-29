# Contributing to pier-tools

Thanks for your interest! pier-tools is the catalog Pier reads from. Tools must be small, single-purpose, and tile-shaped (one click + ≤2 params + run + done).

## Authoring rules

- **Language**: Go (`CGO_ENABLED=0`, pure-Go TLS, no openssl-sys) or pure shell (POSIX-portable, no bash-isms).
- **Size**: keep tools under 500 LOC. Pick a smaller scope.
- **No persistent UI**: tools that need state, listings, or a window go elsewhere (use Raycast/Alfred).
- **Permissions**: declared in `pier-tool.yaml`. Beginner tier = no special permissions OR network only.
- **Naming**: kebab-case id, present-tense verb name ("Kill process on port", not "Port killer").

## Per-tool layout

```
tools/<id>/
  pier-tool.yaml      # Aqua-shaped manifest
  README.md           # one paragraph + usage line
  # for shell:
  tool.sh
  # for go:
  go.mod
  main.go
  .goreleaser.yaml
```

## Manifest schema

See `tools/jwt-decode/pier-tool.yaml` and `tools/kill-port/pier-tool.yaml` for canonical examples.

## Release flow

`git tag v<MAJOR>.<MINOR>.<PATCH>` → CI builds + signs + notarizes binaries, builds + signs the catalog, publishes to R2.

## License

By contributing you agree to license your tool under the MIT license at the repo root.
