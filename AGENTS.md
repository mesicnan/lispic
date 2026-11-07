# Lispic development

- Runtime implementation belongs in Hy 1.3.1. Python is limited to the package bootstrap and tests/tools.
- Content and configuration are data. Never evaluate them with Python/Hy eval or the Hy reader.
- Keep parser, content model, validation, image processing, rendering, feeds, build orchestration and CLI separate.
- Preserve source positions in parsed nodes. Use stable hashes, not Python hash(), for persistent identities and cache keys.
- Public output is two independent static directories. Local preview must use local URLs for both sites.
- `gallery false` catalog photos may appear in posts through `ref`, but have no gallery page and cannot be album members.
- Future-dated posts publish normally; drafts do not. Links from public content to drafts are errors.
- Tall photos may move to the left start of their local two-row group; retain the order of all other photos and the original lightbox order. Gallery moves must not cross added-day boundaries.
- Theme: dark, Czech, narrow article text, wide uncropped gallery.
- Run `.venv/bin/python -m pytest -q` for core changes and `node --test tests/layout.test.mjs` for geometry changes. Browser checks: `node tests/browser.mjs` with the example preview running.

- Workspace repositories are siblings: `lispic/` (code), `content/` (source), `blog/` and `gallery/` (generated output). Run code commands from this repository and use `--config ../content/site.sexp` for the author's site.
- Never delete or replace `.git`, `.gitignore`, or `.gitattributes` in output repositories. Regeneration must preserve their history while removing stale generated files.
- Tests use text-only fixtures under `tests/fixtures/site` and generate temporary images; do not depend on or modify the author's content checkout.
