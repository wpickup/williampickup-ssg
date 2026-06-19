# williampickup.org — Site User Guide

## Overview

The site is built with a plain Ruby static site generator. The workflow is:

1. Edit source files (`_posts/`, `_pages/`, `_data/`, templates, CSS)
2. Run `ruby build.rb` to generate the site into `_out/`
3. Deploy `_out/` to your web host

---

## Directory structure

```
williampickup-ssg/
├── _posts/          Markdown files, one per blog post
├── _photos/         Markdown files, one per photo
├── _books/          Markdown files, one per book
├── _pages/          Markdown files for static pages (bio, blogroll)
├── _data/
│   └── now.yml      Content for the /now page
├── _templates/      ERB page templates
├── _partials/       ERB partials (head, header, footer, cards)
├── _out/            Generated site (git-ignored, do not edit directly)
├── extract.rb       One-time migration script (Tinderbox → Markdown)
└── build.rb         Build script — run this to publish
```

CSS, JavaScript, fonts, and images are pulled from `~/Sites/williampickup.org/` at build time. Edit those files there; `build.rb` copies them into `_out/` on every build.

---

## Daily workflow

### Writing a new post

Create a file in `_posts/` named `your-slug.md`:

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
image_url: https://res.publit.io/file/your-account/image.jpg
image_focal_point: "50% 30%"
use_featured_image: true
draft: false
---

Your post content in Markdown here.
```

**Required:** `title`, `slug`, `date`, `draft: false`  
**Optional:** everything else

Run `ruby build.rb` and the post appears at `posts/your-slug.html`.

### Drafts

Set `draft: true` in the front matter. The post is skipped during build.

### Categories and topics

**Categories** are freeform labels shown on posts. Existing ones: Books, Food, Craft, Culture, Travel, Philosophy, Technology, Design, Music, Nature, Health, Work, Spirit.

**Topics** map to the topic index pages. Valid values:
- `books-ideas`
- `learning-making`
- `places-experiences`
- `simple-living`
- `health-wellbeing`

---

## Images

Images are hosted on publit.io. The build script generates responsive `srcset` attributes automatically by inserting `/w_{n}/` into the URL path.

**Image URL format:**
```
https://res.publit.io/file/your-account/w_700/image.jpg
                                        ↑ this part is replaced automatically
```

**Focal point** controls which part of the image stays visible when cropped. Format: `"X% Y%"` — e.g. `"50% 20%"` keeps the top-centre in frame.

---

## Books

Each book is a file in `_books/`:

```markdown
---
title: "Book Title"
slug: book-slug
author: "Author Name"
status: reading        # or: read
date_read: 2026-05-01  # leave blank if still reading
isbn: "9780571337118"
cover_url:             # leave blank — Open Library cover is used automatically via ISBN
on_now_page: true      # shows in the Reading section of the /now page
---
```

Books with `status: reading` appear under "Currently Reading" on the `/reading` page and `/now` page (if `on_now_page: true`). Books with `status: read` appear under "Read".

---

## Photos

Each photo is a file in `_photos/`:

```markdown
---
title: "Photo Title"
slug: photo-slug
date: 2026-06-01
image_url: https://res.publit.io/file/your-account/photo.jpg
image_alt: "Description of the image"
image_size: wide       # wide, full, or portrait
focal_point: "50% 40%"
location: "Sydney, Australia"
camera: "Fujifilm X100V"
caption: "Optional caption text."
series: highlights     # use "highlights" to include in gallery/highlights.html
featured: false
tags: [travel, coast]
---
```

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

Books with `on_now_page: true` and `status: reading` appear automatically in the Reading section.

---

## Static pages

`_pages/bio.md` and `_pages/blogroll.md` use the same Markdown + front matter format. The `template:` key selects which ERB template to use:

```markdown
---
title: "About"
slug: bio
description: "About William Pickup."
template: bio
---

Your bio content here.
```

---

## Building the site

```bash
cd ~/Sites/williampickup-ssg
ruby build.rb
```

Output goes to `_out/`. The script prints every file it generates and a summary at the end.

### Search index (Pagefind)

`build.rb` does not build the Pagefind search index — the CSS theming for the search UI (`#search`, `.pagefind-ui__*` in `site.css`) is wired up, but indexing is a separate step. After running `ruby build.rb`, generate the index over the output directory:

```bash
npx pagefind --site _out
```

Run this after every build that should be searchable, or add it as a second line in your deploy script.

### Previewing locally

```bash
python3 -m http.server 4567 --directory ~/Sites/williampickup-ssg/_out
```

Then open `http://localhost:4567` in your browser.

---

## Deploying

Copy the contents of `_out/` to your web host. For example with rsync:

```bash
rsync -avz --delete ~/Sites/williampickup-ssg/_out/ user@host:/path/to/webroot/
```

---

## Feeds

RSS and Atom feeds are generated automatically at:
- `_out/Feeds/rss.xml`
- `_out/Feeds/atom.xml`

Both include the 20 most recent posts.

---

## Post layouts

The `layout:` front matter key selects a page treatment. Omit it for the default single-column post style.

### `layout: editorial`

A twelve-column grid that activates on screens 1000px and wider. Text sits in a comfortable central column (columns 3–9). Images and text blocks can be promoted to wider column spans using CSS classes on the element.

**How to use it:**

Add `layout: editorial` to the post front matter, then use HTML figure and div elements directly in the Markdown body.

#### Figure classes

```markdown
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

#### Text block classes

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
| `col--margin-right` | Right gutter (cols 10–12) | Asides, references, footnotes |
| `col--margin-left` | Left gutter (cols 1–2) | Asides, references, footnotes |
| `pullquote` | Wide centred (cols 2–11) | Stand-out quotes |

`col--left` and `col--right` use the same 7-column width as the default text column, just repositioned. Placing a `col--left` paragraph followed by a `col--right` paragraph puts two text blocks side by side on the same row — useful for a zig-zag or two-voice layout.

#### How margin notes share a row with adjacent content

Margin notes work by claiming their gutter column before auto-placement reaches the adjacent text. The key is that Grid fills left-to-right across each row.

**`col--margin-right` (cols 10–12)** — place it **before** the element it should sit beside. Grid places the note at cols 10–12, then finds cols 3–9 still empty in that row and places the next element there:

```markdown
<div class="col--margin-right">Sennett, *The Craftsman* (2008).</div>

## The heading this note sits beside
```

**`col--margin-left` (cols 1–2)** — place it **after** the element it should sit beside. Grid places the heading at cols 3–9 first, then finds cols 1–2 still empty in that row and places the note there:

```markdown
## The heading this note sits beside

<div class="col--margin-left">A left-gutter note.</div>
```

The same logic applies to any combination — the element that occupies the earlier columns in the row must appear first in the source.

---

## Templates and CSS

- **Templates** live in `_templates/` as `.html.erb` files
- **Partials** (head, header, footer, post card, book entry) live in `_partials/`
- **CSS** is at `~/Sites/williampickup.org/css/site.css` — edit there, rebuild to see changes

After editing a template or CSS file, just run `ruby build.rb` again.
