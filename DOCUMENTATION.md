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
8. [Series](#series)
9. [Layout variants](#layout-variants)
10. [Body markup](#body-markup)
   - [Highlighted text and strikethrough](#highlighted-text-and-strikethrough)
   - [Pull quotes, part labels, pilcrow](#pull-quotes-part-labels-pilcrow)
   - [Blockquotes](#blockquotes)
   - [Quotebacks](#quotebacks)
   - [Code blocks](#code-blocks)
   - [Epigraphs and new-thought](#epigraphs-and-new-thought)
   - [Figures](#figures)
   - [Photo pairs](#photo-pairs)
   - [Sidenotes and margin notes](#sidenotes-and-margin-notes)
11. [Editorial grid layout](#editorial-grid-layout)
12. [Photo essay layout](#photo-essay-layout)
13. [Scroll-reveal animations](#scroll-reveal-animations)
14. [Images (publit.io)](#images-publitio)
15. [Notes](#notes)
    - [Formatting available in notes](#formatting-available-in-notes)
    - [Promoting a note to a post](#promoting-a-note-to-a-post)
16. [Journeys](#journeys)
17. [Photos](#photos)
18. [Books](#books)
19. [Static pages](#static-pages)
20. [The home page](#the-home-page)
21. [The /now page](#the-now-page)
22. [Blogroll](#blogroll)
23. [Navigation](#navigation)
24. [Building the site](#building-the-site)
25. [Previewing locally](#previewing-locally)
26. [Deploying](#deploying)
27. [Webmentions](#webmentions)
28. [Feeds, sitemap, and robots.txt](#feeds-sitemap-and-robotstxt)
29. [Search](#search)
30. [Templates and CSS](#templates-and-css)
31. [Authoring tools](#authoring-tools)
    - [Nova tasks](#nova-tasks)
    - [Taxonomy cheatsheet](#taxonomy-cheatsheet)
32. [Builder behaviours and gotchas](#builder-behaviours-and-gotchas)

---

## Overview

The site is a plain Ruby static site generator — no framework (Eleventy, Jekyll, etc.), just `build.rb`, ERB templates, and Kramdown for Markdown. The workflow:

1. Edit source files (`_posts/`, `_drafts/`, `_pages/`, `_data/`, templates, CSS)
2. Run `ruby build.rb` to generate the site
3. Deploy the generated output to the web host

The generator and its source live in `~/dev/williampickup-ssg` — deliberately separate from `~/Sites`, which holds generated output and local server config, never source or tooling. (Formerly under `~/Documents/Personal/Web-Development/` — moved out from under iCloud Drive's Desktop & Documents sync, which was racing the build's rapid delete-and-recreate of `_out/` and leaving behind empty duplicate `" 2"` directories.)


---

## Quick start

1. Run the **New Post** Nova task → enter a title → file opens ready to write, saved in `_drafts/`
2. Run the **Watch** Nova task → site rebuilds automatically on every save
3. Preview at `http://localhost:4567` (see [Previewing locally](#previewing-locally))
4. When done: run the **Publish Draft** Nova task → pick the file → it moves to `_posts/`, then commit and push — deploying happens automatically

---

## Directory structure

```
williampickup-ssg/
├── _posts/          Markdown files, one per published blog post
├── _drafts/         Markdown files, one per draft post (see "Drafts")
├── _notes/          Markdown files, one per short-form note
├── _journeys/       Markdown files, one per journey (undated photo essay — see "Journeys")
├── _photos/         Markdown files, one per gallery photo
├── _books/          Markdown files, one per book
├── _pages/          Markdown files for static pages (bio, blogroll, colophon, search)
├── _data/
│   ├── now.yml        Content for the /now page
│   ├── nav.yml        Header/footer navigation links
│   ├── blogroll.yml   Blogroll entries and filter categories
│   ├── series.yml     Series titles and descriptions (see "Series")
│   └── webmentions_sent.json   Webmention send state (committed; see "Webmentions")
├── _templates/      ERB page templates
├── _partials/       ERB partials (head, header, footer, post/note/journey cards, book entry)
├── _out/            Generated site (git-ignored, do not edit directly)
├── css/, javascript/, fonts/, assets/   Static assets, copied into output as-is
├── tools/           Authoring tools associated with the site (see "Authoring tools")
├── worker/          Cloudflare Worker feed proxy used by the blogroll (see worker/README.md)
├── .github/workflows/deploy.yml   CI build + deploy to GitHub Pages (see "Deploying")
├── .nova/           Nova editor tasks and their shell scripts (see "Nova tasks")
├── build.rb         Build script — run this to generate the site
├── deploy.sh        Local build + Pagefind index, for previewing before a push
├── send_webmentions.rb   Sends outbound webmentions — run by CI after each deploy
├── update_book_covers.rb Populates assets/books/ (see "Cover images" under "Books") — not run by build.rb
├── pagefind.yml     Pagefind search-index settings (see "Search")
├── taxonomy.rb      Writes taxonomy.md, a cheatsheet of categories/tags in use (see "Taxonomy cheatsheet")
├── extract.rb       One-time migration script (Tinderbox → Markdown) — retired, kept for reference
└── start-ruby-language-servers.sh   Starts ruby-lsp / rubocop / erb_lint language servers for the editor
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

**Required in practice:** `title`, `slug`, `date`. (The builder won't error without them — `slug` falls back to the filename, `title` to the slug, and a missing `date` sorts the post to the end — but the result looks broken.)
**Everything else is optional** — see the full [front matter reference](#front-matter-reference) below.

Run `ruby build.rb --drafts` to preview it at `drafts/your-slug.html` with a draft banner.

The **New Post** Nova task names the file `YYYY-MM-DD-your-slug.md` (date-prefixed, for sorting in the file list), but writes `slug: your-slug` without the date — the URL always comes from the `slug:` field, not the filename. The filename only matters when `slug:` is missing, in which case the filename (minus `.md`) is used.

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
series: nullarbor-road-trip  # Optional — groups this post with others sharing the slug; see "Series"
```

### Status

```yaml
featured: true    # Listed in the home page's "Start here" sidebar card (up to 6); hidden from the /blog.html listing
draft: true       # Rarely needed — see "Drafts" below
```

See [Drafts](#drafts) for how draft status actually works — it's primarily about which folder the file is in, not a front matter field.

---

## Drafts

Draft status is determined by **location**, not a front matter flag:

- **`_drafts/`** — always a draft, regardless of front matter. This is where new posts should live while you're writing them. Excluded from `ruby build.rb` (production); included, with an amber "Draft" banner, when you pass `--drafts`. The GitHub Actions deploy workflow always builds without `--drafts`, so there's no separate exclusion step to rely on — drafts simply never get written to `_out/` in a production build.
- **`_posts/`** — always published, unless you manually add `draft: true` to its front matter (a rarely-needed override for pulling a published post back without physically moving the file).

To publish, move the file from `_drafts/` to `_posts/`:

- **Publish Draft** Nova task — pick the file from a list; uses `git mv` so history is preserved
- Manually: `git mv _drafts/your-slug.md _posts/your-slug.md`

Then run `ruby build.rb` and the post appears at `posts/your-slug.html`.

**Notes work differently — this is the one important exception.** Unlike posts, a note is *never* drafted by which folder it's in; `_notes/` is the only folder notes ever live in, drafted or not. Draft status for a note comes entirely from `draft: true` in its own front matter, set and later removed **in place** — there's no `_drafts/` → `_notes/` move, and no "Publish Draft" Nova task for notes (that task only scans `_drafts/` and only moves things into `_posts/`). A draft note still builds to `drafts/slug.html`, with the same amber banner and the same exclusion from production — `--drafts` behaves identically either way. Only the *mechanism* for marking a note as a draft differs from a post's.

The **New Note** Nova task creates files directly in `_notes/` with `draft: true` already set, for exactly this reason.

**Journeys and static pages** use the same in-place `draft: true` flag as notes. A draft journey builds to `drafts/slug.html` with the draft banner. A draft page (e.g. `_pages/colophon.md`, currently a draft) is skipped in production; with `--drafts` it builds at its normal `/slug.html` address, with no banner.

**Photos and books have no draft state** — every file in `_photos/` and `_books/` is always published.

**`--drafts` builds also leak drafts into a few listings** — they're meant for local preview only: draft posts appear in `/blog.html`, the home page, archives, topic/category/series pages and the feeds, draft notes in `/notes.html`, and draft journeys in `/journeys.html`. The sitemap and `llms.txt` always exclude draft posts, notes and journeys. CI never passes `--drafts`.

---

## Topics, categories, and tags

Three different classification systems, each doing a different job:

| | Purpose | Values | Archive page |
|---|---|---|---|
| **`topics`** | Drives card accent colour; the primary classification | Fixed set — see table below | `/topics/slug.html` |
| **`categories`** | Freeform label shown on the post | Any string | `/categories/Name.html` |
| **`tags`** | Freeform, finer-grained | Any string | None — tag links point at `/blog.html#tag`, which filters the listing client-side |

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

The keys and labels come from `TOPIC_LABELS` in `build.rb`; the colours from the `.cat--*` rules in `css/site.css`. An unknown topic key still builds (its label is humanised from the key and it gets a topic page), but gets no card colour. Run the **Taxonomy Cheatsheet** Nova task to see which categories and tags are already in use — see [Taxonomy cheatsheet](#taxonomy-cheatsheet).

---

## Series

A fourth, optional classification alongside topics/categories/tags — for a body of posts meant to be read **as a sequence**, like a multi-part trip write-up, rather than filtered as a set. The key difference from every other listing on the site: a series page orders its posts **oldest-first** (Part 1, 2, 3…), not newest-first — it reads as chapters, not a feed.

### Adding a post to a series

```yaml
series: nullarbor-road-trip
```

Just a slug in front matter — no need to register it anywhere first. Any post carrying the same `series:` slug is grouped together automatically at build time and gets a "Part of a series" badge in its header, linking to the series index.

### Series metadata

A slug with no entry in `_data/series.yml` still works — the series index page just falls back to a humanized version of the slug as its title, with no description. To give a series a proper title and framing copy, add it there:

```yaml
# _data/series.yml
nullarbor-road-trip:
  title: "Eight Weeks on the Nullarbor and Back"
  description: "Sydney to Perth and back — twelve weeks, roughly 8,500km, with a standard poodle."
```

### What gets generated

Each distinct `series:` slug in use produces one page at `/series/slug.html` (via `_templates/series.html.erb`), listing every post in that series oldest-first, plus a part count in the page header. Series pages are automatically included in `sitemap.xml`, alongside topic and category archive pages.

Drafts follow the same rule as everywhere else: a series made up entirely of `_drafts/` posts only appears when building with `--drafts`, and its post links resolve to `drafts/slug.html` accordingly — nothing series-specific to configure for that, it falls out of how `Post#url_path` already works.

### Pairing with `layout: photo-essay`

Series and layout are independent front-matter fields, but a multi-part trip or project write-up is often exactly the kind of content that also wants the two-column photo grid — see [Photo essay layout](#photo-essay-layout). Combine both:

```yaml
series: nullarbor-road-trip
layout: photo-essay
```

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

Fenced code blocks with a language tag get syntax highlighting via [Prism](https://prismjs.com), themed to match light/dark mode:

````markdown
```ruby
def hello
  puts "hi"
end
```
````

Both ```` ``` ```` (GitHub-style) and `~~~` (Kramdown-style) fences work, with or without a language. The language becomes a `language-ruby` class on the `<code>` element. Code is set aside before the `==highlight==`/`~~strikethrough~~` handling runs, so `==` and `~~` inside a code block or an inline `` `code span` `` are left alone. Indented (four-space) code blocks also work but can't carry a language.

Prism's stylesheet and scripts (from cdnjs, via `_partials/_prism.html.erb`) are only added to posts and journeys whose body contains a language-tagged block, so other pages don't load them. Prism's autoloader fetches each language's grammar on demand, so any language Prism supports works without extra setup.

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

**Post-only, not available in notes:** figure size modifiers, photo pairs, Prism syntax highlighting (fenced code blocks still render in notes, just uncoloured), the [editorial grid](#editorial-grid-layout) (notes have no `layout` field at all), and sidenotes (the CSS isn't strictly blocked, but the numbering counter never initializes for a note, so a hand-written sidenote would render with broken numbering).

Quotebacks and pull quotes render identically whether a note is viewed on its own permalink page or inline on the `/notes.html` listing — both surfaces show a note's full body, so both get the same styling.

### Promoting a note to a post

If a note grows into something that deserves a full post treatment, use the **Promote Note** Nova task — pick the note from a list; it `git mv`s the file into `_posts/` (preserving history) and scaffolds in blank `description:`/`topics:`/`categories:`/`tags:` lines for whichever the note doesn't already have.

A raw move alone would work without erroring — `Post` defaults every field beyond `title`/`slug`/`date` gracefully — but the result would be a thin post: no topic colour on its card, no card description, and (if the note was untitled) a title that's just the raw slug. The scaffolded fields are there to prompt filling those in.

Two things worth knowing before promoting:

- **The URL changes** — `/notes/slug.html` becomes `/posts/slug.html`. Nothing auto-redirects the old address, so a promotion breaks any existing link to the note.
- **Nothing in the note's content needs to change.** Every formatting option that works in a note also works in a post (see [Formatting available in notes](#formatting-available-in-notes) above) — promotion only adds capability, it never removes any.

---

## Journeys

A journey is a standalone, **undated** photo essay for a place or trip, in `_journeys/`. It's deliberately *not* a post: it has no `date`, topics, categories, tags or series, and never appears in `/blog.html`, the archives or the RSS/Atom feeds. It's meant as a living page you keep adding to across trips, not a one-off dispatch. Journeys are listed at `/journeys.html` and each one is built at `/journeys/slug.html`.

```yaml
title: "Melbourne to the coast"
slug: melbourne-to-the-coast
description: "One sentence for meta tags, the sitemap and llms.txt."
lede: "Intro shown under the title and on the /journeys.html card."
updated: 2026-07-22          # Shown as "Last updated July 2026"; also the sitemap lastmod
image_url: https://media.publit.io/file/hero.jpg
image_focal_point: "50% 40%"
use_featured_image: true     # Hero image at the top of the page
layout: photo-essay          # Default for journeys (posts default to standard)
draft: true                  # In-place draft flag, like notes — remove it to publish
```

The body uses the same markup as posts — see [Body markup](#body-markup) and [Photo essay layout](#photo-essay-layout). The card on `/journeys.html` shows the `lede` (or `description` if there's no lede). A `featured` field is read but not used by any template yet.

`_journeys/melbourne-to-the-coast.md` is currently a draft sample that uses placeholder images from picsum.photos.

There's no Nova task for creating journeys yet — copy an existing file in `_journeys/` as a starting point. The **Watch** task rebuilds when a journey changes.

---

## Photos

Each photo is a file in `_photos/`:

```yaml
title: "Photo Title"
slug: photo-slug
date: 2026-06-01
image_url: https://media.publit.io/file/photo.jpg
image_alt: "Description of the image"
image_size: wide       # wide, full, or portrait (default: standard) — applied on gallery/highlights.html
focal_point: "50% 40%"
location: "Sydney, Australia"
camera: "Fujifilm X100V"
caption: "Optional caption text."
series: highlights     # use "highlights" to include in gallery/highlights.html
featured: false        # the first featured photo becomes the home page hero image
tags: [travel, coast]
```

Each photo gets its own page at `/photos/slug.html`. All photos appear on `/gallery.html`. Unlike posts, photos have no draft state. A photo's `series` has nothing to do with post [series](#series); the only value the builder uses is `highlights`.

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
cover_url:              # optional — see "Cover images" below
on_now_page: true      # shows in the Reading section of the /now page
```

Each book gets its own page at `/reading/slug.html`, with the Markdown body as its notes. `status` defaults to `read` if omitted. Books with `status: reading` appear under "Currently Reading" on `/reading.html`; books with `status: read` appear under "Read", newest `date_read` first.

`on_now_page: true` puts a book in the Reading section of `/now.html` and in the home page's Now card, **whatever its `status`**. The builder doesn't check whether you're still reading it, so remove the flag when you finish the book.

### Cover images

Covers are always self-hosted from `assets/books/<slug>.jpg` — the site never hotlinks a third-party CDN for them (OpenLibrary's cover service in particular is unreliable; hotlinking it was the original cause of covers silently not displaying). `Book#cover_src` in `build.rb` returns `nil`, and the partial renders no `<img>` at all, until that local file exists.

To add or replace a cover, run `ruby update_book_covers.rb` after either:

- **Dropping a photo in yourself** — save/AirDrop a photo of the book straight into `assets/books/<slug>.jpeg` (any common extension, any size — a phone photo is fine). The script auto-orients it, resizes it down to a max of 360px (covers only ever display at ≤180px), converts it to `<slug>.jpg`, and removes the raw original.
  To replace an existing `<slug>.jpg` with a new photo, drop the new one in under a *different* extension (e.g. `.jpeg`, `.png` or `.heic`) so it doesn't overwrite the old file.
- **Leaving it to fetch automatically** — if no local file exists, the script falls back to `cover_url` (a specific image URL) or, failing that, OpenLibrary's cover-by-ISBN lookup, then normalises whatever it downloads the same way.

Requires ImageMagick 7 (the `magick` command — `brew install imagemagick`). The script is safe to re-run any time — an already-normalised cover is skipped (delete it to force a re-fetch), and a fresh photo dropped in for an existing book is picked up and reprocessed. OpenLibrary's tiny "no cover" placeholder image is detected and ignored. It's not part of the regular `build.rb` — the build never touches the network, so a flaky or unreachable image host can't break a deploy.

---

## Static pages

`_pages/*.md` (bio, blogroll, colophon, search) use the same Markdown + front matter format. The `template:` key selects which ERB template to use:

```yaml
title: "About"
slug: bio           # Output: /bio.html (pages are written at the site root)
description: "About William Pickup."
template: bio       # matches _templates/bio.html.erb
sidebar_blurb: "Maker, runner, reader, photographer, traveller."   # bio only — shown in the home page's About card
draft: true         # optional — see "Drafts"
```

`bio`, `blogroll`, `colophon`, and `search` each have a dedicated template. **Omit `template:`** for an ordinary text page: it then uses `_templates/page.html.erb`, which shows the title, the `description` as a lede, and the Markdown body (styled by `.page-prose`, shared with the colophon). A page that needs its own layout needs both a `_pages/*.md` file and a matching `_templates/*.html.erb` file — see [Builder behaviours and gotchas](#builder-behaviours-and-gotchas) for what every template needs to include. Pages don't appear in the navigation automatically; add a link in `_data/nav.yml` if you want one.

`colophon.md` is currently `draft: true` (an outline), so `/colophon.html` isn't built in production — and the footer build stamp only links to it once it is (see [Builder behaviours and gotchas](#builder-behaviours-and-gotchas)).

---

## The home page

`_templates/home.html.erb` assembles the home page from several sources. Nothing needs to be configured separately:

- **Masthead**: the site name and `SITE_DESC` from `build.rb`, plus two live status lines filled in by `main.js`. Each stays hidden unless it loads:
  - a **location ticker** showing coordinates, current temperature (from the free Open-Meteo API) and Sydney local time. The coordinates and timezone are hard-coded in `initLocationTicker` in `javascript/main.js`.
  - a **"Listening to"** line from ListenBrainz's playing-now API, for the user in `LISTENBRAINZ_USER` in `build.rb`, re-checked every 60 seconds. Set the constant to `''` to turn it off.
- **Hero image**: the first photo with `featured: true`, if there is one.
- **Recent writing**: the six newest posts, as cards.
- **Sidebar cards**, in order:
  - **About**, from `_pages/bio.md`'s `sidebar_blurb` and `assets/WP-at-Stromlo.webp`
  - **Now**, with `making` and `travelling` from `now.yml` and books marked `on_now_page`
  - **Start here**, listing posts with `featured: true` (up to six)
  - **Visual work**, with fixed links to the gallery
  - **Blogroll**, listing entries with `sidebar: true` in `blogroll.yml`
  - **Notes**, showing the four newest notes with an 80-character excerpt

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

`making` and `travelling` also appear in the home page's Now sidebar card; `growing` and `thinking_about` are shown on `/now.html` only. Books with `on_now_page: true` appear automatically in the Reading section (whatever their `status` — see [Books](#books)). Any section may be omitted; templates check before rendering.

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
    sidebar: true      # optional — also list this entry in the home page's Blogroll card
```

`filters` lists every category used for the page's filter buttons — a category on an entry that isn't in `filters` won't get a working filter button. `desc` and `sidebar` are optional.

`feed` is the site's RSS/Atom URL. `javascript/blogroll.js` uses it to show each blog's most recent post. Most feeds don't send CORS headers, so the browser fetches them through a small Cloudflare Worker, `wp-feed-proxy.williampickup.workers.dev`, whose source is in `worker/`. The Worker returns just the latest entry as JSON and caches it for two hours. It's deployed separately with `wrangler` (see `worker/README.md`), not by the site's deploy workflow. The page also loads its own stylesheet, `css/blogroll.css`.

The `/blogroll.html` page is rendered from `blogroll.yml`, not from the body of `_pages/blogroll.md`. That file still contains an older hand-written Markdown list of links, which isn't shown.

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
cd ~/dev/williampickup-ssg
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

`build.rb` does not build the Pagefind search index — the CSS theming for the search UI (`#search`, `.pagefind-ui__*` in `site.css`, and `_templates/search.html.erb`) is wired up, but indexing is a separate step, run from the project root (so Pagefind picks up `pagefind.yml`):

```bash
npx --yes pagefind --site _out
```

`deploy.sh` already runs this for you — manual indexing is only needed if you build without it.

---

## Previewing locally

```bash
python3 -m http.server 4567 --directory ~/Sites/williampickup.org/_site
```

Then open `http://localhost:4567` in your browser. The Nova tasks write to `~/Sites/williampickup.org/_site` by default (set in `.nova/Scripts/config.sh`).

`.claude/launch.json` defines an `ssg-preview` server on the same port 4567, but it serves `~/dev/williampickup-ssg/_out`, the default output of a plain `ruby build.rb` or `./deploy.sh`, not the Nova folder. Serve whichever folder your last build actually wrote to.

---

## Deploying

The site is hosted on **GitHub Pages** (`wpickup/williampickup-ssg`, public
repo) — there's no server to SSH into or rsync a build to anymore. As of
2026-08-17, `williampickup.org`'s DNS points directly at GitHub Pages; the
old Vultr box's `httpd`/`relayd` blocks for this domain are still on disk
there but no longer receive any traffic. (This site used to deploy via
rsync/SSH to that box — see `exit-vultr-plan.html` in the separate
`server-config` repo, `~/Documents/Personal/Web-Development/server-config`,
for the full migration history if that context is ever needed.)

`deploy.sh` only builds locally, as a sanity check before pushing — actual
deployment always happens in CI:

```bash
cd ~/dev/williampickup-ssg
./deploy.sh          # build + Pagefind index, local only
./deploy.sh --drafts # same, including drafts
```

### Deploying via GitHub Actions

`.github/workflows/deploy.yml` builds, indexes, publishes to Pages, and
sends webmentions. It runs automatically on every push to `main` — commit
and push, and the live site updates on its own within a minute or so, no
separate deploy step needed:

```bash
git push
```

`workflow_dispatch` is also still enabled, for the rare case of wanting a
rebuild without a new commit (picking up an external change like a
refreshed book cover image, say):

```bash
gh workflow run deploy.yml
```

There's no Nova task for this anymore — it's what plain `git push` does by
default now, so a dedicated button didn't add anything. For the
`workflow_dispatch` case above, just run the `gh` command directly.
(`.nova/Publishing/Vultr.json`, Nova's old remote-publishing config for the
Vultr box, is still in the repo but is no longer part of the deploy.)

In CI the site is built with `bundle exec ruby build.rb` on Ruby 3.3, then
indexed with `npx --yes pagefind --site _out`. A `CNAME` file for
`williampickup.org` is written into `_out/` on every run, so the custom
domain doesn't depend on a file in the repo.

Publishing itself uses `actions/upload-pages-artifact` +
`actions/deploy-pages`, authenticated via the workflow's own
`id-token: write` permission (GitHub's OIDC token) — **no SSH key or deploy
secrets are needed for this at all.** The only repository secret still
required is:

| Secret | Value |
|---|---|
| `WEBMENTION_TOKEN` | Your Telegraph token — see [Webmentions](#webmentions) |

Add it under **Settings → Secrets and variables → Actions**. The workflow
also needs `contents: write` permission to commit the webmention state file
back to the repo — already set in `deploy.yml`, nothing extra to configure.
Its automated commit includes `[skip ci]` so it doesn't re-trigger the
push-based deploy on itself.

Triggering a manual rebuild from an iPad or other device without a terminal: use GitHub's REST API directly (`POST` to `.../actions/workflows/deploy.yml/dispatches` with a scoped personal access token), wrapped in an iOS Shortcut for a one-tap trigger.

---

## Webmentions

### Receiving

Every page's `<head>` advertises [webmention.io](https://webmention.io) as its webmention (and pingback) endpoint. On post pages, `main.js` fetches that post's mentions from the webmention.io API and shows replies, likes/reposts and other mentions in the `#webmentions` section below the post, with a simple filter for obvious spam. The section stays hidden when there are none.

### Sending

After a successful deploy, the GitHub Actions workflow runs `send_webmentions.rb`, which scans every published post's outbound links and sends a webmention for any that haven't been sent before, via [Telegraph](https://telegraph.p3k.io) — a third-party service that handles endpoint discovery, so the protocol doesn't need implementing directly. Links to the site itself and to `media.publit.io` are skipped. `deploy.sh` and the Nova tasks don't send webmentions; CI is the only place this runs automatically.

**One-time setup:** sign in at telegraph.p3k.io with your domain to get a token, and add it as the `WEBMENTION_TOKEN` repository secret for GitHub Actions. To run the script by hand locally:

```bash
WEBMENTION_TOKEN=your-token-here bundle exec ruby send_webmentions.rb
```

`.nova/Scripts/config.sh` also loads the token from a gitignored `.webmention-token` file into Nova task environments, a holdover from when Nova tasks deployed the site. No current Nova task uses it.

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
- `_out/sitemap.xml` — every post, note, photo, book, journey, static page, index page (including `gallery/highlights.html` and `journeys.html`), and archive-year/topic/category/series page. Draft posts, notes and journeys are always excluded, even when building with `--drafts`
- `_out/robots.txt` — disallows `/drafts/` and points crawlers at the sitemap. Also lists common AI crawlers (GPTBot, ClaudeBot, Google-Extended, PerplexityBot, etc.) by name with an explicit `Allow: /`, so the stance on AI crawling is a deliberate, visible one rather than just whatever the wildcard rule happens to imply. Flip any single bot to `Disallow: /` in `build.rb` if you change your mind about it specifically.
- `_out/llms.txt` — a curated Markdown index for LLMs/agents, per [llmstxt.org](https://llmstxt.org): site description, the 20 most recent posts, topic links, published journeys (if any), and links to the other index surfaces (blog, notes, gallery, reading, journeys, about, sitemap, feed). Distinct from `sitemap.xml`, which is exhaustive; this is meant to be a smaller, high-signal summary.
- `_out/.well-known/security.txt` — [RFC 9116](https://www.rfc-editor.org/rfc/rfc9116). Contact + a rolling one-year `Expires` date computed at build time, so it never goes stale on its own.
- `_out/404.html` — the not-found page, which GitHub Pages serves automatically.
- `_out/manifest.json` — a minimal web app manifest (name, description, theme colours, icons) linked from every page's `<head>` via `<link rel="manifest">`. Uses `display: minimal-ui`. Icons: `favicon.svg` and `apple-touch-icon.png` for `purpose: any`, plus `assets/icon-maskable-512.png` (generated from the enneagram mark in `favicon.svg`, on the light-theme background colour, artwork scaled to ~66% of the canvas diameter to sit safely inside every platform's mask shape) for `purpose: maskable`.

---

## Search

Client-side search via [Pagefind](https://pagefind.app), on `/search.html`. The index is built separately from the main site build — see [Search index (Pagefind)](#search-index-pagefind) above. Without an index (e.g. after a plain `ruby build.rb`), the search page loads but finds nothing.

Indexing options live in `pagefind.yml` in the project root, which Pagefind reads automatically from its working directory. CI, `deploy.sh` and the **Build and Index** Nova task all run from the root, so they all produce the same index. It currently excludes site chrome (`nav`, `footer`, `.site-header`, `.skip-link`, `.breadcrumb`) so navigation words don't match every page. Change indexing behaviour there, not with command-line flags.

---

## Templates and CSS

- **Templates** live in `_templates/` as `.html.erb` files, one per page type (or per generated group, like `topic.html.erb` for every topic archive page)
- **Partials** (head, header, footer, post card, note card, journey card, book entry) live in `_partials/`
- **CSS** is at `css/site.css` in this repo — edit here, rebuild to see changes. The blogroll page also loads `css/blogroll.css`, via the head partial's `extra_css` option.
- **JavaScript**: `javascript/main.js` handles the theme toggle, mobile nav, scroll-reveal, quotebacks, blog filtering, webmentions and the home page status lines. `javascript/blogroll.js` handles blogroll filtering and latest-post lookups.
- **Structured data**: the home page embeds `WebSite`/`Person` JSON-LD. Topic, category, series, journey, photo and gallery-highlights pages emit `BreadcrumbList` JSON-LD through `renderer.breadcrumb_ld([[name, url], …])`; pass `nil` as the URL for the current page.

After editing a template or CSS file, just run `ruby build.rb` again.

---

## Authoring tools

`tools/Publit Upload.app` — a droplet app for uploading images to publit.io; drag an image onto it, get back a URL to paste into a post's `image_url` front matter. Lives in the repo (not just on the Desktop) since it's specific to this site's authoring workflow — a Finder alias on the Desktop points into `tools/` for convenient access.

### Nova tasks

Each task in `.nova/Tasks/` runs a script in `.nova/Scripts/`. Every script first sources `config.sh`, which sets `SSG_OUT_DIR` (default `~/Sites/williampickup.org/_site`) and loads `.webmention-token` if it exists.

| Task | Script | What it does |
|---|---|---|
| **Authoring Guide** | `authoring-guide.sh` | Opens this file in Nova |
| **Build** | `build.sh` | `ruby build.rb` |
| **Build with Drafts** | `build-drafts.sh` | `ruby build.rb --drafts` |
| **Build and Index** | `pagefind.sh` | Production build, then a Pagefind index (settings from `pagefind.yml`) |
| **Watch** | `watch.sh` | Builds with `--drafts`, then rebuilds on every change. Needs `fswatch` (`brew install fswatch`) |
| **New Post** | `new-post.sh` | Asks for a title and writes `_drafts/YYYY-MM-DD-slug.md` with a full front matter scaffold |
| **New Note** | `new-note.sh` | Asks for an optional title and writes `_notes/YYYY-MM-DD-slug.md` (or `…-untitled.md`) with `draft: true` |
| **Publish Draft** | `publish-draft.sh` | Choose a file in `_drafts/` and move it to `_posts/` (with `git mv` if it's tracked) |
| **Promote Note** | `promote-note.sh` | Moves a note to `_posts/` and adds blank post fields — see [Promoting a note to a post](#promoting-a-note-to-a-post) |
| **Taxonomy Cheatsheet** | `taxonomy-cheatsheet.sh` | Runs `taxonomy.rb` and opens `taxonomy.md` |

**Watch** watches every build input: all the content folders (`_posts`, `_drafts`, `_notes`, `_journeys`, `_pages`, `_photos`, `_books`), `_data`, `_templates`, `_partials`, `build.rb`, and the static folders `css`, `javascript`, `fonts` and `assets`. If you add a new content or static folder to `build.rb`, add it to `watch.sh` too.

The note slug written by **New Note** includes the date (`slug: 2026-06-29-title`), so the note's URL does too. The post slug written by **New Post** doesn't.

### Taxonomy cheatsheet

`ruby taxonomy.rb` (or the **Taxonomy Cheatsheet** Nova task) writes `taxonomy.md`, which is gitignored and regenerated each time. It lists:

- the six topics, from `TOPIC_LABELS` in `build.rb` (the script loads `build.rb` as a library, so it always matches)
- every category and tag in use across `_posts/` and `_drafts/`, with counts
- warnings for values that differ only in case, e.g. "Photography" vs "photography"

Check it before inventing a new category or tag.

---

## Builder behaviours and gotchas

**Reading time** — calculated automatically from word count (~200 wpm), minimum 1 min. Shown on blog cards and in the post header.

**Slugs** — must be unique across all posts. Used as the filename and URL — changing a slug after publishing breaks links.

**Dates** — ISO 8601 format (`2026-06-18`). Posts sorted newest-first throughout the site. Archive pages group by year automatically.

**Build footer stamp** — every page footer shows a UTC build timestamp and short git commit SHA (`built 21 Jun '26, 03:53 UTC  e39d8bf`), generated in `build.rb` from `git rev-parse --short HEAD`. It's useful for confirming that a deploy reflects what was pushed. The "built …" text links to `colophon.html` only when the colophon page is part of the build (`renderer.page_built?('colophon')`); while the colophon is a draft it's plain text in production, so it never links to a 404. The SHA links to that commit on GitHub (`REPO_URL` in `build.rb`). In a local build of a commit you haven't pushed yet, that link will 404 until you push; published builds always come from CI, so their commit is always on GitHub.

**Adding a new template** — `_partials/_head.html.erb` is just the contents of `<head>`: `<meta>` and `<link>` tags only, no `<html>` wrapper. Every template is responsible for writing `<!DOCTYPE html><html lang="en"><head>` itself, rendering the `head` partial inside it, then closing `</head>` before `<body>`. Consistent across every existing template (copy the pattern from any file in `_templates/`), but manual — forgetting to close `</head>` before `<body>` in a new template is a silent bug, not something the builder catches.

**Ruby dependency** — `build.rb` requires the `kramdown` gem (the Gemfile's only dependency); run via `bundle exec ruby build.rb` (or ensure `bundle install` has been run) rather than bare `ruby build.rb` if gems aren't already on the system path. `Gemfile`/`Gemfile.lock` pin the version used in CI. `.ruby-version` pins Ruby 4.0.6 for local use; CI runs Ruby 3.3 (set in `deploy.yml`). The code runs on both, but keep that gap in mind if you use newer Ruby syntax.

**Small caps for acronyms** — `md_to_html` wraps runs of two or more capital letters (e.g. `NASA`, `ROUGH TYPE`) in `<span class="acr">` so they display as small caps. Text inside `<pre>`/`<code>` and inside tag attributes is left alone. This applies everywhere Markdown is rendered, including notes, journeys, pages and book notes.

**Smart quotes** — Kramdown converts straight quotes to curly quotes in all Markdown bodies.

**Missing `date` on a post** — it doesn't error, but the post sorts to the end of every list and has no archive year.
