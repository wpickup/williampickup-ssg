# Technical Design — williampickup.org Static Site Generator

**Version:** July 2026  
**File:** `build.rb` (~550 lines), ERB templates, YAML data

---

## Contents

- [Overview](#overview)
- [Directory Layout](#directory-layout)
- [Configuration Block](#configuration-block)
- [Front Matter Parsing](#front-matter-parsing)
- [The Dateable Module](#the-dateable-module)
- [Model Classes](#model-classes)
  - [attr_reader](#attr_reader)
  - [One-line method syntax](#one-line-method-syntax)
  - [Safe navigation operator](#safe-navigation-operator)
  - [Array coercion with reject](#array-coercion-with-reject)
  - [Boolean coercion](#boolean-coercion)
  - [The css_classes method](#the-css_classes-method)
  - [reading_time](#reading_time)
  - [Book cover URLs](#book-cover-urls)
- [The Renderer Class](#the-renderer-class)
  - [render and partial](#render-and-partial)
  - [make_binding](#make_binding)
  - [Helper methods on Renderer](#helper-methods-on-renderer)
- [ERB Template Mechanics](#erb-template-mechanics)
  - [The local variable block pattern](#the-local-variable-block-pattern)
  - [Calling partials from templates](#calling-partials-from-templates)
  - [Conditional rendering](#conditional-rendering)
  - [Inline Ruby in output tags](#inline-ruby-in-output-tags)
  - [The head partial and extra_css](#the-head-partial-and-extra_css)
- [The Build Function](#the-build-function)
  - [Content loading](#content-loading)
  - [partition](#partition)
  - [Hash with a default block](#hash-with-a-default-block)
  - [select with Symbol#to_proc](#select-with-symbolto_proc)
  - [The sitemap template as data builder](#the-sitemap-template-as-data-builder)
  - [The guard at the bottom](#the-guard-at-the-bottom)
- [Partial Conventions](#partial-conventions)
  - [post_card partial](#post_card-partial)
- [Static Asset Handling](#static-asset-handling)
- [Feed Templates](#feed-templates)
- [The write Helper](#the-write-helper)
- [Environment Variable Override](#environment-variable-override)
- [Dependency Summary](#dependency-summary)
- [Data Flow Summary](#data-flow-summary)
- [send_webmentions.rb](#send_webmentionsrb)
  - [require_relative and the library boundary](#require_relative-and-the-library-boundary)
  - [State file design](#state-file-design)
  - [Incremental save](#incremental-save)
  - [Link extraction](#link-extraction)
  - [Seed mode](#seed-mode)
- [The Nova Task System](#the-nova-task-system)
  - [config.sh — shared configuration](#configsh--shared-configuration)
  - [build.sh and build-drafts.sh](#buildsh-and-build-draftssh)
  - [watch.sh](#watchsh)
  - [new-post.sh and new-note.sh](#new-postsh-and-new-notesh)
  - [promote-note.sh](#promote-notesh)
  - [deploy.sh](#deploysh)
- [GitHub Actions Deployment Pipeline](#github-actions-deployment-pipeline)
  - [Step by step](#step-by-step)
- [CSS Architecture](#css-architecture)
  - [Design tokens](#design-tokens)
  - [color-mix()](#color-mix)
  - [clamp() for fluid spacing](#clamp-for-fluid-spacing)
  - [Theme switching](#theme-switching)
  - [Category colour palette](#category-colour-palette)
  - [Self-hosted fonts](#self-hosted-fonts)

---

## Overview

The generator is a single Ruby script — `build.rb` — that reads source content from a set of convention-named directories, renders HTML through ERB templates, and writes a complete, self-contained static site into an output directory. There are no external frameworks, no build graphs, and no plugin system. The full build pipeline runs top-to-bottom in a single pass.

The design is deliberately conservative. Ruby is used as a scripting language, not as a framework — data flows in one direction (source → model → renderer → file), and every step is readable without reference to documentation.

---

## Directory Layout

```
williampickup-ssg/
├── build.rb                  # The entire build pipeline
├── send_webmentions.rb       # Post-build webmention dispatch (reuses build.rb models)
├── extract.rb                # One-time Tinderbox migration tool
├── Gemfile                   # Three gems: kramdown, nokogiri (extract only), rake
│
├── _posts/                   # Published long-form posts (Markdown + YAML front matter)
├── _drafts/                  # Draft posts — only included when --drafts flag is passed
├── _notes/                   # Short-form notes
├── _photos/                  # Photo metadata files
├── _books/                   # Book records
├── _pages/                   # Static pages (bio, colophon, search, blogroll)
│
├── _templates/               # One .html.erb file per page type
├── _partials/                # Reusable ERB fragments (prefixed with _)
├── _data/                    # YAML data files (nav.yml, now.yml, blogroll.yml)
│
├── css/                      # Copied verbatim to output
├── javascript/               # Copied verbatim to output
├── fonts/                    # Copied verbatim to output
└── assets/                   # Copied verbatim to output
```

The output goes to `_out/` by default, overridable by the `SSG_OUT_DIR` environment variable. That override is what allows CI to write to a different location than a local development server without needing separate configuration files.

---

## Configuration Block

At the top of `build.rb`, a set of Ruby constants defines all site-level values:

```ruby
SITE_URL       = 'https://williampickup.org'
SITE_TITLE     = 'William Pickup'
AUTHOR_NAME    = 'William Pickup'
AUTHOR_EMAIL   = 'will@williampickup.org'
COPYRIGHT_YEAR = Date.today.year
```

These are Ruby **constants** (names beginning with a capital letter), which means Ruby will emit a warning if anything tries to re-assign them. Using constants rather than variables makes it immediately clear that these values are fixed for the lifetime of the build and safe to reference from anywhere — templates, models, helper methods — without being passed as arguments.

`BUILD_STAMP` and `BUILD_SHA` are computed once at startup:

```ruby
BUILD_STAMP = Time.now.utc.strftime("%-d %b '%y, %H:%M UTC")
BUILD_SHA   = begin
  sha = `git rev-parse --short HEAD 2>/dev/null`.strip
  sha.empty? ? nil : sha
rescue StandardError
  nil
end
```

`BUILD_SHA` uses a **backtick expression** — Ruby's notation for running a shell command and capturing its standard output as a string. The `2>/dev/null` redirect suppresses stderr so the build doesn't print a Git error when the project is not in a Git repository. The `rescue StandardError` wraps the whole block in case Git is not installed at all, returning `nil` gracefully. This is a `begin…rescue…end` block used as an expression — Ruby allows rescue at expression level, meaning the whole construct evaluates to either the SHA string or `nil`, and that value is assigned directly to the constant.

The `%-d` format code in `strftime` suppresses the leading zero from the day number (so `3` rather than `03`). Using UTC rather than the system local time ensures the stamp is identical whether the build runs locally in Sydney or on a GitHub Actions runner in an unknown timezone.

`DRAFTS` is set from the command-line arguments:

```ruby
DRAFTS = ARGV.include?('--drafts')
```

`ARGV` is Ruby's built-in array of command-line arguments. This evaluates to `true` or `false` at startup, making `DRAFTS` a boolean constant that the rest of the build can test anywhere without needing to pass it through function arguments.

`STATIC_DIRS` uses a **map transformation** on a literal array of directory names:

```ruby
STATIC_DIRS = %w[css javascript fonts assets].map { |d| File.join(SRC_DIR, d) }
```

`%w[...]` is Ruby's **word array literal** — it creates an array of strings split on whitespace without requiring quotes or commas. The `map` block then converts each bare name into a fully-qualified absolute path, which is what `FileUtils.cp_r` requires later.

---

## Front Matter Parsing

Every content file uses YAML front matter in the Jekyll convention:

```
---
title: Walking the Coast to Coast
date: 2024-09-12
topics:
  - places-experiences
---

Body text begins here...
```

The parsing function uses a **regular expression with named capture groups** applied via `=~`:

```ruby
def parse_frontmatter(path)
  raw = File.read(path, encoding: 'utf-8')
  if raw =~ /\A---\s*\n(.*?)\n---\s*\n(.*)\z/m
    fm   = YAML.safe_load($1, permitted_classes: [Date, Time]) || {}
    body = $2.strip
  else
    fm   = {}
    body = raw.strip
  end
  [fm, body]
end
```

Several things worth examining here:

- `\A` anchors the match to the very start of the string (as opposed to `^`, which matches the start of any line). This ensures the function only recognises front matter if the file starts with `---`, not if `---` appears somewhere in the body.
- `\z` anchors to the very end of the string.
- The `m` flag after the closing `/` enables **multiline mode**, which makes `.` match newline characters. Without it, the `(.*?)` inside the front matter block and the `(.*)` for the body would stop at the first newline.
- `(.*?)` uses a **lazy (non-greedy) quantifier** — it matches as few characters as possible. This is essential: it makes the regex stop at the first closing `---` rather than the last one in the file if the body happens to contain `---`.
- `$1` and `$2` are Ruby's **match data globals** — they hold the content of the first and second capture groups from the most recent `=~` match. `$1` is the YAML front matter text; `$2` is the body.
- `YAML.safe_load` with `permitted_classes: [Date, Time]` is a security boundary. Plain `YAML.load` executes arbitrary Ruby objects from YAML (a known vulnerability). `safe_load` restricts deserialisation to basic types; the `permitted_classes` option adds only `Date` and `Time`, which are needed because YAML natively represents ISO date strings as Ruby `Date` objects.
- The `|| {}` after `safe_load` handles the edge case of an empty front matter block — an empty YAML document evaluates to `nil`, and `nil || {}` returns the empty hash.
- The function returns an **array literal** `[fm, body]`, which callers receive using Ruby's **multiple assignment**: `fm, body = parse_frontmatter(path)`. Ruby unpacks the array into the two variables in one step.

---

## The Dateable Module

All four content-bearing model classes (Post, Note, Photo, Book) need to coerce dates from YAML into Ruby `Date` objects. Rather than copying the method into each class, it is extracted into a module:

```ruby
module Dateable
  private
  def coerce_date(val)
    return val if val.is_a?(Date)
    Date.parse(val.to_s)
  rescue ArgumentError
    nil
  end
end
```

`module` in Ruby is a namespace that can be **mixed in** to a class with `include`. When a class calls `include Dateable`, the module's methods become instance methods of that class, as if they had been defined directly on it. This is Ruby's principal mechanism for sharing behaviour without inheritance — it avoids the coupling that a shared base class would create while keeping the logic in one place.

The `private` declaration before the method definition means `coerce_date` is only callable from within the class itself, not from outside. This is appropriate because it is an implementation detail of construction, not part of the public interface.

The early-return `return val if val.is_a?(Date)` handles the common case where YAML has already deserialized the value to a `Date` object (which happens when the value is an unquoted ISO date like `2024-09-12`). The rescue catches only `ArgumentError`, which is what `Date.parse` raises for an unparseable string — not a bare `rescue` that would swallow all exceptions including programming errors.

---

## Model Classes

There are five model classes: `Post`, `Note`, `Photo`, `Book`, and `Page`. They follow a consistent pattern: the constructor receives a file path, calls `parse_frontmatter`, and assigns all front matter fields to instance variables. Computed properties are expressed as methods.

### attr_reader

```ruby
attr_reader :slug, :title, :date, :description, :lede,
            :categories, :tags, :topics, ...
```

`attr_reader` is a Ruby macro — a class method that generates simple getter methods at class-definition time. Each symbol in the list becomes a method that returns the corresponding instance variable. Writing `attr_reader :slug` is exactly equivalent to writing:

```ruby
def slug
  @slug
end
```

This is pure convenience — it eliminates repetitive boilerplate while keeping the public interface explicit. Only `attr_reader` is used (not `attr_writer` or `attr_accessor`), which means the attributes are **read-only from outside** the class. The instance variables are only set in `initialize`.

### One-line method syntax

Ruby 3.0 introduced a concise method definition syntax using `=`:

```ruby
def type          = 'post'
def url_path      = "#{draft ? 'drafts' : 'posts'}/#{slug}.html"
def url           = "#{SITE_URL}/#{url_path}"
def primary_topic = topics.first
def date_display  = date&.strftime('%-d %B %Y') || ''
def date_iso      = date&.iso8601 || ''
def year          = date&.year
```

These are **endless methods** — they define a method whose body is a single expression, with no `end` keyword required. They are equivalent to full `def…end` blocks but communicate clearly that the method is a pure computation returning one value.

### Safe navigation operator

The `&.` operator (sometimes called the "lonely operator") is used throughout the model methods:

```ruby
def date_display = date&.strftime('%-d %B %Y') || ''
def date_iso     = date&.iso8601 || ''
def year         = date&.year
```

`date&.strftime(...)` means: call `strftime` on `date` if `date` is not `nil`; if `date` is `nil`, return `nil` without raising a `NoMethodError`. Without it, a post with no date would raise an exception when `date_display` was called, because `nil` does not have a `strftime` method. The trailing `|| ''` converts any remaining `nil` to an empty string, which is safe to interpolate into HTML.

### Array coercion with reject

```ruby
@categories = Array(fm['categories']).reject(&:empty?)
@tags       = Array(fm['tags']).reject(&:empty?)
@topics     = Array(fm['topics']).reject(&:empty?)
```

`Array(value)` is a Ruby kernel method that **safely converts any value to an array**. If `value` is already an array, it is returned unchanged. If it is `nil`, an empty array is returned. If it is a single string, it is wrapped in a one-element array. This handles the three cases that can appear in YAML: a key that is absent (nil), a key with one string value, or a key with a proper list. Without this, the code would need an explicit type check.

`reject(&:empty?)` removes any blank strings that might slip through. The `&:empty?` syntax converts the symbol `:empty?` into a **proc** using `Symbol#to_proc`, and passes it as a block to `reject`. It is equivalent to `reject { |s| s.empty? }` but more concise.

### Boolean coercion

```ruby
@featured    = fm['featured'] == true
@has_sidenotes = fm['has_sidenotes'] == true
@draft       = fm['draft'] == true || force_draft
```

YAML parses `true` and `false` as Ruby booleans, but a missing key returns `nil`. Comparing with `== true` ensures the instance variable is always a genuine Ruby boolean, never `nil`. This matters because the variable is used in boolean contexts throughout templates and the build loop.

### The css_classes method

```ruby
def css_classes
  classes = ['h-entry']
  classes << "cat--#{primary_topic}" if primary_topic
  classes << 'has-sidenotes'         if has_sidenotes
  classes << "layout--#{layout}"    if layout && layout != 'standard'
  classes.join(' ')
end
```

This builds the `class` attribute string for the `<article>` element by starting with a base array and conditionally appending to it with `<<` (the array append operator), using **postfix if** — Ruby's inline conditional that reads as natural English: "append this if that". The final `join(' ')` converts the array to a space-separated string. This pattern is cleaner than string concatenation with conditionals because each class is handled independently and the base case is always guaranteed.

### reading_time

```ruby
def reading_time
  words = content_html.gsub(/<[^>]+>/, '').split.length
  "#{[(words / 200.0).ceil, 1].max} min read"
end
```

This strips HTML tags with a simple regex, splits on whitespace to count words, and divides by 200 (a standard words-per-minute estimate, using `200.0` to force **floating-point division** rather than integer division). `.ceil` rounds up to the nearest whole minute. `[result, 1].max` ensures the minimum is 1 minute even for very short posts — `Array#max` on a two-element array is a clean way to express a lower bound without an `if` statement.

### Book cover URLs

```ruby
def cover_src
  return cover_url if cover_url
  return nil unless isbn
  "https://covers.openlibrary.org/b/isbn/#{isbn}-M.jpg"
end

def cover_srcset
  return nil unless isbn
  m = "https://covers.openlibrary.org/b/isbn/#{isbn}-M.jpg"
  l = "https://covers.openlibrary.org/b/isbn/#{isbn}-L.jpg"
  "#{m} 180w, #{l} 500w"
end
```

These methods use **guard clauses** — early returns at the top of the method that handle the edge cases before the main logic. `return cover_url if cover_url` returns the explicit URL if one was provided in the front matter. `return nil unless isbn` handles the case where no ISBN was supplied. The remainder of the method only runs when the ISBN is known, at which point it constructs Open Library CDN URLs. Guard clauses keep the main path unindented and avoid nested conditionals.

---

## The Renderer Class

```ruby
class Renderer
  def initialize(all_posts, nav_data = {})
    @all_posts = all_posts
    @nav_data  = nav_data
  end
  ...
end
```

`nav_data = {}` is a **default parameter** — if `Renderer.new` is called with only one argument, `nav_data` defaults to an empty hash rather than raising an `ArgumentError`. This makes the class slightly more flexible without requiring callers to always supply navigation data.

The `Renderer` is constructed once at the start of `build()` and shared across the entire build. It holds two pieces of state: the full post list (used for cross-linking between posts) and the navigation data (used by every header and footer partial). Everything else is passed in as locals per render call.

### render and partial

```ruby
def render(template_name, locals = {})
  path     = File.join(TEMPLATES_DIR, "#{template_name}.html.erb")
  template = ERB.new(File.read(path), trim_mode: '-')
  b        = make_binding(locals)
  template.result(b)
end

def partial(name, locals = {})
  path     = File.join(PARTIALS_DIR, "_#{name}.html.erb")
  template = ERB.new(File.read(path), trim_mode: '-')
  b        = make_binding(locals)
  template.result(b)
end
```

These two methods are nearly identical in structure, differing only in which directory they look in and whether they prepend an underscore to the filename (the underscore convention signals that a file is a partial, not a standalone page). Each call reads the template file fresh from disk, compiles it into an `ERB` object, and evaluates it in a custom binding.

`ERB.new(source, trim_mode: '-')` is the core template compilation step. The `trim_mode: '-'` option enables **dash trimming**: any ERB tag that ends with `-%>` will consume the newline that follows it in the template source, preventing blank lines from appearing in the rendered output. This is particularly important in loops — without it, each iteration of a post list would emit extra blank lines between list items.

`template.result(b)` evaluates the compiled template using binding `b` and returns the result as a string.

### make_binding

```ruby
def make_binding(locals)
  b = binding
  locals.each { |k, v| b.local_variable_set(k, v) }
  b.local_variable_set(:renderer, self)
  b
end
```

This is the mechanism by which ERB templates access their data. `binding` is a Ruby keyword that captures the current **execution context** — the local variables, the self reference, and the block. It returns a `Binding` object that ERB uses as the scope in which to evaluate the template.

`b.local_variable_set(k, v)` injects each key-value pair from the `locals` hash into that binding as a named local variable. So when `render('post', post: post, root: '../')` is called, the template can reference `post` and `root` directly as variables — not as hash lookups, but as genuine locals in scope.

The final `b.local_variable_set(:renderer, self)` injects the `Renderer` instance itself into the binding as `renderer`. This is how templates call `renderer.partial(...)`, `renderer.topic_label(...)`, and `renderer.h(...)` — the template has a reference to the object that rendered it, giving it access to all of the Renderer's public methods. It also means that `publit_srcset` and `h` can be called in templates without a receiver — they are actually delegated through `renderer` via the binding.

### Helper methods on Renderer

```ruby
def h(str)           = CGI.escapeHTML(str.to_s)
def publit_srcset(url, fp = nil) ...
def publit_width(url, w) = url.sub(%r{(publit\.io/file/)}, "\\1w_#{w}/")
def topic_label(id)  = TOPIC_LABELS[id] || id.to_s.gsub('-', ' ').split.map(&:capitalize).join(' ')
```

`h` is the standard Rails convention for HTML-escaping, replicated here without the framework. `CGI.escapeHTML` converts `<`, `>`, `&`, `"`, and `'` to their HTML entity equivalents. `.to_s` ensures that even a `nil` value becomes the empty string `""` rather than raising a `NoMethodError`.

`publit_srcset` generates a `srcset` attribute for Publitio CDN images. It works by inserting a width token into the URL path:

```ruby
def publit_width(url, w) = url.sub(%r{(publit\.io/file/)}, "\\1w_#{w}/")
```

`%r{...}` is Ruby's **regex literal** using braces as delimiters instead of the more common `/…/`. Braces are used here because the URL contains forward slashes, which would need escaping if `/…/` delimiters were used. The capture group `(publit\.io/file/)` matches the CDN path fragment, and `"\\1w_#{w}/"` replaces it with the same fragment followed by the width variant. `\\1` in the replacement string is a **backreference** to the first capture group; the double backslash is needed because the replacement string is a Ruby string literal where `\1` would otherwise be interpreted as an escape sequence.

`topic_label` uses a **fallback chain**: if the topic ID exists in `TOPIC_LABELS`, return its human label; otherwise, construct a label by replacing hyphens with spaces, splitting into words, capitalising each word with `map(&:capitalize)`, and joining back with spaces. This means new topics work without editing the hash.

---

## ERB Template Mechanics

ERB (Embedded Ruby) is part of Ruby's standard library. Templates are plain text files with two kinds of embedded tags:

| Tag | Behaviour |
|-----|-----------|
| `<%= expression %>` | Evaluates the expression and inserts the result into the output |
| `<%- ... -%>` | Executes Ruby code with no output; the `-` on either end trims adjacent whitespace/newlines |
| `<%# comment %>` | A comment — not output, not executed |

### The local variable block pattern

Every template begins with an assignment block:

```erb
<%
  page_title    = "#{post.title} — #{SITE_TITLE}"
  description   = post.description
  canonical_url = post.url
  og_type       = 'article'
  og_title      = post.title
  og_image      = post.image_url
  date_iso      = post.date_iso
  img           = publit_srcset(post.image_url, post.image_focal_point) if post.use_featured_image && post.image_url
  primary_topic = post.primary_topic
  topic_lbl     = renderer.topic_label(primary_topic)
-%>
```

The trailing `-%>` on the closing tag trims the newline that follows, so this block contributes no blank lines to the output. These assignments normalise data into consistently-named variables that the rest of the template uses, regardless of which model object provided them. The pattern keeps the template body clean — it doesn't need to know whether it is working with a `Post` or a `Note` for these purposes.

The `img = ... if post.use_featured_image && post.image_url` line uses **conditional assignment in expression position** — Ruby's `if` used as a modifier on the right of an assignment. If the condition is false, `img` is assigned `nil`, which is then tested later with `<%- if img -%>`. This means no image markup is output when either condition fails.

### Calling partials from templates

```erb
<%= renderer.partial('head',
      page_title: page_title, description: description,
      canonical_url: canonical_url, og_type: og_type, og_title: og_title,
      og_image: og_image, date_iso: date_iso, root: root) %>
```

This is a regular Ruby method call. The hash argument (the keyword-style key: value pairs) is Ruby's **implicit hash** syntax — when the last argument to a method is a hash, the braces are optional. `renderer.partial` looks up `_head.html.erb`, injects those key-value pairs as local variables into a binding, evaluates the ERB, and returns the rendered string, which `<%= ... %>` inserts into the output.

The `root` variable is a relative path prefix (`''`, `'../'`, or `'/'`) that differs depending on how deep in the output hierarchy a page sits. All asset and page links are constructed as `<%= root %>css/site.css` rather than absolute paths, so the site can be served from a subdirectory during local development and from the root in production without changing any links.

### Conditional rendering

```erb
<%- if img -%>
        <figure class="post-hero-image">
          <img
            src="<%= img[:src] %>"
            srcset="<%= img[:srcset] %>"
            ...
            <% img[:style] %>>
        </figure>
<%- end -%>
```

`img` is a hash returned by `publit_srcset` — a Ruby hash with symbol keys `:src`, `:srcset`, and `:style`. The `img[:src]` syntax accesses values by key. Inside the `<img>` tag, `img[:style]` emits the `style="object-position: ..."` attribute string directly when a focal point was specified, or an empty string when it was not — so no conditional block is needed for the attribute itself.

### Inline Ruby in output tags

The post template constructs links inline within ERB output tags:

```erb
<time class="dt-published" datetime="<%= post.date_iso %>">
  <%= post.date&.strftime('%-d %B') %>
  <a href="<%= root %>archive/<%= post.year %>.html"><%= post.year %></a>
</time>
```

```erb
<%= post.categories.map { |c|
      %(<a href="#{root}categories/#{c}.html">#{h(c)}</a>)
    }.join(', ') %>
```

The second example uses `map` with a block that returns a string using `%(...)` — Ruby's **percent literal for strings**, equivalent to double-quoted string with interpolation. `join(', ')` assembles the array into a comma-separated list. The `h(c)` call HTML-escapes the category name. This is more robust than building the string with concatenation because `map` + `join` naturally handles the zero, one, and many cases (empty string, no separator needed, comma-separated respectively).

### The head partial and extra_css

The `_head.html.erb` partial includes a mechanism for optional extra stylesheets:

```erb
<%- Array(defined?(extra_css) ? extra_css : nil).each do |sheet| -%>
  <link rel="stylesheet" href="<%= root %>css/<%= sheet %>">
<%- end -%>
```

`defined?(extra_css)` is a Ruby keyword that returns a string describing what `extra_css` is (`"local-variable"`, `"constant"`, etc.) if it exists in scope, or `nil` if it does not. This is necessary because the partial is used in many templates, most of which do not pass `extra_css` as a local. If the code simply referenced `extra_css` without the `defined?` guard, it would raise a `NameError` in templates that do not define it. The ternary wraps the check, and `Array(nil)` produces an empty array, so the loop body never executes when no extra CSS was requested.

---

## The Build Function

`build()` is a single top-level function that orchestrates the entire pipeline:

```
1. Wipe and recreate OUT_DIR
2. Load all content into model objects
3. Construct one Renderer
4. Render each content item, writing to file
5. Render all index and listing pages
6. Render feeds, sitemap, robots.txt
7. Copy static assets
```

### Content loading

Each content type has its own loader function following the same pattern:

```ruby
def load_posts
  from_posts = Dir[File.join(POSTS_DIR, '*.md')]
    .map { |p| Post.new(p) rescue (warn "Error loading #{p}: #{$!}"; nil) }
  from_drafts = Dir.exist?(DRAFTS_DIR) ? Dir[File.join(DRAFTS_DIR, '*.md')]
    .map { |p| Post.new(p, force_draft: true) rescue (warn "Error loading #{p}: #{$!}"; nil) } : []
  (from_posts + from_drafts)
    .compact.reject { |p| p.draft && !DRAFTS }
    .sort_by { |p| p.date || Date.new(1970) }.reverse
end
```

`Dir[pattern]` is Ruby's **glob expansion** — it returns an array of all file paths matching the pattern. This is a method call on the `Dir` class using the `[]` indexing operator (which is actually a method named `[]`), not a hash lookup.

The `rescue` on the same line as `.map { |p| Post.new(p) rescue ... }` is a compact form of **inline rescue**. If `Post.new(p)` raises any exception, the rescue clause runs instead, printing a warning and returning `nil`. This means a single malformed content file does not abort the entire build.

`$!` is Ruby's **global error variable** — it holds the most recently raised exception. Using it in the rescue clause prints the error message without needing to name the exception in the rescue signature (`rescue => e`).

`.compact` removes `nil` values from the array — the `nil` entries inserted by the inline rescue for any files that failed to load.

`.sort_by { |p| p.date || Date.new(1970) }.reverse` sorts by date, using `Date.new(1970)` (the Unix epoch) as a fallback for posts with no date, which sorts them to the end. `.reverse` produces descending (newest-first) order.

### partition

```ruby
published_posts, draft_posts = posts.partition { |p| !p.draft }
```

`partition` splits an array into two arrays in one pass based on whether the block returns true or false. The result is a two-element array that Ruby unpacks directly via multiple assignment. This is cleaner than two separate `select` calls and makes the intent explicit — the post list is divided into exactly two categories.

### Hash with a default block

```ruby
topic_groups = Hash.new { |h, k| h[k] = [] }
posts.each { |p| p.topics.each { |t| topic_groups[t] << p } }
```

`Hash.new { |h, k| h[k] = [] }` creates a hash whose **default block** is invoked whenever a key is accessed that does not yet exist. When `topic_groups['books-ideas']` is accessed for the first time, the block runs, creates an empty array for that key, and returns it. This means `topic_groups[t] << p` (append post `p` to the array for topic `t`) works correctly without first needing to check whether the key exists and initialise it. The block form (rather than `Hash.new([])`) is essential because `Hash.new([])` would share a single array object across all missing keys.

### select with Symbol#to_proc

```ruby
featured_posts = posts.select(&:featured).first(6)
now_books      = books.select(&:on_now_page)
```

`&:featured` converts the symbol `:featured` to a proc via `Symbol#to_proc`, producing the equivalent of `select { |p| p.featured }`. It is a concise way to filter a collection by a boolean attribute method.

### The sitemap template as data builder

The `sitemap.html.erb` template is notable because it builds its data structure in the front section rather than delegating that work to the builder:

```erb
<%
  urls = []
  urls << [SITE_URL + '/', Date.today.iso8601]
  posts.each { |p| urls << [p.url, (p.date || Date.today).iso8601] }
  notes.each { |n| urls << [n.url, (n.date || Date.today).iso8601] }
  ...
  %w[blog notes gallery reading now archive].each { |slug| urls << ["#{SITE_URL}/#{slug}.html", nil] }
-%>
```

This builds an array of `[url, lastmod]` pairs before the XML output begins, then iterates over it. The two-element array pairs are a lightweight alternative to a struct — they work well here because the sitemap only needs two things about each URL.

### The guard at the bottom

```ruby
build if __FILE__ == $0
```

`__FILE__` is a Ruby special variable that holds the path of the current source file. `$0` is the path of the main script being run. They are equal when `build.rb` is executed directly (`ruby build.rb`), but not when another file loads it with `require_relative 'build'`. This guard is what allows `send_webmentions.rb` to do:

```ruby
require_relative 'build'
```

...and gain access to `Post`, `load_posts`, `Note`, `load_notes`, and all the helper functions, without triggering a full site build as a side effect. It is the standard Ruby pattern for a file that is both a standalone script and a reusable library.

---

## Partial Conventions

Partials are ERB files in `_partials/`, named with a leading underscore (`_header.html.erb`, `_post_card.html.erb`). They are called via `renderer.partial('header', ...)` — the method prepends the underscore and appends the extension.

The header and footer partials use a `defined?` guard for the `current` variable:

```erb
<%- nav = defined?(current) ? current : nil -%>
```

This identifies the active navigation item. Templates pass `current: 'writing'` (or `'reading'`, `'notes'`, etc.) to the header and footer when rendering, and the partial uses it to emit `aria-current="page"` on the matching navigation link:

```erb
<%= ' aria-current="page"' if nav && nav == item['current'] %>
```

The space before `aria-current` is significant — it is inside the string literal, so the attribute is separated from whatever precedes it in the tag.

### post_card partial

```erb
<%
  primary_topic  = post.primary_topic
  topic_lbl      = renderer.topic_label(primary_topic)
  all_topics_str = post.topics.join(';')
  all_tags_str   = post.tags.join(';')
  img            = publit_srcset(post.image_url, post.image_focal_point) if post.image_url
-%>
<li class="post-card<%= " cat--#{primary_topic}" if primary_topic %>"
    data-category="<%= all_topics_str %>"
    data-tags="<%= all_tags_str %>"
    data-featured="<%= post.featured %>">
```

The `data-category`, `data-tags`, and `data-featured` attributes are **data attributes** read by `main.js` to implement client-side filtering. The semicolon-joined strings (`post.topics.join(';')`) are a simple encoding that JavaScript can split on to get an array of values.

`" cat--#{primary_topic}" if primary_topic` uses string interpolation inside a conditional — the entire interpolated string (including the leading space) is only produced if `primary_topic` is truthy. When it is `nil`, the expression returns `nil`, and `<%= nil %>` emits an empty string.

---

## Static Asset Handling

```ruby
STATIC_DIRS.each do |src|
  next unless Dir.exist?(src)
  dest = File.join(OUT_DIR, File.basename(src))
  FileUtils.rm_rf(dest)
  FileUtils.cp_r(src, dest)
end
```

`next unless Dir.exist?(src)` is a **guard clause in a loop** — `next` skips to the next iteration immediately. This tolerates missing directories without an error. `FileUtils.rm_rf(dest)` removes the destination directory if it already exists (from a previous build), and `FileUtils.cp_r(src, dest)` copies the entire source directory tree recursively. The `r` in both method names stands for "recursive".

`File.basename(src)` extracts just the final component of the path (e.g. `css` from `/path/to/williampickup-ssg/css`), which is the subdirectory name that should appear in the output.

---

## Feed Templates

The RSS feed illustrates a technique used throughout the project — duck typing on `respond_to?`:

```erb
<%- if entry.respond_to?(:description) && entry.description -%>
  <description><![CDATA[<%= entry.description %>]]></description>
<%- end -%>
<%- if entry.respond_to?(:categories) -%>
<%- entry.categories.each do |cat| -%>
  <category><%= h(cat) %></category>
<%- end -%>
<%- end -%>
```

`respond_to?(:description)` asks whether the object has a method named `description` — it does not care what class the object is. This is **duck typing**: the template works correctly with any object that has the right methods, without needing to check its class. Here, both `Post` objects (which have `description`, `categories`, and `topics`) and `Note` objects (which do not have those methods) could in principle be passed as `entry`, and the template handles both without a type check.

`CDATA` sections in the feed (`<![CDATA[...]]>`) allow the HTML content to be embedded in XML without escaping every `<` and `&`. The content is delimited by the CDATA markers rather than entity-encoded, which means feed readers receive the raw HTML.

---

## The write Helper

```ruby
def write(path, content)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, content, encoding: 'utf-8')
  puts "  #{path.sub(OUT_DIR + '/', '')}"
end
```

`FileUtils.mkdir_p` creates the full directory tree to the destination file if it does not already exist. The `p` stands for "parents" — it creates intermediate directories. Without it, writing to `_out/posts/some-slug.html` would fail with a `No such file or directory` error when the `posts/` directory had not yet been created.

`path.sub(OUT_DIR + '/', '')` strips the output directory prefix from the path before printing it, so the console shows `posts/some-slug.html` rather than the full absolute path. This makes the build log readable without being noisy.

---

## Environment Variable Override

```ruby
OUT_DIR = ENV['SSG_OUT_DIR'] || File.join(__dir__, '_out')
```

`ENV` is Ruby's representation of the process environment — it behaves like a hash where the keys are environment variable names. `ENV['SSG_OUT_DIR']` returns the value of that variable, or `nil` if it is not set. The `||` then falls back to the default `_out` path. This is the standard Ruby pattern for environment-configurable defaults and is what allows the GitHub Actions workflow to write to a different location than a local development run.

---

## Dependency Summary

The Gemfile declares three gems:

```ruby
gem 'kramdown'          # Markdown-to-HTML conversion
gem 'nokogiri'          # XML parsing — used only by extract.rb
gem 'rake'              # Optional task runner (not used by build.rb directly)
```

`build.rb` itself requires only `kramdown` at runtime. Everything else (`erb`, `date`, `fileutils`, `yaml`, `cgi`) is part of Ruby's standard library and needs no installation. This means the build has a minimal, stable dependency footprint — the only external code running on every build is Kramdown.

---

## Data Flow Summary

```
_posts/*.md      ─┐
_notes/*.md      ─┤
_photos/*.md     ─┤── parse_frontmatter()  ──►  Model objects (Post, Note, ...)
_books/*.md      ─┤
_pages/*.md      ─┘

_data/nav.yml    ─┐
_data/now.yml    ─┤── YAML.safe_load()     ──►  Plain Ruby hashes
_data/blogroll.yml─┘

Model objects + hashes
        │
        ▼
  Renderer.new(all_posts, nav_data)
        │
        ├── render('post',  post: p, prev_post: ..., root: '../')
        ├── render('home',  posts: ..., featured_posts: ..., root: '')
        ├── render('blog',  posts: ..., root: '')
        ├── ...
        │       │
        │       ├── partial('head',    page_title: ..., ...)
        │       ├── partial('header',  root: ..., current: ...)
        │       ├── partial('post_card', post: ..., root: ...)
        │       └── partial('footer',  root: ..., current: ...)
        │
        ▼
  write(OUT_DIR/posts/slug.html, html_string)
  write(OUT_DIR/index.html, html_string)
  ...
  FileUtils.cp_r(css/, OUT_DIR/css/)
```

---

## send_webmentions.rb

`send_webmentions.rb` is a post-build script that discovers all outbound links in published post HTML, compares them against a persistent record of what has already been sent, and dispatches webmention notifications for anything new via the Telegraph API. It is a standalone script but deliberately shares all of `build.rb`'s models and loaders.

### require_relative and the library boundary

```ruby
require_relative 'build'
```

This loads `build.rb` as a library. Because `build.rb` ends with `build if __FILE__ == $0`, the full build pipeline does not run — only the constant definitions, model classes, and loader functions are brought into scope. `send_webmentions.rb` then calls `load_posts` directly to get the same post objects the builder uses, without duplicating any parsing or model logic.

### State file design

The script tracks sent webmentions in `_data/webmentions_sent.json`, a JSON file committed to the repository:

```ruby
STATE_FILE = File.join(__dir__, '_data', 'webmentions_sent.json')

def load_state
  return {} unless File.exist?(STATE_FILE)
  JSON.parse(File.read(STATE_FILE))
rescue JSON::ParserError
  {}
end

def save_state(state)
  FileUtils.mkdir_p(File.dirname(STATE_FILE))
  File.write(STATE_FILE, JSON.pretty_generate(state.sort.to_h))
end
```

The state is a hash keyed by post slug, where each value is an array of target URLs already settled. `JSON.pretty_generate` with `state.sort.to_h` produces deterministic output — the keys are always alphabetically sorted, which keeps Git diffs readable and means the file does not change spuriously between runs.

`rescue JSON::ParserError` handles a corrupted state file by starting fresh rather than crashing. `return {} unless File.exist?` is a guard clause that handles the first-run case where no state file has been created yet.

The state file is committed to the repository because CI and local builds need to agree on what has already gone out. If it were local-only, a CI run would re-send every webmention that a previous local run had sent, causing duplicates.

### Incremental save

```ruby
new_targets.each do |target|
  code, body = send_webmention(post.url, target)

  if [200, 201].include?(code)
    state[post.slug] << target
    sent_count += 1
  elsif SETTLED_ERRORS.include?(body['error'])
    state[post.slug] << target   # won't retry
    err_count += 1
  else
    err_count += 1               # will retry — not added to state
  end

  save_state(state)  # after every single target
end
```

`save_state` is called after every individual target, not once at the end of the loop. This is a deliberate design choice: if the script is interrupted mid-run (network timeout, Ctrl-C, CI job cancelled), the state file contains everything that had been settled up to that point, and the next run continues from where it stopped rather than starting over and re-sending. The comment in the script header documents why — this behaviour was learned from experience with the previous version.

The three-way branch on response code is worth examining:
- HTTP 200 or 201 means the webmention was accepted → add to state (won't retry)
- A `SETTLED_ERRORS` error code means the target definitively doesn't support webmentions, the link wasn't found, or the source wasn't valid HTML → add to state (won't retry, but not a success)
- Any other error means a transient failure → do not add to state (will retry on next run)

```ruby
SETTLED_ERRORS = %w[not_supported invalid_parameter no_link_found source_not_html].freeze
```

`SETTLED_ERRORS` is frozen (`.freeze` prevents any code from accidentally modifying the array at runtime) and uses `%w[]` for conciseness.

### Link extraction

```ruby
def extract_targets(html)
  html.scan(/href="(https?:\/\/[^"]+)"/).flatten.uniq.select do |url|
    host = URI(url).host
    host && !EXCLUDED_HOSTS.include?(host)
  rescue URI::InvalidURIError
    false
  end
end
```

`String#scan` with a capture group returns an array of arrays — each inner array contains the captures from one match. `.flatten` collapses this to a flat array of URL strings. `.uniq` removes duplicates (so linking to the same external URL twice in a post doesn't send two webmentions).

The `.select` block uses `URI(url).host` to extract the hostname for filtering. `rescue URI::InvalidURIError` inside the block handles any malformed URLs — a block-level rescue returns `false` for that element, which `select` treats as rejection. Own-site URLs and CDN hosts are excluded via `EXCLUDED_HOSTS`.

```ruby
EXCLUDED_HOSTS = [
  URI(SITE_URL).host,
  'media.publit.io',
].freeze
```

`URI(SITE_URL).host` extracts the hostname from the `SITE_URL` constant at load time, so the exclusion list doesn't need to be maintained separately from the main site configuration.

### Seed mode

```ruby
SEED_MODE = ARGV.include?('--seed')

if SEED_MODE
  load_posts.each do |post|
    targets = extract_targets(post.content_html)
    next if targets.empty?
    state[post.slug] = (state[post.slug] || []) | targets
    save_state(state)
  end
  puts "Seeded #{state.values.flatten.length} existing post/target pairs as already-settled."
  exit 0
end
```

Seed mode marks the entire back-catalogue as already sent without making any network calls. `(state[post.slug] || []) | targets` merges any existing entries with the newly found targets using the **array union operator** `|`, which produces a deduplicated result. `exit 0` terminates the process with a success code after seeding.

The `--seed` flag solves a practical problem: the very first run on a site with existing posts would otherwise fire webmentions for years of old content, which is both noisy for recipients and contrary to the protocol's intent. Run once with `--seed`, commit the state file, and from that point only new posts trigger real sends.

---

## The Nova Task System

Nova is a macOS code editor (by Panic) with a built-in task runner. The project's Nova tasks expose the key build operations as named commands reachable from a menu or keyboard shortcut, without requiring a terminal. All tasks are thin wrappers around shell scripts stored in `.nova/Scripts/`.

### config.sh — shared configuration

Every script begins by sourcing `config.sh`:

```bash
source "$( dirname "${BASH_SOURCE[0]}" )/config.sh"
```

`${BASH_SOURCE[0]}` is the path to the currently-executing script file. `dirname` extracts its directory. This pattern resolves the config file relative to the script's own location, so the scripts work correctly regardless of the working directory when they are called.

`config.sh` defines four things used across all scripts:

```bash
SSH_HOST="williampickup"
SSH_USER="will"
REMOTE_PATH="/var/www/htdocs/williampickup.org"

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"

OUT_DIR="${SSG_OUT_DIR:-/Users/will/Sites/williampickup.org/_site}"
export SSG_OUT_DIR="$OUT_DIR"
```

`PROJECT_DIR` is resolved by navigating two levels up from the Scripts directory (`../..` from `.nova/Scripts/` lands at the project root) and calling `pwd` to get the absolute path. This is the standard Bash pattern for finding a project root relative to a known file location.

`${SSG_OUT_DIR:-/Users/will/Sites/williampickup.org/_site}` is Bash **parameter expansion with a default**: use `$SSG_OUT_DIR` if it is set and non-empty; otherwise use the fallback path. The comment in the file explains the Nova-specific context: because Nova launches tasks through a GUI process rather than an interactive shell, shell profile exports (`export SSG_OUT_DIR=...` in `.zshrc`) are not reliably inherited. Defining the value in `config.sh` and re-exporting it ensures all child processes in the task see it.

Similarly for the webmention token:

```bash
if [ -z "${WEBMENTION_TOKEN:-}" ] && [ -f "$PROJECT_DIR/.webmention-token" ]; then
  export WEBMENTION_TOKEN="$(cat "$PROJECT_DIR/.webmention-token")"
fi
```

The token is read from a gitignored `.webmention-token` file in the project root. This solves the same Nova environment inheritance problem for secrets — the token cannot be in `config.sh` because that file is committed to Git, and it cannot be relied upon from a shell profile export for the same GUI-launch reason.

### build.sh and build-drafts.sh

`build.sh` calls `ruby build.rb "$@"`, passing through any arguments from Nova's task configuration. `build-drafts.sh` calls `ruby build.rb --drafts`, explicitly. The `set -e` at the top of each script causes the script to exit immediately if any command fails — Nova displays a failure indicator in its UI when a task script exits non-zero.

### watch.sh

`watch.sh` uses `fswatch`, a macOS file system event monitor:

```bash
fswatch -o \
  "$PROJECT_DIR/_posts" \
  "$PROJECT_DIR/_drafts" \
  ...
  "$PROJECT_DIR/css" \
  "$PROJECT_DIR/javascript" \
  | while read -r count; do
      ruby build.rb --drafts && echo "  ✓ Done" || echo "  ✗ Build failed"
    done
```

`fswatch -o` outputs a count of changed events (as a number) to stdout each time one or more files change in any of the watched directories. The pipe to `while read -r count` reads each output line — each line represents a batch of changes — and triggers a rebuild. The `&&` / `||` conditional chains report success or failure without aborting the watch loop (if `set -e` were in effect inside the while loop, a build failure would kill the watcher).

### new-post.sh and new-note.sh

Both scripts use `osascript` to present a macOS dialog for user input:

```bash
TITLE=$(osascript -e '
  tell application "Nova"
    activate
  end tell
  set result to text returned of (display dialog "New post title:" ...)
' 2>/dev/null) || exit 0
```

`osascript -e '...'` runs an AppleScript expression and captures its output. The `|| exit 0` after the command substitution exits cleanly if the user presses Cancel — AppleScript raises an error on Cancel, which causes the subshell to exit non-zero, triggering the `||` branch. `exit 0` is used (not `exit 1`) so that Nova does not show the task as failed when the user simply cancelled.

The slug is derived from the title using a pipeline of `tr` and `sed` commands:

```bash
SLUG=$(echo "$TITLE" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9 ]//g' \
  | sed 's/  */ /g' \
  | sed 's/ /-/g' \
  | sed 's/^-//;s/-$//')
```

`tr '[:upper:]' '[:lower:]'` lowercases the entire string. The first `sed` strips any character that is not a letter, digit, or space. The second collapses multiple consecutive spaces to one. The third replaces spaces with hyphens. The fourth removes any leading or trailing hyphens that might result from a title starting or ending with punctuation.

The front matter is written with a heredoc:

```bash
cat > "$FILE" << FRONTMATTER
---
title: $TITLE
slug: $SLUG
date: $TODAY
description:
topics:
categories:
...
---

FRONTMATTER
```

`<< FRONTMATTER` is a **here-document** — it feeds all text until the matching `FRONTMATTER` delimiter to `cat` as stdin. Variables inside the heredoc are expanded because the delimiter is unquoted (quoting the delimiter, e.g. `<< 'FRONTMATTER'`, would suppress expansion). The `cat > "$FILE"` redirects the output to the new file.

### promote-note.sh

This script moves a note from `_notes/` to `_posts/`, scaffolding in the post-specific front matter fields that notes don't carry. The file list is presented as a macOS `choose from list` dialog:

```bash
shopt -s nullglob
NOTE_FILES=("$NOTES_DIR"/*.md)
shopt -u nullglob
```

`shopt -s nullglob` sets the shell option that makes glob patterns expand to nothing (rather than being returned literally) when no files match. Without it, if `_notes/` were empty, `NOTE_FILES` would contain the literal string `"$NOTES_DIR/*.md"` as its one element. The option is unset immediately after with `shopt -u nullglob` to avoid affecting subsequent glob operations.

The missing post fields are added without re-parsing the YAML, using `awk`:

```bash
ADD=""
grep -q '^description:' "$DEST" || ADD="${ADD}description: \n"
grep -q '^topics:'      "$DEST" || ADD="${ADD}topics: \n"
...

if [ -n "$ADD" ]; then
  awk -v add="$ADD" '
    NR==1 && /^---$/ { print; printf "%s", add; next }
    { print }
  ' "$DEST" > "$DEST.tmp" && mv "$DEST.tmp" "$DEST"
fi
```

Each `grep -q` silently checks for the presence of a field. The `||` operator means: if grep finds nothing (exit 1), append the field name to `ADD`. The `awk` script then inserts all missing fields immediately after the opening `---` delimiter — `NR==1` matches only the first line, ensuring the fields appear at the top of the front matter block rather than somewhere in the body. Writing to a `.tmp` file and then `mv`-ing it is the standard safe-write pattern — it prevents a half-written file if the process is interrupted.

The script also prefers `git mv` over plain `mv` when the file is tracked:

```bash
if git ls-files --error-unmatch "_notes/$CHOSEN" >/dev/null 2>&1; then
  git mv "_notes/$CHOSEN" "_posts/$CHOSEN"
else
  mv "$SRC" "$DEST"
fi
```

`git ls-files --error-unmatch` exits non-zero if the file is not tracked. Using `git mv` rather than `mv` preserves the file's Git history through the rename, so `git log --follow` on the post file shows its entire history including when it was a note.

### deploy.sh

The local deploy script does five things in sequence: build, index (Pagefind), rsync, send webmentions, check live CSP. The post-deploy CSP check is a useful sanity guard:

```bash
CSP=$(curl -sI "https://williampickup.org/" | grep -i "content-security-policy")
if echo "$CSP" | grep -q "wasm-unsafe-eval"; then
  echo "  ✓ CSP contains wasm-unsafe-eval"
else
  echo "  ⚠ WARNING: CSP missing wasm-unsafe-eval — search may not work"
fi
```

Pagefind's search UI requires `wasm-unsafe-eval` in the Content Security Policy because it uses WebAssembly. The CSP is set server-side (on the Vultr host, not in the static files), so a server misconfiguration would not be caught by the build. This check catches it immediately after deploy.

---

## GitHub Actions Deployment Pipeline

The `deploy.yml` workflow mirrors the local `deploy.sh` script but runs on GitHub's infrastructure. It is triggered only by `workflow_dispatch` — a manual button in the GitHub Actions UI — rather than on every push. This is deliberate: the site is a personal publication and deploys should be intentional acts, not automatic consequences of saving a file.

```yaml
on:
  workflow_dispatch: {}

permissions:
  contents: write
```

`permissions: contents: write` is required because the workflow commits the updated webmention state back to the repository at the end. Without this, the default read-only permissions would cause the final git push to fail.

### Step by step

**Checkout and Ruby setup:**

```yaml
- uses: actions/checkout@v4
- uses: ruby/setup-ruby@v1
  with:
    ruby-version: '3.3'
    bundler-cache: true
```

`bundler-cache: true` caches the installed gems between workflow runs using GitHub's action cache. On subsequent runs, the gems are restored from cache rather than downloaded and compiled, making the step near-instant.

**Build:**

```yaml
- name: Build site
  run: bundle exec ruby build.rb
```

`bundle exec` runs the command within the Bundler context — it ensures the exact gem versions specified in `Gemfile.lock` are used, not whatever happens to be installed globally on the runner. This is the primary guarantee of build reproducibility between local and CI environments.

**Pagefind index:**

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '20'
- run: npx --yes pagefind --site _out
```

Node is required solely to run Pagefind via `npx`. The `--yes` flag suppresses the prompt npx shows when downloading a package for the first time. The index is generated inside `_out/pagefind/` and becomes part of what rsync transfers to the server.

**SSH key setup:**

```yaml
- run: |
    mkdir -p ~/.ssh
    echo "${{ secrets.DEPLOY_SSH_KEY }}" > ~/.ssh/deploy_key
    chmod 600 ~/.ssh/deploy_key
    ssh-keyscan -H "${{ secrets.DEPLOY_HOST }}" >> ~/.ssh/known_hosts
```

The deploy key is a private SSH key stored as a GitHub Actions secret. `chmod 600` is required — SSH refuses to use a key file that is world-readable. `ssh-keyscan` adds the server's host key to `known_hosts` before the first connection, which prevents the interactive "Are you sure you want to continue connecting?" prompt that would otherwise stall the job. The `-H` flag hashes the hostname in the output, which is a minor security measure.

**rsync:**

```yaml
rsync -avz --delete \
  --omit-dir-times \
  --no-perms \
  -e "ssh -i ~/.ssh/deploy_key -o StrictHostKeyChecking=yes" \
  --exclude '.DS_Store' \
  --exclude 'drafts/' \
  _out/ "${{ secrets.DEPLOY_USER }}@${{ secrets.DEPLOY_HOST }}:${{ secrets.DEPLOY_PATH }}"
```

Key flags:
- `-a` (archive): preserves timestamps, symlinks, and recursive directory structure
- `-v` (verbose): logs each transferred file
- `-z` (compress): compresses data in transit, useful for text-heavy HTML
- `--delete`: removes files on the server that no longer exist in `_out/`, keeping the live site in exact sync with the build output
- `--omit-dir-times`: does not try to preserve directory modification times; many web server setups don't permit this and it would cause rsync errors
- `--no-perms`: does not try to preserve file permissions; again, the server user may not have permission to `chmod` the files
- `StrictHostKeyChecking=yes`: refuses to connect if the host key doesn't match `known_hosts`; protects against a man-in-the-middle during deploy
- `--exclude 'drafts/'`: belt-and-braces exclusion — the build only writes draft files when `--drafts` is passed (which CI never does), but this ensures that even if `_out/drafts/` somehow existed, it would not be transferred to the live server

**Webmention sending:**

```yaml
- name: Send webmentions for new outbound links
  env:
    WEBMENTION_TOKEN: ${{ secrets.WEBMENTION_TOKEN }}
  run: bundle exec ruby send_webmentions.rb
```

The token is injected via environment variable from a GitHub Actions secret rather than being stored in any file. `bundle exec` is used for the same reproducibility reason as the build step.

**Committing updated state:**

```yaml
- run: |
    if ! git diff --quiet -- _data/webmentions_sent.json; then
      git config user.name "github-actions[bot]"
      git config user.email "github-actions[bot]@users.noreply.github.com"
      git add _data/webmentions_sent.json
      git commit -m "Update webmention state [skip ci]"
      git push
    fi
```

`git diff --quiet` exits 0 if there are no changes and 1 if there are. The `if !` inverts this, so the block only runs when the state file was actually modified (i.e., webmentions were sent). Committing an unchanged file would create a spurious empty commit.

`[skip ci]` in the commit message is a convention recognised by GitHub Actions: it prevents the push from triggering a new workflow run. Without it, this commit would trigger another deploy, which would trigger another commit, and so on indefinitely.

`git config user.name "github-actions[bot]"` sets the commit author for this one run. GitHub Actions runners have no global Git identity configured, so the identity must be set before any commit. The `github-actions[bot]` email is the conventional identity for bot commits on GitHub and causes the commit to be attributed to the Actions bot user in the repository history.

---

## CSS Architecture

`site.css` is a single file of roughly 2 700 lines. It is structured in a consistent layered order: font declarations, design tokens, reset and base styles, layout primitives, component styles, and theme overrides. The layering is not enforced by tooling — it is maintained by convention.

### Design tokens

All visual values that might need to change together — colours, spacing, typography, animation curves — are defined as CSS custom properties on `:root`:

```css
:root {
  --warm-white:   #f0ede8;
  --warm-black:   #1c1916;
  --clay:         #c07a4a;

  --bg:           var(--warm-black);
  --ink:          var(--warm-white);
  --accent:       var(--clay);

  --border:       color-mix(in srgb, var(--ink) 10%, transparent);
  --surface-raised: color-mix(in srgb, var(--ink) 6%, var(--bg));

  --font-display: 'Cormorant Garamond', 'Georgia', serif;
  --font-body:    'Jost', system-ui, sans-serif;

  --gutter:  clamp(1.25rem, 4vw, 3rem);
  --gap:     clamp(0.75rem, 2vw, 1.5rem);
  --max-w:   1360px;
  --ease-out: cubic-bezier(0.22, 1, 0.36, 1);
}
```

The palette is split into two layers. The **raw palette** (`--warm-white`, `--warm-black`, `--clay`, etc.) names the actual colour values. The **semantic tokens** (`--bg`, `--ink`, `--accent`, etc.) map roles onto palette values. All component rules reference only the semantic layer — no component uses `--warm-black` directly; it uses `--ink`. This separation is what makes theme switching possible: changing the theme means only redefining the semantic tokens, not editing every component rule.

### color-mix()

```css
--border:         color-mix(in srgb, var(--ink) 10%, transparent);
--border-mid:     color-mix(in srgb, var(--ink) 18%, transparent);
--surface-raised: color-mix(in srgb, var(--ink) 6%, var(--bg));
```

`color-mix()` is a CSS function that blends two colours in a specified colour space. `color-mix(in srgb, var(--ink) 10%, transparent)` produces a version of `--ink` at 10% opacity, expressed as a fully-resolved colour value rather than using `rgba()` or an `opacity` property. This matters for several reasons:

- It works with any underlying colour, including CSS custom properties that themselves reference other properties. `rgba(var(--ink), 0.1)` would not work because `rgba()` expects individual R, G, B numbers, not a colour value.
- It participates in cascade inheritance normally, unlike `opacity`, which affects the entire element including its children.
- Because the percentage is relative to `--ink` (whatever colour that resolves to in the current theme), the border colour automatically adjusts for both dark and light themes without being explicitly redefined. A 10% ink border is visually light in both themes.

`color-mix(in srgb, var(--ink) 6%, var(--bg))` produces a colour that is 6% ink blended into the background — a very subtle surface lift used for raised elements like labels and badges. This is more robust than a fixed colour because the raised surface always sits in the correct relationship to the background regardless of which theme is active.

### clamp() for fluid spacing

```css
--gutter: clamp(1.25rem, 4vw, 3rem);
--gap:    clamp(0.75rem, 2vw, 1.5rem);
```

`clamp(min, preferred, max)` returns the `preferred` value when it falls between `min` and `max`, otherwise clamping to the boundary. `clamp(1.25rem, 4vw, 3rem)` means: use 4% of the viewport width as the gutter, but never less than 1.25rem (tight on small screens) and never more than 3rem (generous on wide screens). This replaces a set of media query breakpoints with a single continuously-responsive value.

Similar patterns appear for post-specific spacing:

```css
--post-gutter: clamp(var(--gutter), 8vw, 6rem);
```

This creates a wider gutter specifically for post pages, relative to the base gutter token, again without breakpoints.

### Theme switching

The site defaults to dark. The light theme activates through two separate mechanisms, and both must be handled:

```css
/* Mechanism 1 — system preference, no explicit user override */
@media (prefers-color-scheme: light) {
  :root:not([data-theme="dark"]) {
    --warm-white:   #f5f3ee;
    --warm-gray:    #3d3a37;
    --bg:           var(--warm-white);
    --ink:          var(--warm-black);
    --accent:       var(--clay);
    /* ... */
  }
}

/* Mechanism 2 — user explicitly selected light */
html[data-theme="light"] {
  --warm-white:   #f5f3ee;
  --warm-gray:    #3d3a37;
  --bg:           var(--warm-white);
  --ink:          var(--warm-black);
  /* ... */
}

/* Mechanism 3 — user explicitly selected dark (overrides system light preference) */
html[data-theme="dark"] {
  --warm-white:   #f0ede8;
  --bg:           var(--warm-black);
  --ink:          var(--warm-white);
  /* ... */
}
```

The `:root:not([data-theme="dark"])` selector in the media query is the key detail. Without the `:not()`, a user whose system is set to light mode could not override to dark — the media query would always override their explicit `data-theme="dark"` selection. The `:not([data-theme="dark"])` clause exempts the element from the media query rule when the user has explicitly chosen dark, allowing the `html[data-theme="dark"]` rule to win instead.

The logic in full:

| System preference | `data-theme` attribute | Result |
|---|---|---|
| dark | not set | `:root` dark defaults — dark |
| light | not set | `@media (prefers-color-scheme: light) :root:not([dark])` — light |
| dark | `"light"` | `html[data-theme="light"]` — light |
| light | `"dark"` | `html[data-theme="dark"]` (`:not([dark])` excludes media query) — dark |
| either | `"dark"` | `html[data-theme="dark"]` — dark |

`data-theme` is set on `<html>` by `main.js`, which reads from `localStorage` on page load. The toggle button in `_header.html.erb` triggers the JavaScript that cycles the attribute and persists the choice.

The theme toggle icon is handled purely in CSS:

```css
/* Default (dark theme): show moon icon */
.theme-toggle .icon-sun  { display: none; }
.theme-toggle .icon-moon { display: block; }

/* Light theme: show sun icon */
html[data-theme="light"] .theme-toggle .icon-sun  { display: none; }
html[data-theme="light"] .theme-toggle .icon-moon { display: block; }

@media (prefers-color-scheme: light) {
  :root:not([data-theme="dark"]) .theme-toggle .icon-sun  { display: none; }
  :root:not([data-theme="dark"]) .theme-toggle .icon-moon { display: block; }
}
```

The icon that is shown is the one the user would switch *to*, not the one currently active — so the light theme shows the moon (click to go dark) and the dark theme shows the sun (click to go light).

### Category colour palette

Six topic categories each have a named colour:

```css
--sage:         #7ab68a;  /* books-ideas */
--slate-blue:   #5e9cb8;  /* places-experiences */
--violet-muted: #a48fd0;  /* learning-making */
--ochre:        #c4a84a;  /* simple-living */
--dusty-rose:   #cc7a9e;  /* health-wellbeing */
```

These are applied via the `cat--{topic-id}` class the builder adds to each post card and post article:

```css
.cat--books-ideas        { --cat-color: var(--sage); }
.cat--places-experiences { --cat-color: var(--slate-blue); }
.cat--learning-making    { --cat-color: var(--violet-muted); }
.cat--simple-living      { --cat-color: var(--ochre); }
.cat--health-wellbeing   { --cat-color: var(--dusty-rose); }
```

Setting `--cat-color` as a local custom property on the element means any descendant can reference it — the post card's category label, the accent bar on the post header, or any other element that wants to be coloured by the post's topic. The colour palettes for dark and light themes are different sets of values (lighter, more saturated values for dark backgrounds; darker, less saturated for light), and both are defined in the respective theme blocks.

### Self-hosted fonts

All typefaces are served from `/fonts/` rather than a CDN:

```css
@font-face {
  font-family: 'Cormorant Garamond';
  font-style:  normal;
  font-weight: 400;
  font-display: swap;
  src: url('../fonts/cormorant-garamond-v21-latin-regular.woff2') format('woff2');
}
```

`font-display: swap` instructs the browser to render text immediately in the fallback font (`Georgia` for the display face, `system-ui` for the body face) and swap to the web font when it finishes loading. This prevents invisible text during font load (FOIT — Flash of Invisible Text) at the cost of a brief layout shift (FOUT — Flash of Unstyled Text), which is the accepted trade-off for readability.

Only `woff2` format is declared. `woff2` has near-universal browser support in any context where CSS custom properties and `color-mix()` also work, so the older `woff` fallback format is unnecessary.

