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

## Templates and CSS

- **Templates** live in `_templates/` as `.html.erb` files
- **Partials** (head, header, footer, post card, book entry) live in `_partials/`
- **CSS** is at `~/Sites/williampickup.org/css/site.css` — edit there, rebuild to see changes

After editing a template or CSS file, just run `ruby build.rb` again.
