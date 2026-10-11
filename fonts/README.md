# Self-hosted fonts

All web fonts are served from this directory; no Google Fonts or other font CDN is used. `build.rb` copies `fonts/` into the output unchanged, and the `@font-face` rules at the top of `css/site.css` point at these files with relative paths (`../fonts/…`).

The files came from [google-webfonts-helper](https://gwfh.mranftl.com/fonts/), `latin` subset, woff2 only.

## Cormorant Garamond (display face, 5 files)

| File | Weight | Style |
|------|--------|-------|
| `cormorant-garamond-v21-latin-300.woff2` | 300 (Light) | normal |
| `cormorant-garamond-v21-latin-regular.woff2` | 400 (Regular) | normal |
| `cormorant-garamond-v21-latin-500.woff2` | 500 (Medium) | normal |
| `cormorant-garamond-v21-latin-300italic.woff2` | 300 (Light) | italic |
| `cormorant-garamond-v21-latin-italic.woff2` | 400 (Regular) | italic |

## Jost (body face, 3 files)

| File | Weight | Style |
|------|--------|-------|
| `jost-v20-latin-300.woff2` | 300 (Light) | normal |
| `jost-v20-latin-regular.woff2` | 400 (Regular) | normal |
| `jost-v20-latin-500.woff2` | 500 (Medium) | normal |

## Adding or updating a font file

1. Download the new woff2 file from google-webfonts-helper into this directory.
2. Add or update the matching `@font-face` rule at the top of `css/site.css`. If the version number in the filename changed (e.g. `v21` → `v22`), update the `src:` URL too.
3. Delete any file that's no longer referenced, then rebuild.

The font stacks are defined in `site.css` as `--font-display` (Cormorant Garamond, then Georgia) and `--font-body` (Jost, then `system-ui`). Every `@font-face` rule uses `font-display: swap`.
