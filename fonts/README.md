# Self-hosted fonts

Download these files from https://gwfh.mranftl.com/fonts/ and place them in this directory.

## Cormorant Garamond (5 files)

Search for "Cormorant Garamond", select subsets: **latin**

| File | Weight | Style |
|------|--------|-------|
| `cormorant-garamond-v22-latin-300.woff2` | 300 (Light) | normal |
| `cormorant-garamond-v22-latin-regular.woff2` | 400 (Regular) | normal |
| `cormorant-garamond-v22-latin-500.woff2` | 500 (Medium) | normal |
| `cormorant-garamond-v22-latin-300italic.woff2` | 300 (Light) | italic |
| `cormorant-garamond-v22-latin-italic.woff2` | 400 (Regular) | italic |

## Jost (3 files)

Search for "Jost", select subsets: **latin**

| File | Weight | Style |
|------|--------|-------|
| `jost-v14-latin-300.woff2` | 300 (Light) | normal |
| `jost-v14-latin-regular.woff2` | 400 (Regular) | normal |
| `jost-v14-latin-500.woff2` | 500 (Medium) | normal |

## Activating self-hosted fonts

Once the 8 woff2 files are in this directory:

1. In `tokens.css` — uncomment the `/* SELF-HOSTED FONTS */` block near the top
2. In `/Boilerplate/core-head-links` in Tinderbox — remove the three Google Fonts `<link>` lines
   (preconnect googleapis, preconnect gstatic, and the stylesheet link)
3. Re-export all pages and upload fonts/ directory to live server

The @font-face rules use absolute paths (`/fonts/...`) so they work at any nesting depth.
