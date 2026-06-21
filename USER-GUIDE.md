# williampickup.org — Site User Guide

## Overview

The site is built with a plain Ruby static site generator. The workflow is:

1. Edit source files (`_posts/`, `_pages/`, `_data/`, templates, CSS) — this repo lives in `~/Documents/Personal/Web-Development/williampickup-ssg`, separate from anything served locally
2. Run `ruby build.rb` to generate the site into `_out/` (or set `SSG_OUT_DIR` to write straight to a local preview folder — see "Previewing locally" below)
3. Deploy the generated output to your web host

---

## Directory structure

```
williampickup-ssg/
├── _posts/          Markdown files, one per published blog post
├── _drafts/         Markdown files, one per draft post (see "Drafts" below)
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

CSS, JavaScript, fonts, and images live inside this repo (`css/`, `javascript/`, `fonts/`, `assets/`) — edit them here, not anywhere under `~/Sites`. `build.rb` copies them into the output directory on every build.

---

## Daily workflow

### Writing a new post

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
image_url: https://res.publit.io/file/your-account/image.jpg
image_focal_point: "50% 30%"
use_featured_image: true
---

Your post content in Markdown here.
```

**Required:** `title`, `slug`, `date`  
**Optional:** everything else

Run `ruby build.rb --drafts` to preview it at `drafts/your-slug.html` with a draft banner.

### Drafts

Draft status is determined by which folder the file is in, not a front matter flag:

- **`_drafts/`** — always a draft, regardless of front matter. This is where new posts should live while you're writing them. Excluded from `ruby build.rb` (production); included, with a draft banner, when you pass `--drafts`.
- **`_posts/`** — always published, unless you manually add `draft: true` to its front matter (a rarely-needed override for pulling a published post back without moving the file).

To publish, move the file from `_drafts/` to `_posts/` — either with the **Publish Draft** Nova task (pick the file from a list; it uses `git mv` so history is preserved), or manually:

```bash
git mv _drafts/your-slug.md _posts/your-slug.md
```

Run `ruby build.rb` and the post appears at `posts/your-slug.html`.

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
cd ~/Documents/Personal/Web-Development/williampickup-ssg
ruby build.rb
```

Output goes to `_out/` inside the repo by default. The script prints every file it generates and a summary at the end.

### Writing output somewhere else (`SSG_OUT_DIR`)

The generator and its source live in `~/Documents/Personal/Web-Development/williampickup-ssg` — separate from anything actually served locally. To preview the site through a real local server instead of just generating files, set `SSG_OUT_DIR` to redirect the build there instead of `_out/`:

```bash
SSG_OUT_DIR=~/Sites/williampickup.org/_site ruby build.rb
```

CI (the GitHub Actions deploy workflow) never sets this — it always uses the default `_out/`, so this is purely a local convenience. `deploy.sh` and the Nova build tasks both respect it the same way `build.rb` does.

Note: `build.rb` deletes and recreates whatever `OUT_DIR` resolves to on every build. Point it at a dedicated subfolder (like `_site` above), not a folder that holds anything else you care about (e.g. don't point it directly at `~/Sites/williampickup.org` itself if that folder also holds a `.claude/` config or similar — it'll get wiped on the next build).

### Search index (Pagefind)

`build.rb` does not build the Pagefind search index — the CSS theming for the search UI (`#search`, `.pagefind-ui__*` in `site.css`) is wired up, but indexing is a separate step. After running `ruby build.rb`, generate the index over the output directory:

```bash
npx pagefind --site _out
```

`deploy.sh` (see "Deploying" below) already runs this for you — manual indexing is only needed if you build without it.

### Previewing locally

```bash
python3 -m http.server 4567 --directory ~/Sites/williampickup.org/_site
```

Then open `http://localhost:4567` in your browser. (The Nova tasks and `.claude/launch.json` in this project already point at this folder via `SSG_OUT_DIR` — see above.)

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

`williampickup` here is the SSH config alias for the Vultr server (see `~/.ssh/config`) — it already carries the right user and deploy key, so you don't need to spell those out. Pass `--drafts` as an extra argument if you want drafts included in the build (they're excluded from the rsync regardless, via `--exclude 'drafts/'`).

Since typing `DEPLOY_DEST=...` every time is easy to forget, consider exporting it once per shell session:

```bash
export DEPLOY_DEST=williampickup:/var/www/htdocs/williampickup.org/
./deploy.sh   # now deploys every time, no env var needed
```

After a real deploy (`DEPLOY_DEST` set), `deploy.sh` also sends webmentions for any new outbound links and commits the updated state file — see "Sending webmentions" below.

### Deploying via GitHub Actions

`.github/workflows/deploy.yml` runs the same build → index → rsync → webmention sequence, triggered manually — either via the Actions tab's "Run workflow" button, or from the terminal:

```bash
gh workflow run deploy.yml
```

