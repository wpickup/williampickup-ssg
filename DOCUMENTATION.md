# williampickup.org — Site Documentation

A single reference for writing content and operating the generator: front matter fields, layout options, body markup, and the build/deploy pipeline.

## Contents

1. [Overview](#overview)
2. [Quick start](#quick-start)
3. [Directory structure](#directory-structure)
4. [Writing a post](#writing-a-post)
5. [Front matter reference](#front-matter-reference)
6. [Drafts](#drafts)
7. [Topics, categories, and tags](#topics-categories-and-tags)
8. [Layout variants](#layout-variants)
9. [Body markup](#body-markup)
   - [Highlighted text and strikethrough](#highlighted-text-and-strikethrough)
   - [Pull quotes, part labels, pilcrow](#pull-quotes-part-labels-pilcrow)
   - [Blockquotes](#blockquotes)
   - [Quotebacks](#quotebacks)
   - [Code blocks](#code-blocks)
   - [Epigraphs and new-thought](#epigraphs-and-new-thought)
   - [Figures](#figures)
   - [Photo pairs](#photo-pairs)
   - [Sidenotes and margin notes](#sidenotes-and-margin-notes)
10. [Editorial grid layout](#editorial-grid-layout)
11. [Photo essay layout](#photo-essay-layout)
12. [Scroll-reveal animations](#scroll-reveal-animations)
13. [Images (publit.io)](#images-publitio)
14. [Notes](#notes)
    - [Formatting available in notes](#formatting-available-in-notes)
15. [Photos](#photos)
16. [Books](#books)
17. [Static pages](#static-pages)
18. [The /now page](#the-now-page)
19. [Blogroll](#blogroll)
20. [Navigation](#navigation)
21. [Building the site](#building-the-site)
22. [Previewing locally](#previewing-locally)
23. [Deploying](#deploying)
24. [Sending webmentions](#sending-webmentions)
25. [Feeds, sitemap, and robots.txt](#feeds-sitemap-and-robotstxt)
26. [Search](#search)
27. [Templates and CSS](#templates-and-css)
28. [Authoring tools](#authoring-tools)
29. [Builder behaviours and gotchas](#builder-behaviours-and-gotchas)

---

## Overview

The site is a plain Ruby static site generator — no framework (Eleventy, Jekyll, etc.), just `build.rb`, ERB templates, and Kramdown for Markdown. The workflow:

1. Edit source files (`_posts/`, `_drafts/`, `_pages/`, `_data/`, templates, CSS)
2. Run `ruby build.rb` to generate the site
3. Deploy the generated output to the web host

The generator and its source live in `~/Documents/Personal/Web-Development/williampickup-ssg` — deliberately separate from `~/Sites`, which holds only generated output and local server config, never source or tooling.

---

## Quick start

1. Run the **New Post** Nova task → enter a title → file opens ready to write, saved in `_drafts/`
2. Run the **Watch** Nova task → site rebuilds automatically on every save
3. Preview at `http://localhost:4567` (see [Previewing locally](#previewing-locally))
4. When done: run the **Publish Draft** Nova task → pick the file → it moves to `_posts/`, then run **Deploy**

---

## Directory structure

```
williampickup-ssg/
├── _posts/          Markdown files, one per published blog post
├── _drafts/         Markdown files, one per draft post (see "Drafts")
├── _notes/           Markdown files, one per short-form note
├── _photos/         Markdown files, one per gallery photo
├── _books/          Markdown files, one per book
├── _pages/          Markdown files for static pages (bio, blogroll, colophon, search)
├── _data/
│   ├── now.yml        Content for the /now page
│   ├── nav.yml        Header/footer navigation links
│   └── blogroll.yml   Blogroll entries and filter categories
├── _templates/      ERB page templates
├── _partials/       ERB partials (head, header, footer, cards)
├── _out/            Generated site (git-ignored, do not edit directly)
├── css/, javascript/, fonts/, assets/   Static assets, copied into output as-is
├── tools/           Authoring tools associated with the site (see "Authoring tools")
├── extract.rb       One-time migration script (Tinderbox → Markdown) — retired, kept for reference
└── build.rb         Build script — run this to publish
```

CSS, JavaScript, fonts, and images all live inside this repo — edit them here, not anywhere under `~/Sites`. `build.rb` copies `css/`, `javascript/`, `fonts/`, and `assets/` into the output directory verbatim on every build.

---

## Writing a post

New posts start as drafts. Create a file in `_drafts/` named `your-slug.md` (or use the **New Post** Nova task, which does this for you and opens the file ready to write):

```markdown
---
title: "Your Post Title"
slug: your-slug
date: 2026-06-17
description: "One-sentence description for SEO and feeds."
lede: "Optional longer intro shown on the blog listing card."
categories: [Books]
tags: [reading, craft]
topics: [books-ideas]
image_url: https://media.publit.io/file/your-image.jpg
image_focal_point: "50% 30%"
use_featured_image: true
---

Your post content in Markdown here.
```

**Required:** `title`, `slug`, `date`
**Everything else is optional** — see the full [front matter reference](#front-matter-reference) below.

Run `ruby build.rb --drafts` to preview it at `drafts/your-slug.html` with a draft banner.

---

## Front matter reference

### Required

```yaml
title: The post title
slug: the-post-slug         # URL: /posts/slug.html — use lowercase-with-hyphens
date: 2026-06-18
```

### Recommended

```yaml
description: One sentence shown in blog cards and meta tags.
topics:
  - books-ideas             # First topic drives the card colour — see "Topics, categories, and tags"
```

### Images

```yaml
image_url: https://media.publit.io/file/your-image.jpg
image_focal_point: 50% 30%  # CSS object-position, controls crop on card thumbnails
use_featured_image: true    # Show image as hero at top of post page (default: false)
```

`image_url` without `use_featured_image` still shows a thumbnail on the blog card.

### Layout and style

```yaml
layout: standard            # standard · editorial · feature · dispatch · photo-essay
                             # (omit for standard — it is the default)
accent: dark                # Reserved for a future per-post colour override — not yet wired to any CSS; leave blank
has_sidenotes: true          # Required if the post contains sidenote markup — see "Sidenotes and margin notes"
```

### Classification

```yaml
categories:
  - Books                   # Freeform label — any string works, drives /categories/Name.html
topics:
  - books-ideas              # Fixed set — see "Topics, categories, and tags" for valid values
tags:
  - photography              # Freeform — shown on the post, filterable, no archive page generated
```

### Status

```yaml
featured: true    # Appears in "Start here" on home page; hidden from blog listing
```

See [Drafts](#drafts) for how draft status actually works — it's primarily about which folder the file is in, not a front matter field.

---

## Drafts

Draft status is determined by **location**, not a front matter flag:

- **`_drafts/`** — always a draft, regardless of front matter. This is where new posts should live while you're writing them. Excluded from `ruby build.rb` (production); included, with an amber "Draft" banner, when you pass `--drafts`. Never reaches the live server, even on an accidental `--drafts` deploy — the rsync step separately excludes `drafts/` too.
- **`_posts/`** — always published, unless you manually add `draft: true` to its front matter (a rarely-needed override for pulling a published post back without physically moving the file).

To publish, move the file from `_drafts/` to `_posts/`:

- **Publish Draft** Nova task — pick the file from a list; uses `git mv` so history is preserved
- Manually: `git mv _drafts/your-slug.md _posts/your-slug.md`

Then run `ruby build.rb` and the post appears at `posts/your-slug.html`.

**Notes work differently — this is the one important exception.** Unlike posts, a note is *never* drafted by which folder it's in; `_notes/` is the only folder notes ever live in, drafted or not. Draft status for a note comes entirely from `draft: true` in its own front matter, set and later removed **in place** — there's no `_drafts/` → `_notes/` move, and no "Publish Draft" Nova task for notes (that task only scans `_drafts/` and only moves things into `_posts/`). A draft note still builds to `drafts/slug.html`, with the same banner and the same exclusion from production, `--drafts` behaves identically either way — only the *mechanism* for marking a note as a draft differs from a post's.

The **New Note** Nova task creates files directly in `_notes/` with `draft: true` already set, for exactly this reason.

---

## Topics, categories, and tags

Three different classification systems, each doing a different job:

| | Purpose | Values | Archive page |
|---|---|---|---|
| **`topics`** | Drives card accent colour; the primary classification | Fixed set — see table below | `/topics/slug.html` |
| **`categories`** | Freeform label shown on the post | Any string | `/categories/Name.html` |
| **`tags`** | Freeform, finer-grained | Any string | None generated currently |

A post can belong to more than one topic — list all that apply; the **first one wins** for card colour.

### Valid topic keys

| Topic key | Label | Colour |
|---|---|---|
| `books-ideas` | Books and Ideas | Slate blue |
| `learning-making` | Learning and Making | Clay |
| `simple-living` | Simple Living | Sage green |
| `places-experiences` | Places and Experiences | Ochre |
| `systems-thinking` | Systems Thinking | Violet |
| `health-wellbeing` | Health and Wellbeing | Dusty rose |

---

## Layout variants

Set with `layout:` in front matter. Default is `standard` (omit the field).

**`standard`** — Prose with a drop-cap on the first paragraph. Optional hero image above the body. Good for most posts.

**`editorial`** — A twelve-column CSS grid that activates on screens 1000px and wider, with a wider text column and column-based figure/text placement. See [Editorial grid layout](#editorial-grid-layout) for the full class reference.

**`feature`** — Hero image fills the top of the page; title and date overlay it. Use when the image is integral to the post — the reader arrives through the image. Requires `image_url` and `use_featured_image: true`.

**`dispatch`** — Narrower, newsletter-style column (`--post-max-w: 640px`). Date is prominent. Good for short link-posts, brief observations, or things written quickly.

**`photo-essay`** — Body images run in a two-column grid on wide screens; prose and images share equal weight. See [Photo essay layout](#photo-essay-layout).

---

## Body markup

Posts are written in Markdown (Kramdown). Standard Markdown applies throughout — the additions below give richer layouts within the body. Most work in any layout; a few (editorial grid columns) only apply inside `layout: editorial`.

### Highlighted text and strikethrough

Wrap with `==` on each side for a highlight:

```markdown
This is the ==key conclusion== of the argument.
```

Renders as `<mark>` with a translucent accent-colour background. Works inline within any paragraph, list item, or blockquote. Handled server-side in `build.rb`'s `md_to_html`, so it works identically regardless of JavaScript.

Wrap with `~~` on each side for rhetorical strikethrough:

```markdown
~~The old approach was fine.~~ ==The new one changes everything.==
```

Renders as faded `<del>` text. Most powerful immediately followed by a `==highlighted==` replacement — the crossed-out thought and its correction sit side by side.

### Pull quotes, part labels, pilcrow

**Pull quote** — a single sentence given generous space:

```html
<p class="pullquote">The most important kind of freedom is to be what you really are.</p>
```

Centred, italic, display-sized Cormorant Garamond. Best used once per post, for the essay's core sentence.

**Part label** — a small section marker for essay-length posts:

```html
<p class="part-label">part one.</p>

## The argument
```

Tiny, letter-spaced, lowercase. Pair it with an `## H2` heading immediately after.

**Pilcrow** — a visual pause without a heading break: paste the character `¶` directly on its own line. No CSS needed, no markup — just the Unicode character.

### Blockquotes

Standard Markdown blockquote — gets an accent left-border:

```markdown
> The most important kind of freedom is to be what you really are.
```

Add a cite line:

```markdown
> The most important kind of freedom is to be what you really are.
> — Jim Morrison
```

### Quotebacks

A richer attributed-quote treatment, auto-detected client-side (in `main.js`) from a specific blockquote shape — no special class needed in the Markdown itself. The convention: the blockquote's **last paragraph** starts with an em-dash or en-dash (`—` or `–`) and contains a link:

```markdown
> Quote text here.
>
> — Author Name, [Article Title](https://example.com)
```

On page load, JS detects any matching blockquote inside a post, a single note, or the notes listing, pulls the link's URL and text as the citation, treats the text before the first comma as the author, and rewrites the attribution line into a styled `<footer><cite>` — removing the plain attribution paragraph and adding the `quoteback` class. The result looks like:

> Quote text here.
> — Author Name, *Article Title*

with the citation styled distinctly from a plain `— Author Name` blockquote. If the blockquote's last paragraph doesn't start with a dash, or has no link, it's left as an ordinary blockquote.

`post.html.erb` also loads the external [Quotebacks.org](https://quotebacks.org) widget script, and `site.css` has a `quoteback-component` CSS hook for it — this supports embedding a `<quoteback-component>` custom element generated by that tool's browser extension, as an alternative to writing the blockquote convention above by hand. No post currently uses it; the auto-promoted blockquote is the tested, primary path.

### Code blocks

Fenced code blocks with a language tag get syntax highlighting via Prism.js (loaded from a CDN, themed to match light/dark mode):

````markdown
```ruby
def hello
  puts "hi"
end
```
````

No post currently uses this, but the CSS and CDN import are wired up and ready — just write a normal fenced code block with a language identifier.

### Epigraphs and new-thought

**Epigraph** — an opening quote treatment, distinct from an inline blockquote (Cormorant Garamond, italic, larger, with an optional `<footer>` for attribution):

```html
<div class="epigraph">
  <p>Not all those who wander are lost.</p>
  <footer>J.R.R. Tolkien</footer>
</div>
```

**New-thought** — small caps for the opening words of a section, a Tufte-style convention for marking a fresh train of thought without a full heading:

```html
<p><span class="newthought">This is new</span> — the rest of the paragraph continues normally.</p>
```

### Figures

Plain image with caption (standard width):

```html
<figure>
  <img src="https://media.publit.io/file/image.jpg" alt="Description">
  <figcaption>Caption text</figcaption>
</figure>
```

#### Figure size modifiers

| Class | Effect |
|---|---|
| `figure--wide` | Breaks outside the text column on wide screens |
| `figure--full` | Full viewport width |
| `figure--small` | Max 132px wide |
| `figure--half` | Half-width (used in photo-essay grid) |
| `figure--portrait` | Portrait crop (used in photo-essay grid) |
| `figure--float-left` | Floats left, text wraps (collapses on mobile) |
| `figure--float-right` | Floats right, text wraps (collapses on mobile) |
| `figure--video` | Responsive iframe/video embed |

Combine modifiers: `class="figure--small figure--float-left"`

**Video embed:**

```html
<figure class="figure--video">
  <iframe src="https://www.youtube.com/embed/VIDEO_ID"
    allowfullscreen loading="lazy"></iframe>
</figure>
```

### Photo pairs

Two images side by side (collapses to a single column on mobile):

```html
<div class="photo-pair">
  <figure>
    <img src="…" alt="…">
    <figcaption>Left image</figcaption>
  </figure>
  <figure>
    <img src="…" alt="…">
    <figcaption>Right image</figcaption>
  </figure>
</div>
```

### Sidenotes and margin notes

Two separate systems for putting content in a margin — pick based on layout and purpose, not interchangeably (see the comparison table under [Editorial grid layout](#editorial-grid-layout) if the post uses `layout: editorial`).

**Sidenotes** — numbered, footnote-style, works in any layout at any width. Requires `has_sidenotes: true` in front matter. Each sidenote needs a unique checkbox `id` per post (`sn1`, `sn2`, …):

```html
<span class="sidenote sidenote-numbered">
  <input type="checkbox" id="sn1" class="sidenote-checkbox">
  <label for="sn1" class="sidenote-toggle"></label>
  <span class="sidenote-content">The sidenote text goes here.</span>
</span>
```

On wide screens (900px+) sidenotes float into the right margin. On narrow screens they collapse to a tap-to-expand toggle. Increment the `id` for each note: `sn1`, `sn2`, `sn3`, …

**Margin notes** — a simpler, unnumbered variant with no toggle, no counter, and no `has_sidenotes` requirement:

```html
<span class="marginnote">A brief aside, uncounted.</span>
```

Same float-right-margin behaviour on wide screens, collapses to a plain inline block (not a toggle) on narrow screens. Use this for asides that don't need footnote numbering.

---

## Editorial grid layout

For `layout: editorial` only. A twelve-column CSS grid that activates on screens 1000px and wider. Text sits in a comfortable central column (columns 3–9). Images and text blocks can be promoted to wider column spans using CSS classes on the element. Below 1000px, everything collapses to a single readable column.

### Figure classes

```html
<figure class="figure--full">
  <img src="https://..." alt="Alt text">
  <figcaption>Caption</figcaption>
</figure>
```

| Class | Column span | Use for |
|---|---|---|
| *(none)* | text column | Default inline image |
| `figure--wide` | 2 cols wider than text | Landscape photos, diagrams |
| `figure--full` | Full container width | Dramatic scene-setting images |
| `figure--half` | Half the text column | Portrait images, paired figures |
| `figure--float-left` | Left margin (3 cols) | Small image in left gutter |
| `figure--float-right` | Right margin (4 cols) | Small image in right gutter |

### Text block classes

```html
<div class="col--margin-right">A bibliographic note or aside.</div>
```

| Class | Column span | Use for |
|---|---|---|
| `col--wide` | 1 col wider each side | Subheadings, intro paragraphs |
| `col--narrow` | Narrower than text | Captions, short notes |
| `col--full` | Full width | Dividers, section breaks |
| `col--left` | Left-anchored text column | Text shifted to left half of grid |
| `col--right` | Right-anchored text column | Text shifted to right half of grid |
| `col--margin-right` | Right gutter (cols 10–12) | Short asides, captions |
| `col--margin-left` | Left gutter (cols 1–2) | Short asides, captions |
| `pullquote` | Wide centred (cols 2–11) | Stand-out quotes |

`col--left` and `col--right` use the same 7-column width as the default text column, just repositioned. A `col--left` paragraph followed by a `col--right` paragraph puts two text blocks side by side on the same row — useful for a zig-zag or two-voice layout.

### How margin notes share a row with adjacent content

Margin notes work by claiming their gutter column before auto-placement reaches the adjacent text. CSS Grid fills left-to-right across each row, so **source order determines row-sharing**:

**`col--margin-right` (cols 10–12)** — place it **before** the element it should sit beside:

```markdown
<div class="col--margin-right">Sennett, *The Craftsman* (2008).</div>

## The heading this note sits beside
```

**`col--margin-left` (cols 1–2)** — place it **after** the element it should sit beside:

```markdown
## The heading this note sits beside

<div class="col--margin-left">A left-gutter note.</div>
```

The element occupying the earlier columns in the row must appear first in the source.

### Margin notes vs. sidenotes — which one to use

| | `col--margin-left` / `col--margin-right` | Sidenotes / margin notes (`.sidenote`, `.marginnote`) |
|---|---|---|
| Works in | `layout: editorial` only, 1000px+ screens | Any layout, any width |
| Mechanism | CSS Grid column placement | CSS `float: right` |
| Numbering | None | `.sidenote-numbered` only |
| Mobile behaviour | Falls back to a plain full-width block below 1000px | Collapses to inline block or tap-to-expand toggle |
| Side | Left or right | Right only |
| Built for | Short asides or captions that align beside a specific block in the grid | Citations and footnote-style annotations in continuous prose |

**Rule of thumb:** if the post uses `layout: editorial`, use `col--margin-left`/`col--margin-right` for asides — they're part of the grid system. For a standard single-column post that needs numbered footnotes or citations, use sidenotes or margin notes instead. Don't mix sidenote markup into an editorial post or vice versa — the two systems assume different parent layouts and will not interact correctly.

---

## Photo essay layout

For `layout: photo-essay`, images in the body run in a two-column grid. Use `figure--half` for standard portrait/landscape pairs, `figure--portrait` for tall portrait crops:

```html
<figure class="figure--half">
  <img src="…" alt="…">
</figure>

<figure class="figure--portrait">
  <img src="…" alt="…">
</figure>
```

Odd-numbered figures go in the left column, even-numbered in the right. `figure--wide` and `figure--full` break out of the grid entirely. `photo-pair` (see [Photo pairs](#photo-pairs)) creates a manual side-by-side within the grid if needed.

---

## Scroll-reveal animations

Post cards, gallery items, section headers, and the home masthead all fade or slide into view as they scroll into the viewport — automatic, no markup needed for those. The same system is available for any element in post content via a `reveal` class.

**How to use it:** add `class="reveal"` to any element — a `<figure>`, a `<div>`, a paragraph — optionally with a direction modifier and a speed modifier:

```html
<figure class="figure--wide reveal reveal--left reveal--slow">
  <img src="https://..." alt="Alt text">
</figure>
```

| Direction modifier | Effect |
|---|---|
| `reveal` (no modifier) | Fade up — the site default |
| `reveal--left` | Slide in from the left |
| `reveal--right` | Slide in from the right |
| `reveal--fade` | Plain fade, no movement |
| `reveal--up` | Same as no modifier — explicit fade-up |

| Speed modifier | Duration |
|---|---|
| *(none)* | 0.55s — the site default |
| `reveal--faster` | 0.18s |
| `reveal--fast` | 0.32s |
| `reveal--slow` | 0.9s |
| `reveal--slower` | 1.2s |

Direction and speed modifiers combine freely — `class="reveal reveal--right reveal--fast"` slides in from the right at the faster speed. Stick to one direction and one speed per element (adding two of the same kind just lets CSS specificity pick a winner).

The animation triggers once, the first time the element scrolls into view, via an `IntersectionObserver` in `main.js`. Respects `prefers-reduced-motion` automatically. If an element is already in the initial viewport on load (e.g. a short draft), the animation plays immediately instead of waiting for a scroll. Works in any layout — `reveal` is general-purpose, independent of the editorial grid.

---

## Images (publit.io)

The site uses [publit.io](https://publit.io) for image hosting. The build generates responsive `srcset` automatically for any `image_url` pointing at `media.publit.io/file/`, by inserting `/w_{n}/` into the URL path for each breakpoint.

In body content, use the direct publit URL as-is in `<img src="…">` — the browser picks the right size via `srcset` when the image is a card or hero; for images inline in the body, the plain URL works fine on its own.

**Focal point** controls which part of the image stays visible when cropped. Format: `"X% Y%"` (CSS `object-position`) — e.g. `"50% 20%"` keeps the top-centre in frame.

For uploading new images, see [Authoring tools](#authoring-tools).

---

## Notes

Notes are short, informal entries — observations, links, brief thoughts — with their own dedicated stream, separate from the main blog. They live in `_notes/`, are listed at `/notes.html`, and get a "Recent notes" card on the home page. They do **not** appear mixed into `/blog.html` alongside posts.

### Front matter

```yaml
slug: note-slug           # URL: /notes/slug.html
date: 2026-06-18
title: Optional title     # omit for untitled notes
draft: true                 # unlike posts, this is the ONLY way to draft a note — see "Drafts"
```

Create a new draft note with the **New Note** Nova task — it writes straight into `_notes/` with `draft: true` already set (never into `_drafts/`, which is posts-only). To publish, remove the `draft: true` line from the file in place; there's no move and no "Publish Draft" task for notes.

### Behaviour

- Listed at `/notes.html`, sorted newest-first
- Show full body text inline — no "read more"
- Have their own permalink at `/notes/slug.html`
- Untitled notes show just the date and body; add a `title` for a titled entry
- Not included in RSS/Atom (feeds are posts-only) or the home page's "Recent writing" grid — they have their own home page card instead

### Formatting available in notes

Notes render into a different HTML wrapper (`.note-single__body` / `.notes-list__body`) than posts (`.post-body`), and most of [Body markup](#body-markup)'s formatting is scoped specifically to that `.post-body` class — so not everything documented there works in a note.

**Works in notes:** standard Markdown, `==highlighted==`/`~~strikethrough~~`, [quotebacks](#quotebacks), [pull quotes](#pull-quotes-part-labels-pilcrow), epigraphs, new-thought, the pilcrow, and [scroll-reveal](#scroll-reveal-animations) (`reveal`, `reveal--*`).

**Post-only, not available in notes:** figure size modifiers, photo pairs, code block syntax highlighting, the [editorial grid](#editorial-grid-layout) (notes have no `layout` field at all), and sidenotes (the CSS isn't strictly blocked, but the numbering counter never initializes for a note, so a hand-written sidenote would render with broken numbering).

Quotebacks and pull quotes render identically whether a note is viewed on its own permalink page or inline on the `/notes.html` listing — both surfaces show a note's full body, so both get the same styling.

---

## Photos

Each photo is a file in `_photos/`:

```yaml
title: "Photo Title"
slug: photo-slug
date: 2026-06-01
image_url: https://media.publit.io/file/photo.jpg
image_alt: "Description of the image"
image_size: wide       # wide, full, or portrait
focal_point: "50% 40%"
location: "Sydney, Australia"
camera: "Fujifilm X100V"
caption: "Optional caption text."
series: highlights     # use "highlights" to include in gallery/highlights.html
featured: false
tags: [travel, coast]
```

---

## Books

Each book is a file in `_books/`:

```yaml
title: "Book Title"
slug: book-slug
author: "Author Name"
status: reading        # or: read
date_read: 2026-05-01  # leave blank if still reading
isbn: "9780571337118"
cover_url:              # leave blank — Open Library cover is used automatically via ISBN
on_now_page: true      # shows in the Reading section of the /now page
```

Books with `status: reading` appear under "Currently Reading" on `/reading.html` and on `/now.html` (if `on_now_page: true`). Books with `status: read` appear under "Read".

---

## Static pages

`_pages/*.md` (bio, blogroll, colophon, search) use the same Markdown + front matter format. The `template:` key selects which ERB template to use:

```yaml
title: "About"
slug: bio
description: "About William Pickup."
template: bio       # matches _templates/bio.html.erb
```

`bio`, `blogroll`, `colophon`, and `search` each have a dedicated template. Adding a new static page means both a `_pages/*.md` file and a matching `_templates/*.html.erb` file — see [Builder behaviours and gotchas](#builder-behaviours-and-gotchas) for what every template needs to include.

---

## The /now page

Edit `_data/now.yml`:

```yaml
updated: 2026-06-17
sections:
  making: "What you're making right now."
  travelling: "Where you're travelling or planning to go."
  growing: "What's happening in the garden."
  thinking_about: "What's on your mind."
```

`making` and `travelling` also appear in a condensed strip on the home page; `growing` and `thinking_about` are shown on `/now.html` only. Books with `on_now_page: true` and `status: reading` appear automatically in the Reading section.

**Plain text only — no links or markdown.** Each section is passed through `h()` (HTML-escape) before output, so `[a link](https://...)` or `<a href="...">` renders as literal text, not a clickable link. This is deliberate — YAML strings are simpler to write than markdown-in-YAML — but it does mean you can't casually drop a link into a `/now` update the way you might in a post. If you want to point somewhere, write the URL out in full as plain text (`see https://example.com`), or write the news as a short note or post instead, both of which do support markdown.

---

## Blogroll

`_data/blogroll.yml` powers `/blogroll.html`:

```yaml
filters:
  - bloggers
  - craft
  - life

entries:
  - name: "The Marginalian"
    url: "https://www.themarginalian.org"
    feed: "https://feeds.feedburner.com/brainpickings/rss"
    category: life
    desc: "Maria Popova — marginalia on the search for meaning."
```

`filters` lists every category used for the page's filter buttons — a category on an entry that isn't in `filters` won't get a working filter button. `feed` is the site's RSS/Atom URL, used by client-side JS to show its most recent post (see `javascript/blogroll.js`); `desc` is optional.

---

## Navigation

`_data/nav.yml` drives the header and footer link lists — editing it changes the nav site-wide, no template edits needed:

```yaml
header:
  - label: Writing
    href: blog.html
    current: writing    # matches the `current:` local passed to a template, for aria-current highlighting

footer_primary:
  - label: Writing
    href: blog.html
    current: writing

footer_secondary:
  - label: RSS
    href: feeds/rss.xml
  - label: Contact
    href: "mailto:will@williampickup.org"
    email: true          # renders as a plain (non-root-relative) link, for mailto: and similar
```

`header` populates the primary nav; `footer_primary` and `footer_secondary` populate the two footer link groups. `current` should match the `current:` value a template passes when rendering `_header`/`_footer`, so the active page gets `aria-current="page"`.

---

## Building the site

```bash
cd ~/Documents/Personal/Web-Development/williampickup-ssg
ruby build.rb
```

Output goes to `_out/` inside the repo by default. The script prints every file it generates and a summary at the end.

### Writing output somewhere else (`SSG_OUT_DIR`)

To preview the site through a real local server instead of just generating files, set `SSG_OUT_DIR` to redirect the build there instead of `_out/`:

```bash
SSG_OUT_DIR=~/Sites/williampickup.org/_site ruby build.rb
```

CI (the GitHub Actions deploy workflow) never sets this — it always uses the default `_out/`. `deploy.sh` and the Nova build tasks both respect `SSG_OUT_DIR` the same way `build.rb` does.

**Important:** `build.rb` deletes and recreates whatever `OUT_DIR` resolves to on every build. Point it at a dedicated subfolder (like `_site` above), never at a folder that holds anything else you care about — e.g. don't point it directly at `~/Sites/williampickup.org` itself if that folder also holds a `.claude/` config or similar, since it will get wiped on the next build.

### Search index (Pagefind)

`build.rb` does not build the Pagefind search index — the CSS theming for the search UI (`#search`, `.pagefind-ui__*` in `site.css`, and `_templates/search.html.erb`) is wired up, but indexing is a separate step:

```bash
npx pagefind --site _out
```

`deploy.sh` already runs this for you — manual indexing is only needed if you build without it.

---

## Previewing locally

```bash
python3 -m http.server 4567 --directory ~/Sites/williampickup.org/_site
```

Then open `http://localhost:4567` in your browser. The Nova tasks and `.claude/launch.json` in this project already point at this folder via `SSG_OUT_DIR`.

---

## Deploying

`deploy.sh` builds the site, generates the Pagefind search index, and (if you give it a destination) rsyncs `_out/` to the web host — all in one step:

```bash
cd ~/Documents/Personal/Web-Development/williampickup-ssg

# Build + index only, no deploy:
./deploy.sh

# Build, index, and deploy:
DEPLOY_DEST=williampickup:/var/www/htdocs/williampickup.org/ ./deploy.sh
```

`williampickup` is the SSH config alias for the Vultr server (see `~/.ssh/config`) — it already carries the right user and deploy key. Pass `--drafts` as an extra argument to include drafts in the build (they're excluded from the rsync regardless, via `--exclude 'drafts/'`).

Export `DEPLOY_DEST` once per shell session to avoid retyping it:

```bash
export DEPLOY_DEST=williampickup:/var/www/htdocs/williampickup.org/
./deploy.sh   # now deploys every time, no env var needed
```

After a real deploy (`DEPLOY_DEST` set), `deploy.sh` also sends webmentions for any new outbound links and commits the updated state file — see [Sending webmentions](#sending-webmentions).

### Deploying via GitHub Actions

`.github/workflows/deploy.yml` runs the same build → index → rsync → webmention sequence, triggered manually:

```bash
gh workflow run deploy.yml
```

It deliberately does not run on every push to `main` — commits and merges never trigger a production deploy on their own. It needs five repository secrets set under **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `DEPLOY_SSH_KEY` | Private key for a dedicated deploy keypair (not your personal key — generate one scoped just to this, e.g. `ssh-keygen -t ed25519 -f deploy_key -C "github-actions"`, and add its public half to the server's `authorized_keys`) |
| `DEPLOY_HOST` | The server's IP or hostname |
| `DEPLOY_USER` | The SSH user on the server |
| `DEPLOY_PATH` | The webroot path, e.g. `/var/www/htdocs/williampickup.org/` |
| `WEBMENTION_TOKEN` | Your Telegraph token — see [Sending webmentions](#sending-webmentions) |

Add these directly in the GitHub UI, never by pasting key material into chat or a file in the repo. The workflow also needs `contents: write` permission to commit the webmention state file back to the repo — already set in `deploy.yml`, nothing extra to configure.

Triggering the workflow from an iPad or other device without a terminal: use GitHub's REST API directly (`POST` to `.../actions/workflows/deploy.yml/dispatches` with a scoped personal access token), wrapped in an iOS Shortcut for a one-tap deploy.

---

## Sending webmentions

After a successful deploy, `send_webmentions.rb` scans every published post's outbound links and sends a webmention for any that haven't been sent before, via [Telegraph](https://telegraph.p3k.io) — a third-party service that handles endpoint discovery, so the protocol doesn't need implementing directly.

**One-time setup:** sign in at telegraph.p3k.io with your domain to get a token, then make it available in each environment that deploys:

```bash
# Local terminal (deploy.sh reads this automatically):
export WEBMENTION_TOKEN=your-token-here

# Nova-triggered deploys: Nova's GUI task runner may not inherit a
# shell-exported variable, so use a gitignored local file instead:
echo "your-token-here" > .webmention-token

# GitHub Actions: add WEBMENTION_TOKEN as a repository secret
```

Without a token set, `send_webmentions.rb` prints a notice and exits — it never blocks a deploy.

**State tracking:** `_data/webmentions_sent.json` records which (post, target) pairs have already been settled — sent, or definitively rejected by Telegraph as unsupported — so re-deploying doesn't re-send for unchanged posts. Saved incrementally after every single target, so an interrupted run never loses track of what already went out. Committed to the repo (not gitignored), since it's shared state between local deploys and CI.

**Adopting this on a site with an existing backlog:** the first real run treats every published post as new, which would fire webmentions at every outbound link across the entire back-catalogue at once. Run with `--seed` first to mark the existing backlog as already-settled without sending anything:

```bash
ruby send_webmentions.rb --seed
git add _data/webmentions_sent.json && git commit -m "Seed webmention baseline"
```

After that, only posts or links that didn't exist at seed time will ever trigger a real send.

---

## Feeds, sitemap, and robots.txt

Generated automatically on every build — no separate maintenance step, always reflect whatever content currently exists:

- `_out/feeds/rss.xml`, `_out/feeds/atom.xml` — the 20 most recent published posts
- `_out/sitemap.xml` — every post, note, photo, book, and static page. Drafts are always excluded, even when building with `--drafts`
- `_out/robots.txt` — disallows `/drafts/` and points crawlers at the sitemap

---

## Search

Client-side search via [Pagefind](https://pagefind.app), on `/search.html`. The index is built separately from the main site build — see [Search index (Pagefind)](#building-the-site) above.

---

## Templates and CSS

- **Templates** live in `_templates/` as `.html.erb` files, one per page type (or per generated group, like `topic.html.erb` for every topic archive page)
- **Partials** (head, header, footer, post card, note card) live in `_partials/`
- **CSS** is at `css/site.css` in this repo — edit here, rebuild to see changes

After editing a template or CSS file, just run `ruby build.rb` again.

---

## Authoring tools

`tools/Publit Upload.app` — a droplet app for uploading images to publit.io; drag an image onto it, get back a URL to paste into a post's `image_url` front matter. Lives in the repo (not just on the Desktop) since it's specific to this site's authoring workflow — a Finder alias on the Desktop points into `tools/` for convenient access.

---

## Builder behaviours and gotchas

**Reading time** — calculated automatically from word count (~200 wpm), minimum 1 min. Shown on blog cards and in the post header.

**Slugs** — must be unique across all posts. Used as the filename and URL — changing a slug after publishing breaks links.

**Dates** — ISO 8601 format (`2026-06-18`). Posts sorted newest-first throughout the site. Archive pages group by year automatically.

**Build footer stamp** — every page footer shows a UTC build timestamp and short git commit SHA (`built 21 Jun '26, 03:53 UTC  e39d8bf`), generated in `build.rb` from `git rev-parse --short HEAD`. Not a clickable link — the repo is private, so a GitHub link would 404 for every visitor except the owner. Useful for confirming a given deploy actually reflects what was pushed.

**Adding a new template** — `_partials/_head.html.erb` is just the contents of `<head>`: `<meta>` and `<link>` tags only, no `<html>` wrapper. Every template is responsible for writing `<!DOCTYPE html><html lang="en"><head>` itself, rendering the `head` partial inside it, then closing `</head>` before `<body>`. Consistent across every existing template (copy the pattern from any file in `_templates/`), but manual — forgetting to close `</head>` before `<body>` in a new template is a silent bug, not something the builder catches.

**Ruby dependency** — `build.rb` requires the `kramdown` gem; run via `bundle exec ruby build.rb` (or ensure `bundle install` has been run) rather than bare `ruby build.rb` if gems aren't already on the system path. `Gemfile`/`Gemfile.lock` pin the version used in CI.
