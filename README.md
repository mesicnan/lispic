# Lispic

A personal generator for two static photography websites. The core is written in **Hy 1.3.1**, with Pillow handling image processing. The dark blog uses a narrow text column, while the gallery presents wide rows without cropping. The generated directories require only static HTTP hosting.

## Quick start

Requires Python 3.11 or later with `venv` and system time zone data. Verified with Python 3.13.16, Hy 1.3.1, and Pillow 12.3.0.

The workspace contains four sibling directories, each with its own Git repository:

```text
workspace/
  lispic/    # This repository: generator code, documentation, tests, and tools
  content/   # Website source: site.sexp, posts, pages, albums, and originals
  blog/      # Generated blog output
  gallery/   # Generated gallery output
```

The existing code history and remote belong to `lispic/.git`. The other three repositories are independent and use their own remotes. Source photos are stored in `content/`, outside the code repository. Only small text-only regression fixtures remain under `tests/fixtures/`; tests generate disposable images themselves.

Run the following from the code repository (`workspace/lispic`), with the content checkout beside it:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -e .
.venv/bin/lispic check --config ../content/site.sexp
.venv/bin/lispic build --config ../content/site.sexp
.venv/bin/lispic serve --config ../content/site.sexp
```

Open **http://localhost:8000** for the blog and **http://localhost:8001** for the gallery. Environment activation is optional. Installing with `pipx install .` makes `lispic` available from any directory; use `--config` to select your `site.sexp`. A separately installed `hy` may lack the project's dependencies, so use `.venv/bin/hy` for development.

- `check` reads all content, including drafts, and validates syntax, metadata, references, and image files. It does not generate a cache or website.
- `build` generates both websites: `../blog` and `../gallery` with the provided content configuration.
- `serve` builds separate local output in `../content/.preview/{blog,gallery}`, replaces both base URLs with localhost addresses, and starts two loopback servers. The production blog and gallery checkouts are preserved. Stop with Ctrl+C and restart after editing content.
- Change ports with `--port 8100 --gallery-port 8101`.

`serve` also rewrites explicit content and navigation links that start with a configured production origin. Other external links remain external. Preview the site over HTTP rather than opening files through `file://`.

## Content

All configuration paths are relative to `content/site.sexp`. The content repository contains `posts/`, `pages/`, `albums/`, `photos.sexp`, and `originals/`. The configuration writes the blog to `../blog` and the gallery to `../gallery`. Image cache and local preview files stay under the ignored `content/.cache/` and `content/.preview/` directories.

The initial content contains two published posts, one draft, an About page, seven catalog photos, two albums, and a separate post-only image. Its images are labelled technical illustrations with different aspect ratios. The code repository's `tools/make_images.hy` can regenerate those demo images when explicitly given a site directory; it overwrites the named demo files, so use it only for demonstration content. Tests use that tool in a temporary directory and do not read or modify the author's content checkout.

The generated website and example content use Czech. Documentation and source comments use English.

### Posts

Create a file such as `2026-10-18-podzim.sexp` in `sources.posts`:

```lisp
(post {:id "podzim-2026" :title "Autumn outside the city" :slug "podzim-za-mestem"
       :published "2026-10-18T18:30:00+02:00" :labels ["krajina"]}
  (p I left in the morning, just before the rain.)
  (p This time, I was interested in the (em edges) of things.)
  (photo {:ref "pole-01"} A caption for this post.)
  (gallery {:photos ["pole-01" "pole-02"]}))
```

IDs and slugs use lowercase ASCII letters, digits, hyphens, or underscores, without leading or trailing punctuation. `:id` is stable; `:slug` determines `/clanky/{slug}/`. The title becomes the main heading. Renaming a source file does not change its URL.

`:published` is an ISO date/time. When omitted, the filename must start with `YYYY-MM-DD`; local midnight is used. Dates without a UTC offset use the configured time zone. Posts are sorted newest first, with ascending source-file paths breaking ties. `:updated` affects Atom metadata but not ordering. **Future-dated posts are published normally.** `:draft true` excludes a post from output. A link from public content to a draft is an error. `check` validates drafts as well.

Optional `:summary` provides a manual plain-text excerpt. `:randomization false` disables paragraph variations for that post. `:labels` refers to the registry in the configuration. A `page` has `:id`, `:title`, `:slug`, a body like a post, and a `/stranky/{slug}/` URL. Pages are excluded from chronological lists and feeds and are automatically added to navigation.

### Text syntax

