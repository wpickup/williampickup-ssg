#!/usr/bin/env ruby
# build.rb — static site builder for williampickup.org
#
# Usage:
#   ruby build.rb            # build to _out/
#   ruby build.rb --watch    # rebuild on file changes (requires 'listen' gem)

require 'erb'
require 'date'
require 'fileutils'
require 'yaml'
require 'kramdown'
require 'cgi'

# ── Configuration ─────────────────────────────────────────────────────────────

SITE_URL      = 'https://williampickup.org'
SITE_TITLE    = 'William Pickup'
SITE_DESC     = 'A personal notebook of making, reading, travelling, photography, and simpler ways of living.'
AUTHOR_NAME   = 'William Pickup'
AUTHOR_EMAIL  = 'will@williampickup.org'
COPYRIGHT_YEAR = Date.today.year

SRC_DIR       = __dir__
OUT_DIR       = File.join(__dir__, '_out')
POSTS_DIR     = File.join(__dir__, '_posts')
PAGES_DIR     = File.join(__dir__, '_pages')
TEMPLATES_DIR = File.join(__dir__, '_templates')
PARTIALS_DIR  = File.join(__dir__, '_partials')
STATIC_DIRS   = %w[css javascript fonts].map { |d| File.join(File.dirname(__dir__), d) }
STATIC_FILES  = %w[favicon.svg].map { |f| File.join(File.dirname(__dir__), f) }

TOPIC_LABELS = {
  'books-ideas'        => 'Books and Ideas',
  'learning-making'    => 'Learning and Making',
  'places-experiences' => 'Places and Experiences',
  'simple-living'      => 'Simple Living',
  'health-wellbeing'   => 'Health and Wellbeing',
}.freeze

# publit.io CDN — inject width param into URL
def publit_srcset(url, focal_point = nil)
  return '' if url.nil? || url.empty?
  widths = [400, 700, 1050, 1400]
  style  = focal_point ? " style=\"object-position: #{focal_point}\"" : ''
  srcset = widths.map { |w| "#{publit_width(url, w)} #{w}w" }.join(",\n                    ")
  { src: publit_width(url, 1050), srcset: srcset, style: style }
end

def publit_width(url, w)
  # Insert /w_{n}/ after the domain segment
  url.sub(%r{(publit\.io/file/)}, "\\1w_#{w}/")
end

def reading_time(text)
  words = text.gsub(/<[^>]+>/, '').split.length
  mins  = [(words / 200.0).ceil, 1].max
  "#{mins} min read"
end

# ── Post model ────────────────────────────────────────────────────────────────

class Post
  attr_reader :slug, :title, :date, :description, :lede,
              :categories, :tags, :topics,
              :image_url, :image_focal_point, :use_featured_image,
              :layout, :accent, :has_sidenotes, :featured,
              :series, :related_posts, :draft,
              :content_md, :content_html, :path

  def initialize(path)
    @path = path
    raw   = File.read(path, encoding: 'utf-8')

    # Split front matter from body
    if raw =~ /\A---\s*\n(.*?)\n---\s*\n(.*)\z/m
      fm           = YAML.safe_load($1, permitted_classes: [Date, Time]) || {}
      @content_md  = $2.strip
    else
      fm           = {}
      @content_md  = raw.strip
    end

    @slug               = fm['slug']  || File.basename(path, '.md')
    @title              = fm['title'] || @slug
    @date               = fm['date'].is_a?(Date) ? fm['date'] : (Date.parse(fm['date'].to_s) rescue nil)
    @description        = fm['description']
    @lede               = fm['lede']
    @categories         = Array(fm['categories'])
    @tags               = Array(fm['tags'])
    @topics             = Array(fm['topics'])
    @image_url          = fm['image_url']
    @image_focal_point  = fm['image_focal_point']
    @use_featured_image = fm['use_featured_image'] == true
    @layout             = fm['layout'] || 'standard'
    @accent             = fm['accent']
    @has_sidenotes      = fm['has_sidenotes'] == true
    @featured           = fm['featured'] == true
    @series             = fm['series']
    @related_posts      = Array(fm['related_posts'])
    @draft              = fm['draft'] != false  # draft unless explicitly false

    @content_html = Kramdown::Document.new(
      @content_md,
      input: :kramdown,
      smart_quotes: 'lsquo,rsquo,ldquo,rdquo',
      hard_wrap: false
    ).to_html
  end

  def url
    "#{SITE_URL}/posts/#{slug}.html"
  end

  def primary_topic
    topics.first
  end

  def topic_label(topic_id = primary_topic)
    TOPIC_LABELS[topic_id] || topic_id
  end

  def date_display
    date&.strftime('%-d %B %Y') || ''
  end

  def date_iso
    date&.iso8601 || ''
  end

  def year
    date&.year
  end

  def reading_time
    words = content_html.gsub(/<[^>]+>/, '').split.length
    mins  = [(words / 200.0).ceil, 1].max
    "#{mins} min read"
  end

  def css_classes
    classes = ['h-entry']
    classes << "cat--#{primary_topic}" if primary_topic
    classes << 'has-sidenotes' if has_sidenotes
    classes << "layout--#{layout}" if layout && layout != 'standard'
    classes.join(' ')
  end
end

# ── Template rendering ────────────────────────────────────────────────────────

