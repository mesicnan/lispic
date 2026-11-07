# Implementation guide

The implementation targets Hy 1.3.1. The Python bootstrap registers Hy's import hook before loading the CLI. User content and configuration use the project's own data reader and are never executed as Hy or Python.

## Module boundaries

| Module | Responsibility and main entry points |
|---|---|
| `model.hy` | `Position`, `Text`, and `Node` carry document structure and diagnostic positions. `fail` raises a positioned `ContentError`; `plain` concatenates descendant text. |
| `parser.hy` | `Reader` separates literal attributes from natural element text. `parse` returns root nodes, `parse-file` adds UTF-8 file loading, and `parse-data` accepts exactly one literal data value. |
| `config.hy` | `merge` copies defaults and applies known overrides. `load-config` parses settings, validates them, normalizes origins, and records the configuration directory as `root`. |
| `validation.hy` | `check-tree` validates nesting and attributes; `safe-file` confines image paths; `date-value` produces aware datetimes. `load-content` reads all records before resolving links and sorting posts. |
| `images.hy` | `process-image` returns metadata for cached or newly converted variants. `publish-image` copies variants into a staged website without exposing originals. |
| `typography.hy` | `canonical` removes source-position dependence. `paragraph-style` derives independent CSS values from stable paragraph identities and the site seed. |
| `excerpts.hy` | `paragraphs` selects eligible text, `summary` chooses a manual or automatic excerpt, and `first-photo` searches document order, including inline galleries. |
| `render.hy` | HTML escaping, origin-aware links, responsive images, content rendering, lists, and complete page shells. `body` applies per-post paragraph settings. |
| `feeds.hy` | `stable-id` creates UUIDv5 entry IDs. `write-feeds` serializes Atom and RSS with ElementTree, using document metadata rather than the build clock. |
| `build.hy` | `output-paths` protects sources and existing directories. `build` coordinates validation, image processing, page generation, feeds, staging, and output replacement. |
| `cli.hy` | `main` parses commands and handles user-facing failures. Preview mode rewrites both origins and serves separate output trees on loopback ports. |
| `static/layout.js` | The pure `layout` function computes geometry without reading or changing the DOM. |
| `static/gallery.js` | Applies geometry on container resize and initializes the bundled PhotoSwipe lightboxes. |

## Data flow and contracts

1. `load-config(path)` returns a settings dictionary with built-in defaults and a resolved `root` directory. Relative source, cache, and output paths use this root.
2. `load-content(cfg)` returns `posts`, `pages`, `albums`, `photos`, and `post-map`. Document records contain `node`, `attrs`, and `path`. Post records also contain aware `published` and `updated` datetimes; public gallery records contain `added`.
3. `build(cfg, check-only=True)` validates content and inspects image files. It returns the content data with a draft-filtered `public-posts` list and an empty `inline` lookup, without generating image variants or web output.
4. A full build processes published images, attaches an `image` record to used catalog photos, and indexes post-only images by `(document path, relative source)`. Image records contain a content `key`, oriented original `width`/`height`, and `variants` with file names, dimensions, and formats. The build adds a `site` field indicating which origin publishes each image.
5. Renderers consume validated records and image metadata. HTML text and attribute values are escaped at the output boundary. The XML library escapes embedded feed HTML as XML text.
6. Both websites are generated in temporary sibling directories. Once rendering succeeds, `publish-output` removes stale generated children while preserving `.git`, `.gitignore`, and `.gitattributes` in each output checkout. The destination directory itself stays in place, preserving relative worktree Git paths. Publication is not a shared filesystem transaction.

`walk` visits only element nodes, in depth-first source order. Renderers must handle `Text` nodes separately. Source positions are one-based and represent Unicode character positions; metadata validation generally reports the opening position of its element.

## Parser whitespace

Attribute data has its own grammar. A string is decoded with JSON escaping, while a body treats quotes and semicolons as ordinary characters. Only backslash, opening parenthesis, and closing parenthesis have body escape sequences.

Text buffers are flushed before nested elements. Ordinary text normalizes whitespace, and only the outer text edges of an ordinary element are trimmed. This keeps a space before an emphasized word while leaving following punctuation adjacent. Entering `pre` propagates whitespace preservation into descendants such as `code`.

## Deterministic identities

- Image cache keys depend on original bytes, conversion settings, pipeline version, and Pillow version. Text metadata and source paths do not invalidate image conversion.
- Paragraph styles depend on the site seed, post ID, paragraph content or explicit ID, and the individual style parameter. Paragraph position is excluded.
- Feed entry IDs depend only on `blog.identity` and the stable post ID.
- Publication ordering uses metadata timestamps, with source paths or photo IDs as stable tie-breakers. Filesystem modification times are excluded.

Changing image conversion behavior requires incrementing `PIPELINE` in `images.hy`. Comments or docstrings do not require a pipeline-version change.

## Tall-photo geometry

`layout(items, width, settings)` accepts width/height ratios and optional calendar-day keys. It returns boxes identified by original input indices plus the container height. It never mutates the input. The DOM adapter updates coordinates rather than node order, so lightbox order remains independent of visual movement.

For a tall ratio `r`, let the two right-hand row heights be `h1` and `h2`, their ratio sums be `A` and `B`, and the gap be `g`. If `H = h1 + h2`, the tall tile width is `r × (H + g)`. Both right-hand rows must fill the remaining width after their internal gaps. The implementation solves these equations for `H`, derives each row height, rejects unsuitable solutions, and scores the rest by distance from the target height and the candidate's movement.

An ordinary row is selected greedily when no suitable two-row group exists. Complete rows fill the container, while the final row is capped at the target height. The browser adapter can compute everything before images finish loading because ratios are already included in generated HTML.

## Maintaining the code

Functions, classes, and modules have English docstrings. Inline comments explain invariants and non-obvious calculations. Generated website copy, example content, and current user-facing diagnostics remain Czech. Bundled PhotoSwipe sources retain their upstream comments and license.

Run the core and geometry commands in the README after relevant changes. Browser checks require the example preview to be running. [verification.md](verification.md) records the initial version's checks and known limitations.

## Repository separation

The workspace has independent sibling repositories for code (`lispic/`), source content (`content/`), generated blog (`blog/`), and generated gallery (`gallery/`). The code repository's existing history remains in its own `.git` directory. Real source content and original photos are not part of the code checkout.

Tests use the text-only site under `tests/fixtures/site` and generate labelled images in a temporary directory using `tools/make_images.hy`. This keeps a standalone code checkout testable without the author's source-content repository or binary photo fixtures. The browser integration test uses a preview of the sibling demonstration content; its comment and the README show the corresponding `--config` path.
