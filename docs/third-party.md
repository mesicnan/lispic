# Bundled browser dependencies

PhotoSwipe 5.4.4, by Dmitry Semenov, licensed under MIT.

Source: https://github.com/dimsemenov/PhotoSwipe/tree/v5.4.4
Documentation: https://photoswipe.com/

The bundled files come from the `photoswipe@5.4.4` package:

- `dist/photoswipe.esm.js`
- `dist/photoswipe-lightbox.esm.js`
- `dist/photoswipe.css`
- `LICENSE` → `PHOTOSWIPE-LICENSE.txt`

The build copies them into both outputs. The generated websites need neither npm nor a CDN at runtime. To update PhotoSwipe, replace these four files together and rerun the lightbox tests.
