# Authoring Guide — williampickup.org SSG

A reference for writing posts and pages: front matter fields, layout options,
CSS patterns, and inline markup.

---

## Quick start

1. Run the **New Post** Nova task → enter a title → file opens ready to write
2. Run the **Watch** Nova task → site rebuilds automatically on every save
3. Preview at `http://localhost:4567` (run `python3 -m http.server 4567 --directory _out`)
4. When done: remove `draft: true` (or set to `false`) and run **Deploy**

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
  - books-ideas             # First topic drives the card colour (see Topics below)
```

### Images

```yaml
image_url: https://media.publit.io/file/your-image.jpg
image_focal_point: 50% 30% # CSS object-position, controls crop on card thumbnails
use_featured_image: true    # Show image as hero at top of post page (default: false)
```

`image_url` without `use_featured_image` still shows a thumbnail on the blog card.

### Layout and style

```yaml
layout: standard            # standard · editorial · feature · dispatch · photo-essay
                            # (omit for standard — it is the default)
accent: dark                # Optional colour override (see Accent below)
has_sidenotes: true         # Required if post contains sidenote markup
```

### Classification

```yaml
categories:
  - Books
topics:
  - books-ideas             # See Topics section — drives card colour
tags:
  - photography
```

### Status

```yaml
draft: true       # Goes to _out/drafts/, shows banner, excluded from deploy
featured: true    # Appears in "Start here" on home page; hidden from blog listing
```

---

## Topics and card colours

The first item in `topics:` sets the accent colour on blog cards and the post header.

| Topic key             | Label                   | Colour      |
|-----------------------|-------------------------|-------------|
| `books-ideas`         | Books and Ideas         | Slate blue  |
| `learning-making`     | Learning and Making     | Clay        |
| `simple-living`       | Simple Living           | Sage green  |
| `places-experiences`  | Places and Experiences  | Ochre       |
| `systems-thinking`    | Systems Thinking        | Violet      |
| `health-wellbeing`    | Health and Wellbeing    | Dusty rose  |

A post can belong to more than one topic — list all that apply, first one wins for colour.

---

## Layout variants

Set with `layout:` in front matter. Default is `standard` (omit the field).

### `standard`
Prose with a drop-cap on the first paragraph. Optional hero image above the body.
Good for most posts.

### `editorial`
Wider text column with a larger title and more prominent blockquotes (blockquotes become
pull quotes at wider viewports). Good for longer, more considered pieces.

### `feature`
Hero image fills the top of the page; title and date overlay it. Use when the image
is integral to the post — the reader arrives through the image.
Requires `image_url` and `use_featured_image: true`.

### `dispatch`
Narrower, newsletter-style column. Date is prominent. Good for short link-posts,
brief observations, or things written quickly.

### `photo-essay`
Body images run in a two-column grid on wide screens. Prose and images share equal
weight. Use `figure--half` or `figure--portrait` for the grid columns;
`figure--wide` and `figure--full` still break out of it.
See the Photo Essay section below.

---

## Body markup

Posts are written in Markdown (Kramdown). Standard Markdown applies throughout.
The additions below give you richer layouts within the body.

### Editorial markup

**Highlighted text** — wrap with `==` on each side:

```markdown
This is the ==key conclusion== of the argument.
```

Renders as `<mark>` with a translucent accent-colour background. Works inline within any paragraph, list item, or blockquote.

**Rhetorical strikethrough** — wrap with `~~` on each side:

```markdown
~~The old approach was fine.~~ ==The new one changes everything.==
```

Renders as faded `<del>` text. Most powerful when immediately followed by a `==highlighted==` replacement — the crossed-out thought and its correction sit side by side.

**Pull quote** — a single sentence given generous space:

```html
<p class="pullquote">The most important kind of freedom is to be what you really are.</p>
```

Centred, italic, display-sized Cormorant Garamond. Best used once per post, for the essay's core sentence.

**Part label** — a small section marker for essay-length posts:

```html
<p class="part-label">part one.</p>
```

Tiny, letter-spaced, lowercase. Pair it with an `## H2` heading immediately after:

```html
<p class="part-label">part one.</p>

## The argument
```

**Pilcrow** — a visual pause without a heading break, paste the character directly:

```
¶
```

No CSS needed. Just a Unicode character on its own line.

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

### Figures

Plain image with caption (standard width):

```html
<figure>
  <img src="https://media.publit.io/file/image.jpg" alt="Description">
  <figcaption>Caption text</figcaption>
</figure>
```

#### Figure size modifiers