It deliberately does not run on every push to `main`, so commits and merges never trigger a production deploy on their own — you decide when to ship by running the workflow explicitly. It needs five repository secrets set under **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `DEPLOY_SSH_KEY` | Private key for a dedicated deploy keypair (not your personal key — generate one scoped just to this, e.g. `ssh-keygen -t ed25519 -f deploy_key -C "github-actions"`, and add its public half to the server's `authorized_keys`) |
| `DEPLOY_HOST` | The server's IP or hostname |
| `DEPLOY_USER` | The SSH user on the server |
| `DEPLOY_PATH` | The webroot path, e.g. `/var/www/htdocs/williampickup.org/` |
| `WEBMENTION_TOKEN` | Your Telegraph token — see "Sending webmentions" below |

I can't create or view these secrets myself — add them directly in the GitHub UI, never by pasting key material into chat or a file in the repo.

The workflow also needs permission to commit back to the repo (for the webmention state file) — this is set via `permissions: contents: write` already in `deploy.yml`, nothing extra to configure.

### Sending webmentions

After a successful deploy, `send_webmentions.rb` scans every published post's outbound links and sends a webmention for any that haven't been sent before, via [Telegraph](https://telegraph.p3k.io) — a third-party service that handles endpoint discovery for you, so we don't need to implement the protocol ourselves.

**One-time setup:** sign in at telegraph.p3k.io with your domain to get a token, then make it available in each environment that deploys:

```bash
# Local terminal (deploy.sh reads this automatically):
export WEBMENTION_TOKEN=your-token-here

# Nova-triggered deploys: Nova's GUI task runner may not inherit a
# shell-exported variable, so use a gitignored local file instead:
echo "your-token-here" > .webmention-token

# GitHub Actions: add WEBMENTION_TOKEN as a repository secret (see above)
```

Without a token set, `send_webmentions.rb` just prints a notice and exits — it never blocks a deploy.

**State tracking:** `_data/webmentions_sent.json` records which (post, target) pairs have already been settled — sent, or definitively rejected by Telegraph as unsupported — so re-deploying doesn't re-send the same webmention for unchanged posts. Saved incrementally after every single target, so an interrupted run never loses track of what already went out. Committed to the repo (not gitignored), since it's shared state between local deploys and CI; both `deploy.sh` and the GitHub Action commit it automatically after sending (locally, committed but not pushed — same as everything else in this workflow).

**Adopting this on a site with an existing backlog:** the first real run treats every published post as new, which means firing webmentions at every outbound link across the entire back-catalogue at once — for an established blog, that's potentially years-old posts suddenly notifying unrelated sites out of nowhere, which isn't really what the protocol is for. Run with `--seed` first to mark the existing backlog as already-settled without sending anything (no network calls at all):

```bash
ruby send_webmentions.rb --seed
git add _data/webmentions_sent.json && git commit -m "Seed webmention baseline"
```

After that, only posts or links that didn't exist at seed time will ever trigger a real send.

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
| `col--margin-right` | Right gutter (cols 10–12) | Short asides, captions |
| `col--margin-left` | Left gutter (cols 1–2) | Short asides, captions |
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

#### Margin notes vs. sidenotes — which one to use

The site has two separate ways to put content in a margin. They are not interchangeable — pick based on the post's layout and what the note is for.

| | `col--margin-left` / `col--margin-right` | Sidenotes (`has_sidenotes: true`) |
|---|---|---|
| Works in | `layout: editorial` only, 1000px+ screens | Any layout, any width |
| Mechanism | CSS Grid column placement | CSS `float: right` |
| Numbering | None | Automatic (footnote-style superscript) |
| Mobile behaviour | Falls back to a plain full-width block below 1000px | Collapses to a tap-to-expand toggle |
| Side | Left or right | Right only |
| Built for | Short asides or captions that align beside a specific block in the grid | Citations and footnote-style annotations in continuous prose |

**Rule of thumb:** if the post uses `layout: editorial`, use `col--margin-left`/`col--margin-right` for asides — they're part of the grid system. For a standard single-column post that needs numbered footnotes or citations, use sidenotes instead (markup documented under "Sidenotes" in `AUTHORING.md`). Don't use sidenote markup inside an editorial post or vice versa — the two systems assume different parent layouts and will not interact correctly.

---

## Scroll-reveal animations

Any element on the site can fade or slide into view as it scrolls into the viewport. This is the same system that already animates post cards, gallery items, and section headers — adding `reveal` to an element's classes opts it into that system rather than introducing a separate one.

**How to use it:** add `class="reveal"` to any element in post content — a `<figure>`, a `<div>`, a paragraph — optionally with a direction modifier and a speed modifier:

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

Direction and speed modifiers combine freely — `class="reveal reveal--right reveal--fast"` slides in from the right at the faster speed. Only one of each kind takes effect; if you add two direction modifiers to the same element, the one with the higher CSS specificity (i.e. whichever rule comes later in `site.css`) wins, so stick to one direction and one speed per element.

The animation triggers once, the first time the element scrolls into view, via an `IntersectionObserver` in `main.js`. It respects `prefers-reduced-motion` automatically — no extra markup needed. If an element never scrolls (already in the initial viewport on load, as in a short draft preview), the animation plays immediately on page load instead.

Works in any layout, not just `layout: editorial` — `reveal` is a general-purpose class, independent of the grid system.

---

## Templates and CSS

- **Templates** live in `_templates/` as `.html.erb` files
- **Partials** (head, header, footer, post card, book entry) live in `_partials/`
- **CSS** is at `css/site.css` in this repo — edit here, rebuild to see changes

After editing a template or CSS file, just run `ruby build.rb` again.