class Renderer
  def initialize(posts, all_posts_sorted)
    @all_posts  = all_posts_sorted
    @posts      = posts
  end

  def render(template_name, locals = {})
    template_path = File.join(TEMPLATES_DIR, "#{template_name}.html.erb")
    template      = ERB.new(File.read(template_path), trim_mode: '-')
    b = binding
    locals.each { |k, v| b.local_variable_set(k, v) }
    # Make helpers available
    b.local_variable_set(:renderer, self)
    template.result(b)
  end

  def partial(name, locals = {})
    partial_path = File.join(PARTIALS_DIR, "_#{name}.html.erb")
    template     = ERB.new(File.read(partial_path), trim_mode: '-')
    b = binding
    locals.each { |k, v| b.local_variable_set(k, v) }
    b.local_variable_set(:renderer, self)
    template.result(b)
  end

  def h(str)
    CGI.escapeHTML(str.to_s)
  end

  def publit_srcset(url, focal_point = nil)
    return nil if url.nil? || url.empty?
    widths = [400, 700, 1050, 1400]
    style  = focal_point ? %( style="object-position: #{focal_point}") : ''
    srcset = widths.map { |w| "#{publit_width(url, w)} #{w}w" }.join(",\n                    ")
    { src: publit_width(url, 1050), srcset: srcset, style: style }
  end

  def publit_width(url, w)
    url.sub(%r{(publit\.io/file/)}, "\\1w_#{w}/")
  end

  def topic_label(id)
    TOPIC_LABELS[id] || id.to_s.gsub('-', ' ').split.map(&:capitalize).join(' ')
  end

  def all_posts
    @all_posts
  end
end

# ── Build pipeline ────────────────────────────────────────────────────────────

def load_posts
  Dir[File.join(POSTS_DIR, '*.md')]
    .map  { |p| Post.new(p) rescue (warn "Error loading #{p}: #{$!}"; nil) }
    .compact
    .reject(&:draft)
    .sort_by { |p| p.date || Date.new(1970) }
    .reverse
end

def write(path, content)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, content, encoding: 'utf-8')
  puts "  #{path.sub(OUT_DIR + '/', '')}"
end

def build
  puts "Building site → #{OUT_DIR}"
  FileUtils.mkdir_p(OUT_DIR)

  posts = load_posts
  puts "Loaded #{posts.length} posts"

  renderer = Renderer.new(posts, posts)

  # ── Posts ──────────────────────────────────────────────────────────────────
  puts "\nPosts:"
  posts.each_with_index do |post, i|
    prev_post = posts[i + 1]
    next_post = i > 0 ? posts[i - 1] : nil

    html = renderer.render('post', post: post, prev_post: prev_post, next_post: next_post, root: '../')
    write(File.join(OUT_DIR, 'posts', "#{post.slug}.html"), html)
  end

  # ── Blog index ─────────────────────────────────────────────────────────────
  puts "\nIndex pages:"
  html = renderer.render('blog', posts: posts, root: '')
  write(File.join(OUT_DIR, 'blog.html'), html)

  # ── Home ───────────────────────────────────────────────────────────────────
  recent_posts  = posts.first(6)
  featured_posts = posts.select(&:featured).first(6)
  html = renderer.render('home', posts: recent_posts, featured_posts: featured_posts, root: '')
  write(File.join(OUT_DIR, 'index.html'), html)

  # ── Archive (all years) ────────────────────────────────────────────────────
  years = posts.map(&:year).compact.uniq.sort.reverse
  html = renderer.render('archive', years: years, posts: posts, root: '')
  write(File.join(OUT_DIR, 'archive.html'), html)

  # ── Archive (per year) ─────────────────────────────────────────────────────
  years.each do |year|
    year_posts = posts.select { |p| p.year == year }
    html = renderer.render('archive_year', year: year, posts: year_posts, root: '../')
    write(File.join(OUT_DIR, 'archive', "#{year}.html"), html)
  end

  # ── Topics ─────────────────────────────────────────────────────────────────
  topic_groups = Hash.new { |h, k| h[k] = [] }
  posts.each { |p| p.topics.each { |t| topic_groups[t] << p } }

  topic_groups.each do |topic_id, topic_posts|
    label = TOPIC_LABELS[topic_id] || topic_id
    html  = renderer.render('topic', topic_id: topic_id, topic_label: label,
                            posts: topic_posts, root: '../')
    write(File.join(OUT_DIR, 'topics', "#{topic_id}.html"), html)
  end

  # ── Categories ─────────────────────────────────────────────────────────────
  cat_groups = Hash.new { |h, k| h[k] = [] }
  posts.each { |p| p.categories.each { |c| cat_groups[c] << p } }

  cat_groups.each do |cat, cat_posts|
    slug = cat.downcase.gsub(/[^a-z0-9]+/, '-')
    html = renderer.render('category', category: cat, posts: cat_posts, root: '../')
    write(File.join(OUT_DIR, 'categories', "#{cat}.html"), html)
  end

  # ── Feeds ──────────────────────────────────────────────────────────────────
  puts "\nFeeds:"
  feed_posts = posts.first(20)
  rss  = renderer.render('feed_rss',  posts: feed_posts)
  atom = renderer.render('feed_atom', posts: feed_posts)
  write(File.join(OUT_DIR, 'Feeds', 'rss.xml'),  rss)
  write(File.join(OUT_DIR, 'Feeds', 'atom.xml'), atom)

  # ── Static assets ──────────────────────────────────────────────────────────
  puts "\nAssets:"
  STATIC_DIRS.each do |src|
    next unless Dir.exist?(src)
    dst = File.join(OUT_DIR, File.basename(src))
    FileUtils.cp_r(src, dst)
    puts "  #{File.basename(src)}/"
  end
  STATIC_FILES.each do |src|
    next unless File.exist?(src)
    FileUtils.cp(src, File.join(OUT_DIR, File.basename(src)))
    puts "  #{File.basename(src)}"
  end

  puts "\nDone. #{posts.length} posts, #{years.length} archive years, #{topic_groups.length} topics, #{cat_groups.length} categories."
end

build