| Class                | Effect                                          |
|----------------------|-------------------------------------------------|
| `figure--wide`       | Breaks outside the text column on wide screens  |
| `figure--full`       | Full viewport width                             |
| `figure--small`      | Max 132px wide                                  |
| `figure--half`       | Half-width (used in photo-essay grid)           |
| `figure--portrait`   | Portrait crop (used in photo-essay grid)        |
| `figure--float-left` | Floats left, text wraps (collapses on mobile)   |
| `figure--float-right`| Floats right, text wraps (collapses on mobile)  |
| `figure--video`      | Responsive iframe/video embed                   |

Combine modifiers: `class="figure--small figure--float-left"`

#### Video embed

```html
<figure class="figure--video">
  <iframe src="https://www.youtube.com/embed/VIDEO_ID"
    allowfullscreen loading="lazy"></iframe>
</figure>
```

### Photo pairs

Two images side by side (collapses to single column on mobile):

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

### Sidenotes

Requires `has_sidenotes: true` in front matter. Each sidenote needs a unique
checkbox `id` per post (`sn1`, `sn2`, etc.).

Numbered sidenote (shows a superscript counter inline):

```html
<span class="sidenote sidenote-numbered">
  <input type="checkbox" id="sn1" class="sidenote-checkbox">
  <label for="sn1" class="sidenote-toggle"></label>
  <span class="sidenote-content">The sidenote text goes here.</span>
</span>
```

On wide screens sidenotes float to the margin. On narrow screens they expand
inline on tap. Increment the `id` for each note: `sn1`, `sn2`, `sn3` …

---

## Photo essay layout

For `layout: photo-essay`, images in the body run in a two-column grid.
Use `figure--half` for standard portrait/landscape pairs, `figure--portrait`
for tall portrait crops:

```html
<figure class="figure--half">
  <img src="…" alt="…">
</figure>

<figure class="figure--portrait">
  <img src="…" alt="…">
</figure>
```

Odd-numbered figures go in the left column, even-numbered in the right.
`figure--wide` and `figure--full` break out of the grid entirely.
`photo-pair` creates a manual side-by-side within the grid if needed.

---

## Using publit.io images

The site uses [publit.io](https://publit.io) for image hosting. The build
generates responsive `srcset` automatically for any `image_url` pointing at
`media.publit.io/file/`.

In body content, use the direct publit URL — the browser picks the right
size via srcset when the image is a card or hero. For images inline in the
body, use the URL as-is in `<img src="…">`.

---

## Accent colour

The `accent:` field is available in front matter for future per-post colour
overrides. Currently reads into the Post model but is not yet wired to a CSS
class — leave it blank unless you are experimenting.

---

## Books front matter

```yaml
title: Book Title
slug: book-slug
author: Author Name
status: reading            # reading · read
date_read: 2026-05-10      # used when status is read
isbn: 9780000000000        # used to fetch cover from OpenLibrary if no cover_url
cover_url: https://…       # overrides ISBN cover lookup
on_now_page: true          # appears in the Now page and home page reading strip
```

---

## Pages front matter

```yaml
title: Page Title
slug: page-slug            # output: _out/page-slug.html
description: …
template: bio              # matches _templates/bio.html.erb
```

---

## Scroll animations

Elements in the following groups animate in with a fade-up on scroll — no markup needed, it's automatic:

- Home masthead name heading
- Home hero photo
- Now strip items
- Post cards on the blog listing
- Gallery items
- Now page sections
- Page hero headers

Siblings within the same container stagger by 70ms each so grouped items arrive in sequence rather than all at once. The animation is suppressed for users with `prefers-reduced-motion` enabled.

---

## Builder behaviours to know

**Drafts**
- `draft: true` → built to `_out/drafts/slug.html` with an amber "Draft" banner
- Excluded from the blog listing, feeds, and all index pages
- Excluded from rsync deploy — never reaches the live server
- Preview with the **Build with Drafts** Nova task

**Featured posts**
- `featured: true` → appears in the "Start here" section on the home page
- JS hides featured posts from the main blog listing (they have a dedicated slot)
- Only a small number of posts should be featured at any time

**Reading time**
- Calculated automatically from word count (~200 wpm), minimum 1 min
- Shown on blog cards and in the post header

**Feeds**
- RSS and Atom feeds are generated from the 20 most recent published posts
- Draft posts never appear in feeds

**Topics vs categories vs tags**
- `topics` → drives card colour and topic archive pages (`/topics/slug.html`)
- `categories` → drives category archive pages (`/categories/Name.html`)
- `tags` → available for filtering but no archive page generated currently

**Slugs**
- Must be unique across all posts
- Used as the filename and URL — changing a slug after publishing breaks links

**Dates**
- ISO 8601 format: `2026-06-18`
- Posts sorted newest-first throughout the site
- Archive pages group by year automatically
