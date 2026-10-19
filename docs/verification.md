# First-version verification

Verified on October 19, 2026, using openSUSE Tumbleweed, Python 3.13.16, Hy 1.3.1, and Pillow 12.3.0. Geometry tests ran on Node.js 24.19.0; browser checks used Chromium through Playwright 1.62.1.

- `python -m pytest -q`: **25 tests passed**. Coverage includes parsing and error positions, Czech text, whitespace and escaping, attributes, ordering and filename dates, future-dated publication, drafts and links, photo/album visibility, EXIF/ICC/GPS, dimensions and caching, stable paragraphs, excerpts and first photos, feed XML and identity, pagination, empty catalogs, output path protection, and obsolete page removal.
- `node --test tests/layout.test.mjs`: **5 tests passed**, including deterministic aspect-ratio datasets at widths from 320 to 1920 px. These check aspect ratios, non-overlap, full rows, tall panoramas, and calendar-day boundaries.
- `node tests/browser.mjs`: **passed**. Checks cover a 1440 px desktop and a 390 px mobile viewport, the blog, gallery, an album, images, PhotoSwipe opening/advancing/closing, actual container resizing, navigation between the local websites, HTTP retrieval of both feeds, and detail/larger-image navigation with JavaScript disabled. The test recorded no JavaScript errors or unsuccessful HTTP responses.
- Desktop overview and mobile post screenshots were also visually inspected.
- A wheel was built and installed with its dependencies into a new virtual environment. `check` and `build` ran against a separate copy of the example content. Commands ran outside the repository, with imports confirmed to come from the installed package.
- `pip check`: no broken requirements.

## Known limitations

- The preview has no file watcher. Restart `serve` after editing.
- Layout uses a deterministic local heuristic rather than global optimization. Extreme aspect ratios can produce unusually short or tall ordinary rows.
- Links and images work without JavaScript; the exact justified/two-row layout and lightbox require JavaScript.
- Excerpts use a limited list of Czech abbreviations and simple sentence boundaries. A manual `summary` takes precedence.
- Originals are not copied, RAW files are not developed, and old image cache entries are not pruned automatically.
- Slug changes do not create automatic redirects. Stable IDs persist, but hosting must provide any redirects for old URLs.
- Both outputs are prepared before old directories are replaced, but replacement is not a shared transaction during disk failure. Concurrent builds of the same website are unsupported.
- Automated browser checks cover Chromium; Firefox and Safari were not run separately.