- Elements use `(name {attributes} content)`. The attribute dictionary is optional but must precede the content.
- Attributes are data: `:keyword` keys, strings with JSON escaping, numbers, `true`, `false`, lists, nested dictionaries, and keyword values such as `:gallery`. Content is never passed to `eval` or the Hy reader.
- Plain text is the default inside an element. Quotes and semicolons are ordinary text characters. Write literal parentheses and backslashes as `\(`, `\)`, and `\\`. Other body escapes are errors.
- Whitespace and line breaks are normalized. `(p This is (em important).)` produces exactly `<p>This is <em>important</em>.</p>`.
- `pre` preserves whitespace, including inside nested `code`. One separator after the element name or attributes is structural; subsequent whitespace belongs to the content. Parentheses in code must still be escaped.
- Supported elements: `p`, `h1`–`h6`, `em`, `strong`, `a`, `ul`, `ol`, `li`, `blockquote`, `pre`, `code`, `br`, `photo`, and `gallery`.
- `(a {:post "podzim-2026"} Related post)` resolves a post by ID. `(a {:href "https://example.org" :title "Optional title"} External link)` creates a regular link. Script URLs are rejected.
- Text and HTML attribute values are escaped. Raw HTML is not supported.
- Parsed nodes retain source positions. Content errors report a filename, line, and column; metadata errors point to the start of the element.

### Photos

Place an original in `sources.originals` and add a record to `sources.catalog`:

```lisp
(photo {:id "pole-01" :src "pole-01.jpg" :alt "A field under an overcast sky"
        :caption "After the harvest" :gallery true
        :added "2026-10-18T18:00:00+02:00" :taken "2026-10-12"})
```

`:added` is required for public gallery photos and is never changed automatically. The gallery sorts by this date descending, with IDs ascending to break ties. `:taken` is a separate optional capture date. The detail URL `/foto/{id}/` is independent of album membership.

**`:gallery false` does not make a photo private:** posts can publish it through `:ref`. It has no gallery detail page and cannot belong to an album. Its variants are published with the blog only when public content uses it. Photos with `:gallery true` have variants on the gallery origin, which the blog references directly.

`(photo {:ref "pole-01" :alt "Optional override"} Local caption.)` inherits the catalog alt text and caption unless overridden. A gallery photo has a separate detail-page link alongside its lightbox link. Inline galleries use `(gallery {:photos ["pole-01" "pole-02"]})`.

A post-only photo can also use `(photo {:src "images/poznamky.jpg" :alt "Description"} Caption.)`; the path is relative to the post's source file. Paths, including symlink targets, must stay within the applicable source directory. Originals are not copied into the output.

### Albums

Add a file in `sources.albums`:

```lisp
(album {:id "podzim" :title "Autumn" :slug "podzim"
        :photos ["pole-03" "pole-01" "pole-02"] :reorder false}
  (p A manually selected collection.))
```

The list defines the order, and photos can belong to multiple albums. Every member must have `:gallery true`. A tall member of the current two-row group may appear first on the left; all other photos retain their relative order. `:reorder true` permits a wider local search. The DOM and lightbox always retain the original list order.

## Images and cache

Pillow applies EXIF orientation first, then converts an embedded ICC profile to sRGB. An invalid or unsupported profile produces an error naming the file. Images without profiles are assumed to use sRGB; unprofiled CMYK is converted with Pillow's standard RGB conversion. Export to sRGB beforehand when color accuracy matters. Transparency is composited over white. Public variants contain no EXIF, GPS, or original ICC metadata; pixel data is already in sRGB.

Default long-edge lengths are 480, 960, 1600, and 2400 px. Images are never enlarged, and duplicate actual sizes are generated only once. JPEG quality is 88 and WebP quality is 85. HTML includes `picture`, `srcset`, `sizes`, dimensions, and lazy loading. The gallery updates `sizes` to match each tile's actual width. The largest generated variant is used for enlarged viewing.

The cache key includes the original file's SHA-256 digest, conversion settings, pipeline version, and Pillow version. Text edits do not reconvert unchanged images. The cache can be deleted and is not deployed. Old cache entries are not pruned automatically. RAW development and animation are outside the first version's scope; use finished JPEG, PNG, WebP, or TIFF exports.

## Layout and paragraphs

`lispic/static/layout.js` is a pure function with no DOM dependencies. It computes justified rows and two-row groups with one tall panorama. Aspect ratios are preserved, complete rows fill the available width, and the last row may remain shorter. The two-row solution accounts for gaps, aspect ratios, and the target height; unsuitable candidates fall back to ordinary rows. Containers narrower than `tall-min-width` use ordinary rows. `ResizeObserver` triggers recalculation without waiting for images to load.

Without wider searching enabled, the tall photo is selected from the first four members of the local group; wider searching examines up to `lookahead + 1`. Groups of up to 12 photos are considered, with both right-hand rows kept roughly between 0.5 and 1.8 times the target height. Configure these heuristic limits through `local-lookahead`, `group-limit`, `min-height-factor`, `max-height-factor`, and `max-score`. In the all-photos overview, a photo cannot move ahead of a photo from another added day, interpreted in the configured time zone. Reordering never crosses pagination boundaries.

