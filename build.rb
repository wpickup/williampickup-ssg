#!/usr/bin/env ruby
# build.rb — static site builder for williampickup.org

require 'erb'
require 'date'
require 'fileutils'
require 'yaml'
require 'kramdown'
require 'cgi'

# ── Configuration ─────────────────────────────────────────────────────────────

SITE_URL       = 'https://williampickup.org'
SITE_TITLE     = 'William Pickup'
SITE_DESC      = 'A personal notebook of making, reading, travelling, photography, and simpler ways of living.'
AUTHOR_NAME    = 'William Pickup'
AUTHOR_EMAIL   = 'will@williampickup.org'
COPYRIGHT_YEAR = Date.today.year

# UTC, not system local time — local builds (Sydney) and CI builds
# (GitHub Actions runners) would otherwise show different times for the
# same moment. The git SHA pins this to an exact, verifiable commit
# (intentionally not linked in the footer — the repo is private, so a
# link to GitHub would 404 for every visitor except the owner).
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

def md_to_html(text)
  return '' if text.nil? || text.empty?
  text = text.gsub(/~~(.+?)~~/m, '<del>\1</del>')
  text = text.gsub(/==(.+?)==/m, '<mark>\1</mark>')
  Kramdown::Document.new(text, input: :kramdown, smart_quotes: 'lsquo,rsquo,ldquo,rdquo', hard_wrap: false).to_html
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

end

class Page
  attr_reader :slug, :title, :description, :template, :draft, :content_html, :path

  def initialize(path)
    @path = path
    fm, body = parse_frontmatter(path)

    @slug         = fm['slug']     || File.basename(path, '.md')
    @title        = fm['title']    || @slug
    @description  = fm['description']
    @template     = fm['template'] || 'page'
    @draft        = fm['draft'] == true
    @content_html = md_to_html(body)
  end

  def url = "#{SITE_URL}/#{slug}.html"
end

# ── Renderer ──────────────────────────────────────────────────────────────────

class Renderer
  def initialize(all_posts, nav_data = {})
    @all_posts = all_posts
    @nav_data  = nav_data
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
  pages    = load_pages
  now_data      = load_now_data
  blogroll_data = load_blogroll_data
  nav_data      = load_nav_data

  puts "Loaded: #{posts.length} posts, #{notes.length} notes, #{photos.length} photos, #{books.length} books, #{pages.length} pages"

  r = Renderer.new(posts, nav_data)

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

  # Home
  featured_posts = posts.select(&:featured).first(6)
  hero_photo     = photos.find(&:featured)
  recent_notes   = notes.first(4)
  write(File.join(OUT_DIR, 'index.html'),
    r.render('home', posts: posts.first(6), featured_posts: featured_posts,
             recent_notes: recent_notes,
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
