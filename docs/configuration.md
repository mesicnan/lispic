# `site.sexp` configuration

The file contains one data dictionary, without comments or executable code. Unknown settings are errors. Omitted settings inherit built-in defaults. A complete working file is provided in `examples/site.sexp`.

| Setting | Default / meaning |
|---|---|
| `language` | `"cs"`, the HTML and RSS language |
| `timezone` | `"Europe/Prague"`, used for dates without offsets and calendar-day movement boundaries |
| `author` | `"Fotograf"`, the footer and Atom author |
| `blog.url` | `"https://blog.example.cz"`, an HTTP(S) origin without a path |
| `blog.title` | `"Zápisník"` |
| `blog.output` | `"dist/blog"` |
| `blog.identity` | `"urn:lispic:my-blog"`, a stable unique URI; keep it unchanged after publication |
| `blog.per-page` | `12`, posts per page on the index, archive, and label pages |
| `gallery.url` | `"https://foto.example.cz"` |
| `gallery.title` | `"Fotografie"` |
| `gallery.output` | `"dist/gallery"` |
| `gallery.per-page` | `60`, photos per page in the all-photos overview; albums are not paginated |
| `sources.posts` | `"content/posts"`, searched recursively for `*.sexp` |
| `sources.pages` | `"content/pages"` |
| `sources.albums` | `"content/albums"` |
| `sources.catalog` | `"content/photos.sexp"`, containing multiple root-level `photo` elements |
| `sources.originals` | `"originals"`, the base directory for catalog photo paths |
| `sources.cache` | `".cache/lispic"` |
| `labels` | `{}`, for example `{:poznamky "Poznámky"}`; registry order determines sidebar order, and counts exclude drafts |
| `images.sizes` | `[480 960 1600 2400]`, long-edge lengths in pixels |
| `images.jpeg-quality` | `88`, in the range 1–100 |
| `images.webp-quality` | `85`, in the range 1–100 |
| `images.webp` | `true`; JPEG is always generated |
| `layout.gap` | `0`, the gap in pixels |
| `layout.target-height` | `260`, the target height of an ordinary row in pixels |
| `layout.tall-ratio` | `2.5`, the minimum height/width ratio for a tall photo |
| `layout.lookahead` | `6`, additional positions examined when wider searching is enabled |
| `layout.tall-min-width` | `700`, the minimum container width for two-row groups |
| `layout.reorder` | `false`, enables wider searching in the all-photos overview; albums use their own explicit `:reorder`, defaulting to `false` |
| `layout.local-lookahead` | `3`, additional candidates within the ordinary local group, even without wider searching |
| `layout.group-limit` | `12`, the maximum number of photos in a candidate two-row group |
| `layout.min-height-factor` | `0.5`, the minimum right-hand row height relative to the target |
| `layout.max-height-factor` | `1.8`, the maximum right-hand row height relative to the target |
| `layout.max-score` | `1.1`, the maximum sum of logarithmic height deviations, plus 0.03 per position moved |
| `feeds.count` | `20`, the maximum number of entries in each blog feed |
| `randomization.enabled` | `true` |
| `randomization.seed` | `"lispic-1"`, the shared site seed |
| `randomization.margin` | `3`, the maximum left and right margins in percent, starting at zero |
| `randomization.mobile-margin` | `1`, the maximum margin for viewports up to 700 px |
| `randomization.font-min` | `98`, the minimum font size as a percentage of the shared base |
| `randomization.font-max` | `102`, the maximum font size |
| `randomization.line-height` | `1.7`, the fixed multiplier of font size |
| `appearance.background` | `"#141618"`, a #RGB or #RRGGBB color |
| `appearance.foreground` | `"#e4e1db"` |
| `appearance.accent` | `"#d2b98a"` |
| `appearance.text-width` | `"44rem"`, the maximum text width; accepted units are rem, em, px, and ch |
| `appearance.navigation` | `[]`, extra links, for example `[{:title "Contact" :href "mailto:me@example.cz"}]` |

Per-document overrides use `(post {... :randomization false} ...)` and `(album {... :reorder true} ...)`. Source IDs, slugs, dates, captions, and album membership belong exclusively in content files.

Changing domains changes absolute URLs but preserves feed identifiers as long as `blog.identity` remains unchanged. The two websites require distinct origins. Local previews always use two different ports.