Paragraph variations use SHA-256 over the site seed, post ID, normalized paragraph structure (or its explicit `:id`), and parameter name. Adding an unrelated paragraph leaves existing variations unchanged. Identical paragraphs without IDs receive identical variations; explicit IDs distinguish them. Text edits change the variations unless an explicit ID is used. Font size is based on `rem`, so nesting does not multiply variations. Mobile margins have a separate, smaller range. Feeds, captions, and navigation have no paragraph variations.

## Feeds and archives

The blog publishes `/atom.xml`, `/rss.xml`, `/archiv/`, `/labels/{id}/` pages, and paginated post lists. The gallery has no feed. Each entry contains an excerpt, the first photo (including the first member of an inline gallery), and a continuation link. Without a manual summary, excerpts use ordinary paragraphs directly inside the post, excluding quotations, code, headings, and captions. The target is 500 characters, preferring paragraph or sentence boundaries between 300 and 650 characters; otherwise the text is cut at a word boundary and given an ellipsis. Common Czech abbreviations and numbers reduce incorrect sentence splits; this is a lightweight heuristic.

Each entry's UUIDv5 derives from `blog.identity` and the post ID. Changing the title, slug, CSS, or seed changes neither the entry ID nor its update timestamp. Keep `blog.identity` unchanged after publication. RSS uses publication dates; Atom includes both publication and update dates. An empty feed uses the Unix epoch, 1970-01-01, rather than the build time.

## Configuration and publishing

The complete working configuration is `../content/site.sexp`. A text-only regression configuration is also kept in `tests/fixtures/site/site.sexp`; it uses temporary `dist/` outputs for isolated tests. [docs/configuration.md](docs/configuration.md) describes every setting and default. Allowed per-document overrides are `post.randomization` and `album.reorder`; other values come from site configuration and built-in defaults. Document metadata belongs in content files.

For your own website, edit the content repository's URLs, author, titles, content, and stable blog identity. After `build`, commit generated changes separately in `../blog` and `../gallery`, or upload their **contents** to the corresponding origin roots. The code, source content, blog output, and gallery output can each use a different remote; configure and push them independently. Lispic does not run Git commits or pushes. Hosting must serve directories through `index.html` and provide correct MIME types for JavaScript, CSS, images, and XML. Python and a database are not required on the host. The tool does not perform deployment.

The build prepares both websites in temporary sibling directories before publishing generated files. Publication removes obsolete pages and variants but preserves each destination's `.git`, `.gitignore`, and `.gitattributes`. A fresh repository containing only those Git files is accepted on its first build. Other existing content requires the `.lispic-output` ownership marker. Output paths must not overlap sources, the cache, or each other. Publication is not transactional during disk failure; do not run concurrent builds for the same website.

To inspect changes, run `git -C ../content status`, `git -C ../blog status`, and `git -C ../gallery status` from the code repository. Each output repository tracks only its own generated website, so website content needs no ignore rules in the code repository.

Recorded verification results: [docs/verification.md](docs/verification.md).

## Development and tests

```sh
.venv/bin/python -m pip install -e ".[test]"
.venv/bin/python -m pytest -q
# Pure geometry: Node.js >=22, no npm dependencies required:
node --test tests/layout.test.mjs
# Optional real-browser checks:
npm install
npx playwright install chromium
# Keep the quick-start preview running in another terminal:
node tests/browser.mjs
```

The tests cover parsing, Czech text and punctuation, unsafe links, metadata, ordering, drafts, orientation and ICC conversion, GPS removal, caching, paragraph variations, excerpts, feed identity and XML, local link targets, reproducibility, and obsolete page removal. Geometry tests check overlaps, aspect ratios, full rows, panoramas, and added-day boundaries. Browser tests cover a 1440 px desktop, a 390 px mobile viewport, the lightbox, cross-site navigation, feeds, and basic navigation without JavaScript.

The core modules are `parser.hy`, `model.hy`, `config.hy`, `validation.hy`, `images.hy`, `typography.hy`, `excerpts.hy`, `render.hy`, `feeds.hy`, `build.hy`, and `cli.hy`. `__init__.py` is the only Python bootstrap; tests use Python and JavaScript. See [docs/development.md](docs/development.md) for the module boundaries and implementation notes.

PhotoSwipe **5.4.4** is bundled locally under the **MIT** license. See `lispic/static/PHOTOSWIPE-LICENSE.txt` and [docs/third-party.md](docs/third-party.md). The generated websites use no runtime CDN or external fonts.

The first version has no file watcher, administration interface, automatic redirects for old slugs, RAW pipeline, or search. IDs are not generated automatically, and authors must persist `:added` dates themselves. Validation stops at the first error.
