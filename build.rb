#!/usr/bin/env ruby
# build.rb — static site builder for williampickup.org

require 'erb'
require 'date'
require 'fileutils'
require 'yaml'
require 'kramdown'
require 'cgi'
require 'json'

# ── Configuration ─────────────────────────────────────────────────────────────

SITE_URL       = 'https://williampickup.org'
SITE_TITLE     = 'William Pickup'
SITE_DESC      = 'A personal notebook of making, reading, travelling, photography, and simpler ways of living.'
AUTHOR_NAME    = 'William Pickup'
AUTHOR_EMAIL   = 'will@williampickup.org'
COPYRIGHT_YEAR = Date.today.year

# Fallback image for pages that don't set their own og:image (posts and books
# usually do). Used so every page gets a social-preview image instead of a
# blank card when shared. Swap for a dedicated banner/logo asset if you'd
# rather not use the bio portrait here.
DEFAULT_OG_IMAGE = "#{SITE_URL}/assets/WP-at-Stromlo.webp"

# Theme colours for <meta name="theme-color">, matching css/site.css's
# --bg token for each mode (html[data-theme="light"] / ["dark"]).
THEME_COLOR_LIGHT = '#f5f3ee'
THEME_COLOR_DARK  = '#1c1916'

# ListenBrainz username for the home page "listening to" widget. Leave blank
# until Apple Music is scrobbling there — the widget silently no-ops without it.
LISTENBRAINZ_USER = 'Wpickup'

# Public source repo — the footer links BUILD_SHA to its commit page here.
REPO_URL = 'https://github.com/wpickup/williampickup-ssg'

# UTC, not system local time — local builds (Sydney) and CI builds
# (GitHub Actions runners) would otherwise show different times for the
# same moment. The git SHA pins this to an exact, verifiable commit. (A
# local build of an unpushed commit links to a commit GitHub doesn't have
# yet — harmless, since only CI builds are ever published.)
BUILD_STAMP = Time.now.utc.strftime("%-d %b '%y, %H:%M UTC")
BUILD_SHA   = begin
  sha = `git rev-parse --short HEAD 2>/dev/null`.strip
  sha.empty? ? nil : sha
rescue StandardError
  nil
end

SRC_DIR       = __dir__
# Defaults to repo/_out — overridable so local runs can write straight to a
# real local-server docroot (e.g. ~/Sites/williampickup.org) without CI
# (which has no such path) needing to know about it.
OUT_DIR       = ENV['SSG_OUT_DIR'] || File.join(__dir__, '_out')
POSTS_DIR     = File.join(__dir__, '_posts')
DRAFTS_DIR    = File.join(__dir__, '_drafts')
NOTES_DIR     = File.join(__dir__, '_notes')
PHOTOS_DIR    = File.join(__dir__, '_photos')
BOOKS_DIR     = File.join(__dir__, '_books')
JOURNEYS_DIR  = File.join(__dir__, '_journeys')
PAGES_DIR     = File.join(__dir__, '_pages')
DATA_DIR      = File.join(__dir__, '_data')
TEMPLATES_DIR = File.join(__dir__, '_templates')
PARTIALS_DIR  = File.join(__dir__, '_partials')
DRAFTS        = ARGV.include?('--drafts')
STATIC_DIRS   = %w[css javascript fonts assets].map { |d| File.join(SRC_DIR, d) }

TOPIC_LABELS = {
  'books-ideas'        => 'Books and Ideas',
  'learning-making'    => 'Learning and Making',
  'places-experiences' => 'Places and Experiences',
  'simple-living'      => 'Simple Living',
  'health-wellbeing'   => 'Health and Wellbeing',
  'systems-thinking'   => 'Systems Thinking',
}.freeze

# ── Helpers ───────────────────────────────────────────────────────────────────

# A fenced code block — ``` (GFM style) or ~~~ (Kramdown's native style),
# with an optional language after the opening fence. The closing fence must
# use the same character and be at least as long as the opening one.
FENCED_CODE_RE = /^(`{3,}|~{3,})[ \t]*([\w+#.-]*)[^\n]*\n(.*?)^\1[`~]*[ \t]*$/m
INLINE_CODE_RE = /`[^`\n]+`/

def md_to_html(text)
  return '' if text.nil? || text.empty?

  # Set code aside before the ~~/== substitutions below, which would
  # otherwise rewrite code contents — and turn a ~~~ fence into <del> tags.
  # Fences are normalised to Kramdown's ~~~ syntax (it doesn't recognise
  # ``` fences), made one tilde longer than any tilde run in the code itself.
  protected_code = []
  guard = ->(code) { protected_code << code; "\u0000#{protected_code.length - 1}\u0000" }
  text = text.gsub(FENCED_CODE_RE) do
    lang, code = $2, $3
    fence = '~' * [3, (code.scan(/~+/).map(&:length).max || 0) + 1].max
    guard.call("#{fence}#{" #{lang}" unless lang.empty?}\n#{code}#{fence}")
  end
  text = text.gsub(INLINE_CODE_RE) { |code| guard.call(code) }

  text = text.gsub(/~~(.+?)~~/m, '<del>\1</del>')
  text = text.gsub(/==(.+?)==/m, '<mark>\1</mark>')
  text = text.gsub(/\u0000(\d+)\u0000/) { protected_code[$1.to_i] }

  # syntax_highlighter: nil — leave <code class="language-x"> for Prism to
  # highlight in the browser, even if Rouge happens to be installed.
  html = Kramdown::Document.new(text, input: :kramdown, smart_quotes: 'lsquo,rsquo,ldquo,rdquo',
                                      hard_wrap: false, syntax_highlighter: nil).to_html
  apply_smallcaps(html)
end

# True when rendered HTML contains a language-tagged code block, so pages
# can load Prism only where it's needed.
def has_code_blocks?(html) = html.to_s.include?('<code class="language-')

# Wraps runs of 2+ uppercase letters (acronyms, initialisms, all-caps titles
# like "ROUGH TYPE") in a span so they can be rendered as small caps instead
# of full-height capitals, which draw the eye more than the surrounding text.
# Operates only on text nodes — skips tag attributes (untouched, since we
# only match text between '>' and '<') and <pre>/<code> contents (protected
# via placeholder swap, since code should show acronyms verbatim).
def apply_smallcaps(html)
  protected_blocks = []
  guarded = html.gsub(%r{<(pre|code)[^>]*>.*?</\1>}m) do |match|
    protected_blocks << match
    "\u0000#{protected_blocks.length - 1}\u0000"
  end

  wrapped = guarded.gsub(/>([^<]+)</) do
    text = $1.gsub(/\b[A-Z]{2,}\b/) { |acronym| %(<span class="acr">#{acronym}</span>) }
    ">#{text}<"
  end

  wrapped.gsub(/\u0000(\d+)\u0000/) { protected_blocks[$1.to_i] }
end

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

module Dateable
  private

  def coerce_date(val)
    return val if val.is_a?(Date)

    Date.parse(val.to_s)
  rescue ArgumentError
    nil
  end
end

# ── Models ────────────────────────────────────────────────────────────────────

class Post  
  include Dateable
  
  attr_reader :slug, :title, :date, :description, :lede,
              :categories, :tags, :topics,
              :image_url, :image_focal_point, :use_featured_image,
              :layout, :accent, :has_sidenotes, :featured,
              :series, :draft,
              :content_md, :content_html, :path

  def initialize(path, force_draft: false)
    @path        = path
    fm, @content_md = parse_frontmatter(path)

    @slug               = fm['slug']  || File.basename(path, '.md')
    @title              = fm['title'] || @slug
    @date               = coerce_date(fm['date'])
    @description        = fm['description']
    @lede               = fm['lede']
    @categories         = Array(fm['categories']).reject(&:empty?)
    @tags               = Array(fm['tags']).reject(&:empty?)
    @topics             = Array(fm['topics']).reject(&:empty?)
    @image_url          = fm['image_url']
    @image_focal_point  = fm['image_focal_point']
    @use_featured_image = fm['use_featured_image'] == true
    @layout             = fm['layout'] || 'standard'
    @accent             = fm['accent']
    @has_sidenotes      = fm['has_sidenotes'] == true
    @featured           = fm['featured'] == true
    @series             = fm['series']
    @draft              = fm['draft'] == true || force_draft
    @content_html       = md_to_html(@content_md)
  end

  def type          = 'post'
  def url_path      = "#{draft ? 'drafts' : 'posts'}/#{slug}.html"
  def url           = "#{SITE_URL}/#{url_path}"
  def primary_topic = topics.first
  def topic_label(t = primary_topic) = TOPIC_LABELS[t] || t.to_s.gsub('-', ' ').split.map(&:capitalize).join(' ')
  def date_display  = date&.strftime('%-d %B %Y') || ''
  def date_iso      = date&.iso8601 || ''
  def year          = date&.year
  def reading_time
    words = content_html.gsub(/<[^>]+>/, '').split.length
    "#{[(words / 200.0).ceil, 1].max} min read"
  end

  def css_classes
    classes = ['h-entry']
    classes << "cat--#{primary_topic}" if primary_topic
    classes << 'has-sidenotes'         if has_sidenotes
    classes << "layout--#{layout}"    if layout && layout != 'standard'
    classes.join(' ')
  end

end

class Note
  include Dateable
  
  attr_reader :slug, :title, :date, :draft, :content_html, :path

  def initialize(path)
    @path = path
    fm, body = parse_frontmatter(path)

    @slug         = fm['slug']  || File.basename(path, '.md')
    @title        = fm['title']
    @date         = coerce_date(fm['date'])
    @draft        = fm['draft'] == true
    @content_html = md_to_html(body)
  end

  def type         = 'note'
  def url_path     = "#{draft ? 'drafts' : 'notes'}/#{slug}.html"
  def url          = "#{SITE_URL}/#{url_path}"
  def date_display = date&.strftime('%-d %B %Y') || ''
  def date_iso     = date&.iso8601 || ''
  def year         = date&.year

end

class Photo
  include Dateable
  
  attr_reader :slug, :title, :date, :image_url, :image_alt, :image_size,
              :focal_point, :location, :camera, :caption, :series,
              :featured, :tags, :content_html, :path

  def initialize(path)
    @path = path
    fm, body = parse_frontmatter(path)

    @slug         = fm['slug']  || File.basename(path, '.md')
    @title        = fm['title'] || @slug
    @date         = coerce_date(fm['date'])
    @image_url    = fm['image_url']
    @image_alt    = fm['image_alt'] || ''
    @image_size   = fm['image_size'] || 'standard'
    @focal_point  = fm['focal_point']
    @location     = fm['location']
    @camera       = fm['camera']
    @caption      = fm['caption']
    @series       = fm['series']
    @featured     = fm['featured'] == true
    @tags         = Array(fm['tags'])
    @content_html = md_to_html(body)
  end

  def url      = "#{SITE_URL}/photos/#{slug}.html"
  def date_iso = date&.iso8601 || ''

end

class Book
  include Dateable
  
  attr_reader :slug, :title, :author, :status, :date_read,
              :isbn, :cover_url, :on_now_page, :content_html, :path

  def initialize(path)
    @path = path
    fm, body = parse_frontmatter(path)

    @slug        = fm['slug']  || File.basename(path, '.md')
    @title       = fm['title'] || @slug
    @author      = fm['author']
    @status      = fm['status'] || 'read'
    @date_read   = coerce_date(fm['date_read'])
    @isbn        = fm['isbn']
    @cover_url   = fm['cover_url']
    @on_now_page = fm['on_now_page'] == true
    @content_html = md_to_html(body)
  end

  def url = "#{SITE_URL}/reading/#{slug}.html"

  # Where update_book_covers.rb should download from — cover_url (a specific
  # image the owner supplied) wins, otherwise fall back to OpenLibrary's
  # cover-by-ISBN lookup. Not used at render time; see cover_src.
  def source_cover_url
    return cover_url if cover_url
    return nil unless isbn
    "https://covers.openlibrary.org/b/isbn/#{isbn}-M.jpg"
  end

  # The actual <img src> — always a self-hosted asset, never a hotlink to a
  # third-party CDN. Covers used to be hotlinked directly from cover_url /
  # OpenLibrary, which was unreliable (OpenLibrary's cover service is prone
  # to slow/failed loads, and there's no local fallback if a third-party
  # host is ever unreachable). update_book_covers.rb downloads once into
  # assets/books/; nil here just means that script hasn't been run for this
  # book yet, and the partial already handles a missing cover gracefully.
  def cover_src
    path = local_cover_path
    return nil unless path
    "#{SITE_URL}/assets/books/#{File.basename(path)}"
  end

  private

  def local_cover_path
    Dir[File.join(SRC_DIR, 'assets', 'books', "#{slug}.*")].first
  end

end

# A standalone, undated photo essay for a place or trip — deliberately NOT a
# Post: no date-driven sort order, no topics/categories/series, never in the
# blog feed or RSS. Modelled on how paulstamatiou.com/photos/* pages work —
# a living document that can be revisited and added to across multiple trips,
# rather than a dispatch published once. Draft status works like Note's (an
# in-place `draft: true` flag, not a folder), since a journey is something
# you'd expect to keep editing rather than "publish" once and move on from.
class Journey
  include Dateable

  attr_reader :slug, :title, :description, :lede,
              :image_url, :image_focal_point, :use_featured_image,
              :layout, :updated, :featured, :draft,
              :content_md, :content_html, :path

  def initialize(path)
    @path        = path
    fm, @content_md = parse_frontmatter(path)

    @slug               = fm['slug']  || File.basename(path, '.md')
    @title              = fm['title'] || @slug
    @description        = fm['description']
    @lede               = fm['lede']
    @image_url          = fm['image_url']
    @image_focal_point  = fm['image_focal_point']
    @use_featured_image = fm['use_featured_image'] == true
    @layout             = fm['layout'] || 'photo-essay'
    @updated            = coerce_date(fm['updated'])
    @featured           = fm['featured'] == true
    @draft              = fm['draft'] == true
    @content_html       = md_to_html(@content_md)
  end

  def type            = 'journey'
  def url_path        = "#{draft ? 'drafts' : 'journeys'}/#{slug}.html"
  def url             = "#{SITE_URL}/#{url_path}"
  def updated_display = updated&.strftime('%B %Y')
  def updated_iso     = updated&.iso8601 || ''

  def css_classes
    classes = ['journey-entry']
    classes << "layout--#{layout}" if layout && layout != 'standard'
    classes.join(' ')
  end
end

class Page
  attr_reader :slug, :title, :description, :template, :draft, :content_html, :path,
              :sidebar_blurb

  def initialize(path)
    @path = path
    fm, body = parse_frontmatter(path)

    @slug          = fm['slug']     || File.basename(path, '.md')
    @title         = fm['title']    || @slug
    @description   = fm['description']
    @template      = fm['template'] || 'page'
    @draft         = fm['draft'] == true
    @sidebar_blurb = fm['sidebar_blurb']
    @content_html  = md_to_html(body)
  end

  def url = "#{SITE_URL}/#{slug}.html"
end

# ── Renderer ──────────────────────────────────────────────────────────────────

class Renderer
  def initialize(all_posts, nav_data = {}, pages = [])
    @all_posts  = all_posts
    @nav_data   = nav_data
    @page_slugs = pages.map(&:slug)
  end

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

  def h(str) = CGI.escapeHTML(str.to_s)

  def publit_srcset(url, fp = nil)
    return nil if url.nil? || url.empty?
    widths = [400, 700, 1050, 1400]
    style  = fp ? %( style="object-position: #{fp}") : ''
    srcset = widths.map { |w| "#{publit_width(url, w)} #{w}w" }.join(",\n                    ")
    { src: publit_width(url, 1050), srcset: srcset, style: style }
  end

  def publit_width(url, w) = url.sub(%r{(publit\.io/file/)}, "\\1w_#{w}/")
  def topic_label(id)  = TOPIC_LABELS[id] || id.to_s.gsub('-', ' ').split.map(&:capitalize).join(' ')
  def all_posts        = @all_posts
  def nav_data         = @nav_data

  # Whether a static page is being built this run — false for a draft page
  # in a production build — so templates can avoid linking to a 404.
  def page_built?(slug) = @page_slugs.include?(slug)

  # Renders a BreadcrumbList JSON-LD <script> tag matching a page's visible
  # .breadcrumb nav. `items` is an ordered array of [name, url] pairs — pass
  # url: nil for the current page (the last item), matching how the visible
  # breadcrumb leaves its own last crumb unlinked.
  def breadcrumb_ld(items)
    entries = items.each_with_index.map do |(name, url), i|
      entry = { '@type' => 'ListItem', 'position' => i + 1, 'name' => name }
      entry['item'] = url if url
      entry
    end
    json = { '@context' => 'https://schema.org', '@type' => 'BreadcrumbList', 'itemListElement' => entries }
    %(  <script type="application/ld+json">\n  #{JSON.generate(json)}\n  </script>\n)
  end

  private

  def make_binding(locals)
    b = binding
    locals.each { |k, v| b.local_variable_set(k, v) }
    b.local_variable_set(:renderer, self)
    b
  end
end

# ── Build helpers ─────────────────────────────────────────────────────────────

def load_posts
  from_posts = Dir[File.join(POSTS_DIR, '*.md')]
    .map { |p| Post.new(p) rescue (warn "Error loading #{p}: #{$!}"; nil) }
  from_drafts = Dir.exist?(DRAFTS_DIR) ? Dir[File.join(DRAFTS_DIR, '*.md')]
    .map { |p| Post.new(p, force_draft: true) rescue (warn "Error loading #{p}: #{$!}"; nil) } : []
  (from_posts + from_drafts)
    .compact.reject { |p| p.draft && !DRAFTS }
    .sort_by { |p| p.date || Date.new(1970) }.reverse
end

def load_notes
  return [] unless Dir.exist?(NOTES_DIR)
  Dir[File.join(NOTES_DIR, '*.md')]
    .map  { |p| Note.new(p) rescue (warn "Error loading #{p}: #{$!}"; nil) }
    .compact.reject { |p| p.draft && !DRAFTS }
    .sort_by { |p| p.date || Date.new(1970) }.reverse
end

def load_photos
  return [] unless Dir.exist?(PHOTOS_DIR)
  Dir[File.join(PHOTOS_DIR, '*.md')]
    .map  { |p| Photo.new(p) rescue (warn "Error loading #{p}: #{$!}"; nil) }
    .compact
end

def load_books
  return [] unless Dir.exist?(BOOKS_DIR)
  Dir[File.join(BOOKS_DIR, '*.md')]
    .map  { |p| Book.new(p) rescue (warn "Error loading #{p}: #{$!}"; nil) }
    .compact
end

def load_journeys
  return [] unless Dir.exist?(JOURNEYS_DIR)
  Dir[File.join(JOURNEYS_DIR, '*.md')]
    .map  { |p| Journey.new(p) rescue (warn "Error loading #{p}: #{$!}"; nil) }
    .compact.reject { |j| j.draft && !DRAFTS }
end

def load_pages
  return [] unless Dir.exist?(PAGES_DIR)
  Dir[File.join(PAGES_DIR, '*.md')]
    .map  { |p| Page.new(p) rescue (warn "Error loading #{p}: #{$!}"; nil) }
    .compact.reject { |p| p.draft && !DRAFTS }
end

def load_now_data
  path = File.join(DATA_DIR, 'now.yml')
  return {} unless File.exist?(path)
  YAML.safe_load(File.read(path), permitted_classes: [Date]) || {}
end

def load_blogroll_data
  path = File.join(DATA_DIR, 'blogroll.yml')
  return {} unless File.exist?(path)
  YAML.safe_load(File.read(path)) || {}
end

def load_nav_data
  path = File.join(DATA_DIR, 'nav.yml')
  return {} unless File.exist?(path)
  YAML.safe_load(File.read(path)) || {}
end

def load_series_data
  path = File.join(DATA_DIR, 'series.yml')
  return {} unless File.exist?(path)
  YAML.safe_load(File.read(path)) || {}
end

def write(path, content)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, content, encoding: 'utf-8')
  puts "  #{path.sub(OUT_DIR + '/', '')}"
end

# ── Build ─────────────────────────────────────────────────────────────────────

def build
  puts "Building site → #{OUT_DIR}"
  FileUtils.rm_rf(OUT_DIR)
  FileUtils.mkdir_p(OUT_DIR)

  posts    = load_posts
  notes    = load_notes
  photos   = load_photos
  books    = load_books
  journeys = load_journeys
  pages    = load_pages
  now_data      = load_now_data
  blogroll_data = load_blogroll_data
  nav_data      = load_nav_data
  series_data   = load_series_data

  puts "Loaded: #{posts.length} posts, #{notes.length} notes, #{photos.length} photos, #{books.length} books, #{journeys.length} journeys, #{pages.length} pages"

  r = Renderer.new(posts, nav_data, pages)

  # ── Posts ──────────────────────────────────────────────────────────────────
  puts "\nPosts:"
  published_posts, draft_posts = posts.partition { |p| !p.draft }
  published_posts.each_with_index do |post, i|
    html = r.render('post', post: post,
                    prev_post: published_posts[i + 1], next_post: i > 0 ? published_posts[i - 1] : nil,
                    root: '../')
    write(File.join(OUT_DIR, 'posts', "#{post.slug}.html"), html)
  end
  if DRAFTS
    draft_posts.each do |post|
      html = r.render('post', post: post, prev_post: nil, next_post: nil, root: '../')
      write(File.join(OUT_DIR, 'drafts', "#{post.slug}.html"), html)
    end
  end

  # ── Notes ──────────────────────────────────────────────────────────────────
  puts "\nNotes:"
  published_notes, draft_notes = notes.partition { |n| !n.draft }
  published_notes.each do |note|
    html = r.render('note', note: note, root: '../')
    write(File.join(OUT_DIR, 'notes', "#{note.slug}.html"), html)
  end
  if DRAFTS
    draft_notes.each do |note|
      html = r.render('note', note: note, root: '../')
      write(File.join(OUT_DIR, 'drafts', "#{note.slug}.html"), html)
    end
  end

  # ── Photos ─────────────────────────────────────────────────────────────────
  puts "\nPhotos:"
  photos.each do |photo|
    html = r.render('photo', photo: photo, root: '../')
    write(File.join(OUT_DIR, 'photos', "#{photo.slug}.html"), html)
  end

  # ── Books ──────────────────────────────────────────────────────────────────
  puts "\nBooks:"
  books.each do |book|
    html = r.render('book', book: book, root: '../')
    write(File.join(OUT_DIR, 'reading', "#{book.slug}.html"), html)
  end

  # ── Journeys ───────────────────────────────────────────────────────────────
  # Draft handling mirrors Notes, not Posts: draft-ness is an in-place front
  # matter flag, so a draft journey still lands in drafts/, but there's no
  # "promote" step that moves the file — you just remove the flag.
  puts "\nJourneys:"
  published_journeys, draft_journeys = journeys.partition { |j| !j.draft }
  published_journeys.each do |journey|
    html = r.render('journey', journey: journey, root: '../')
    write(File.join(OUT_DIR, 'journeys', "#{journey.slug}.html"), html)
  end
  if DRAFTS
    draft_journeys.each do |journey|
      html = r.render('journey', journey: journey, root: '../')
      write(File.join(OUT_DIR, 'drafts', "#{journey.slug}.html"), html)
    end
  end

  # ── Index pages ────────────────────────────────────────────────────────────
  puts "\nIndex pages:"

  write(File.join(OUT_DIR, 'blog.html'),
    r.render('blog', posts: posts, root: ''))

  # Notes listing
  write(File.join(OUT_DIR, 'notes.html'),
    r.render('notes', notes: notes, root: ''))

  # Gallery index + highlights
  highlights = photos.select { |p| p.series == 'highlights' }
  write(File.join(OUT_DIR, 'gallery.html'),
    r.render('gallery', photos: photos, highlights: highlights, root: ''))
  write(File.join(OUT_DIR, 'gallery', 'highlights.html'),
    r.render('gallery_highlights', photos: highlights, root: '../'))

  # Reading page
  reading_books  = books.select { |b| b.status == 'reading' }
  read_books     = books.select { |b| b.status == 'read' }.sort_by { |b| b.date_read || Date.new(1970) }.reverse
  write(File.join(OUT_DIR, 'reading.html'),
    r.render('reading', reading_books: reading_books, read_books: read_books, root: ''))

  # Now page
  now_books = books.select(&:on_now_page)
  write(File.join(OUT_DIR, 'now.html'),
    r.render('now', now_data: now_data, now_books: now_books, root: ''))

  # Journeys index
  write(File.join(OUT_DIR, 'journeys.html'),
    r.render('journeys', journeys: journeys, root: ''))

  # Home
  featured_posts   = posts.select(&:featured).first(6)
  hero_photo       = photos.find(&:featured)
  recent_notes     = notes.first(4)
  bio_page         = pages.find { |p| p.slug == 'bio' }
  sidebar_blogroll = (blogroll_data['entries'] || []).select { |e| e['sidebar'] }
  write(File.join(OUT_DIR, 'index.html'),
    r.render('home', posts: posts.first(6), featured_posts: featured_posts,
             recent_notes: recent_notes, bio_page: bio_page, sidebar_blogroll: sidebar_blogroll,
             now_data: now_data, now_books: now_books, hero_photo: hero_photo, root: ''))

  # Archive
  years = posts.map(&:year).compact.uniq.sort.reverse
  write(File.join(OUT_DIR, 'archive.html'),
    r.render('archive', years: years, posts: posts, root: ''))
  years.each do |year|
    write(File.join(OUT_DIR, 'archive', "#{year}.html"),
      r.render('archive_year', year: year, posts: posts.select { |p| p.year == year }, root: '../'))
  end

  # Topics
  topic_groups = Hash.new { |h, k| h[k] = [] }
  posts.each { |p| p.topics.each { |t| topic_groups[t] << p } }
  topic_groups.each do |tid, tposts|
    write(File.join(OUT_DIR, 'topics', "#{tid}.html"),
      r.render('topic', topic_id: tid, topic_label: TOPIC_LABELS[tid] || tid,
               posts: tposts, root: '../'))
  end

  # Categories
  cat_groups = Hash.new { |h, k| h[k] = [] }
  posts.each { |p| p.categories.each { |c| cat_groups[c] << p } }
  cat_groups.each do |cat, cposts|
    write(File.join(OUT_DIR, 'categories', "#{cat}.html"),
      r.render('category', category: cat, posts: cposts, root: '../'))
  end

  # Series — unlike topics/categories, grouped by an explicit slug in
  # series.yml rather than a fixed hash, and posts are ordered oldest-first
  # (a series reads as a sequence of parts, not a reverse-chron feed).
  series_groups = Hash.new { |h, k| h[k] = [] }
  posts.each { |p| series_groups[p.series] << p if p.series }
  series_groups.each do |sid, sposts|
    meta = series_data[sid] || {}
    write(File.join(OUT_DIR, 'series', "#{sid}.html"),
      r.render('series', series_id: sid,
               series_title: meta['title'] || sid.tr('-', ' ').split.map(&:capitalize).join(' '),
               series_description: meta['description'],
               posts: sposts.sort_by { |p| p.date || Date.new(1970) },
               root: '../'))
  end

  # Static pages (bio, blogroll, etc.)
  pages.each do |page|
    extras = page.template == 'blogroll' ? { blogroll_data: blogroll_data } : {}
    html = r.render(page.template, { page: page, root: '' }.merge(extras))
    write(File.join(OUT_DIR, "#{page.slug}.html"), html)
  end

  # 404
  write(File.join(OUT_DIR, '404.html'), r.render('404', root: '/'))

  # ── Feeds ──────────────────────────────────────────────────────────────────
  puts "\nfeeds:"
  feed_posts = posts.first(20)
  write(File.join(OUT_DIR, 'feeds', 'rss.xml'),  r.render('feed_rss',  posts: feed_posts))
  write(File.join(OUT_DIR, 'feeds', 'atom.xml'), r.render('feed_atom', posts: feed_posts))

  # ── Sitemap + robots.txt ─────────────────────────────────────────────────────
  # .reject(&:draft) here is belt-and-braces — posts/notes already exclude
  # drafts unless --drafts was passed, but a sitemap is exactly the kind of
  # file where "exclude drafts" should never depend on remembering a flag.
  write(File.join(OUT_DIR, 'sitemap.xml'),
    r.render('sitemap', posts: posts.reject(&:draft), notes: notes.reject(&:draft),
             photos: photos, books: books, journeys: journeys.reject(&:draft), years: years,
             topic_groups: topic_groups, cat_groups: cat_groups, series_groups: series_groups, pages: pages))

  write(File.join(OUT_DIR, 'robots.txt'), <<~ROBOTS)
    User-agent: *
    Disallow: /drafts/

    # Named entries for common AI crawlers, listed explicitly rather than
    # relying only on the wildcard rule above — an intentional, visible
    # stance rather than an accident of omission. All currently Allow,
    # matching the wildcard; flip any to "Disallow: /" to opt that bot out.
    User-agent: GPTBot
    Allow: /

    User-agent: ChatGPT-User
    Allow: /

    User-agent: ClaudeBot
    Allow: /

    User-agent: anthropic-ai
    Allow: /

    User-agent: Google-Extended
    Allow: /

    User-agent: PerplexityBot
    Allow: /

    User-agent: CCBot
    Allow: /

    User-agent: Bytespider
    Allow: /

    Sitemap: #{SITE_URL}/sitemap.xml
  ROBOTS

  # ── llms.txt ─────────────────────────────────────────────────────────────
  # Per llmstxt.org — a curated, high-signal index for LLMs/agents (distinct
  # from sitemap.xml, which is exhaustive and machine-oriented). Rebuilt from
  # whatever content currently exists on every build, same as the sitemap.
  puts "\nllms.txt:"
  llms_recent = posts.reject(&:draft).first(20)
  llms_lines = []
  llms_lines << "# #{SITE_TITLE}"
  llms_lines << ''
  llms_lines << "> #{SITE_DESC}"
  llms_lines << ''
  llms_lines << "Written by #{AUTHOR_NAME} (#{SITE_URL}/bio.html). Every post, note, and page is plain HTML — no paywall, login, or JavaScript required to read the text."
  llms_lines << ''
  llms_lines << '## Recent writing'
  llms_recent.each do |post|
    desc = post.description ? ": #{post.description}" : ''
    llms_lines << "- [#{post.title}](#{post.url})#{desc}"
  end
  llms_lines << ''
  llms_lines << '## Topics'
  TOPIC_LABELS.each do |tid, label|
    llms_lines << "- [#{label}](#{SITE_URL}/topics/#{tid}.html)"
  end
  llms_lines << ''
  unless journeys.reject(&:draft).empty?
    llms_lines << '## Journeys'
    journeys.reject(&:draft).each do |journey|
      desc = journey.description || journey.lede
      llms_lines << "- [#{journey.title}](#{journey.url})#{desc ? ": #{desc}" : ''}"
    end
    llms_lines << ''
  end
  llms_lines << '## More'
  llms_lines << "- [All writing](#{SITE_URL}/blog.html)"
  llms_lines << "- [Notes](#{SITE_URL}/notes.html)"
  llms_lines << "- [Photography](#{SITE_URL}/gallery.html)"
  llms_lines << "- [Reading](#{SITE_URL}/reading.html)"
  llms_lines << "- [Journeys](#{SITE_URL}/journeys.html)"
  llms_lines << "- [About](#{SITE_URL}/bio.html)"
  llms_lines << "- [Full sitemap](#{SITE_URL}/sitemap.xml)"
  llms_lines << "- [RSS feed](#{SITE_URL}/feeds/rss.xml)"
  write(File.join(OUT_DIR, 'llms.txt'), llms_lines.join("\n") + "\n")

  # ── /.well-known/ ────────────────────────────────────────────────────────
  # RFC 9116. Expires is required by the spec — set a year out and let it
  # roll forward on its own with every rebuild after that (so it never
  # silently goes stale the way a hand-set one-off date would).
  puts "\n.well-known/:"
  security_expires = ((Date.today >> 12)).strftime('%Y-%m-%dT00:00:00.000Z')
  write(File.join(OUT_DIR, '.well-known', 'security.txt'), <<~SECURITY)
    Contact: mailto:#{AUTHOR_EMAIL}
    Expires: #{security_expires}
    Preferred-Languages: en
    Canonical: #{SITE_URL}/.well-known/security.txt
  SECURITY

  # ── manifest.json ────────────────────────────────────────────────────────
  # 'minimal-ui' keeps a thin browser chrome (address bar) rather than
  # stripping it entirely — fits a blog people still want to see the URL
  # of, while still getting an app icon/splash if added to a home screen.
  puts "\nmanifest.json:"
  manifest = {
    'name'             => SITE_TITLE,
    'short_name'       => 'William Pickup',
    'description'      => SITE_DESC,
    'start_url'        => '/',
    'scope'            => '/',
    'display'          => 'minimal-ui',
    'lang'             => 'en',
    'background_color' => THEME_COLOR_LIGHT,
    'theme_color'      => THEME_COLOR_LIGHT,
    'icons' => [
      { 'src' => '/assets/favicon.svg',            'sizes' => 'any',     'type' => 'image/svg+xml', 'purpose' => 'any' },
      { 'src' => '/assets/apple-touch-icon.png',    'sizes' => '180x180', 'type' => 'image/png',     'purpose' => 'any' },
      { 'src' => '/assets/icon-maskable-512.png',   'sizes' => '512x512', 'type' => 'image/png',     'purpose' => 'maskable' },
    ],
  }
  write(File.join(OUT_DIR, 'manifest.json'), JSON.pretty_generate(manifest) + "\n")

  # ── Static assets ──────────────────────────────────────────────────────────
  puts "\nAssets:"
  STATIC_DIRS.each do |src|
    next unless Dir.exist?(src)
    dest = File.join(OUT_DIR, File.basename(src))
    FileUtils.rm_rf(dest)
    FileUtils.cp_r(src, dest)
    puts "  #{File.basename(src)}/"
  end

  puts "\nDone. #{posts.length} posts · #{notes.length} notes · #{photos.length} photos · #{books.length} books · #{years.length} archive years · #{topic_groups.length} topics · #{cat_groups.length} categories"
end

# Guarded so other scripts can `require_relative 'build'` to reuse Post,
# load_posts, etc. without triggering a full site build as a side effect.
build if __FILE__ == $0
