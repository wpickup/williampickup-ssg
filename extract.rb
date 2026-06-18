#!/usr/bin/env ruby
# extract.rb — migrate Tinderbox .tbx → markdown source files
#
# Usage:
#   ruby extract.rb [path/to/file.tbx]
#
# Extracts:
#   mmdPost / mdPost  → _posts/SLUG.md
#   photo             → _photos/SLUG.md
#   book              → _books/SLUG.md
#   now child notes   → _data/now.yml

require 'nokogiri'
require 'date'
require 'fileutils'
require 'yaml'

TBX_PATH = ARGV[0] || File.expand_path(
  '~/Documents/Personal/Web-Development/williampickup.org/tinderbox-blog/wp-blog-tb-2026.tbx'
)
BLOG_POSTS_DIR = File.expand_path(
  '~/Documents/Personal/Web-Development/williampickup.org/blog-posts'
)

POST_PROTOS  = %w[mmdPost mdPost].freeze
DRAFT_PROTOS = %w[draftPost].freeze
NOTE_PROTOS  = %w[mdNote].freeze

# ── Core extensions ───────────────────────────────────────────────────────────

class String
  def present?  = !strip.empty?
  def presence  = present? ? self : nil
end

class Array
  def presence  = empty? ? nil : self
end

class NilClass
  def presence  = nil
  def present?  = false
end

def decode(str)
  return '' if str.nil?
  str
    .gsub('&amp;',  '&')
    .gsub('&apos;', "'")
    .gsub('&lt;',   '<')
    .gsub('&gt;',   '>')
    .gsub('&quot;', '"')
    .strip
end

def parse_date(str)
  return nil if str.nil? || str.empty? || str == 'never'
  DateTime.parse(str).to_date
rescue ArgumentError
  nil
end

def split_list(str)
  return [] if str.nil? || str.strip.empty?
  str.split(';').map(&:strip).reject(&:empty?)
end

def inline_text(item_node)
  text_node = item_node.at_xpath('text')
  return '' unless text_node
  decode(text_node.text).strip
end

def collect_attrs(item)
  attrs = {}
  item.xpath('attribute').each { |a| attrs[a['name']] = decode(a.text) }
  attrs
end

def body_from_file(file_attr)
  return nil if file_attr.nil? || file_attr.strip.empty?
  path = file_attr.gsub(/^~/, Dir.home)
  candidates = [path, File.join(BLOG_POSTS_DIR, File.basename(path))]
  found = candidates.find { |p| File.exist?(p) }
  unless found
    warn "  [warn] external file not found: #{file_attr}"
    return nil
  end
  raw = File.read(found, encoding: 'utf-8')
  raw = raw.sub(/\A---\s*\n.*?\n---\s*\n/m, '') if raw.start_with?('---')
  raw.strip
end

def write_md(dir, slug, fm, body)
  FileUtils.mkdir_p(dir)
  File.open(File.join(dir, "#{slug}.md"), 'w', encoding: 'utf-8') do |f|
    f.puts '---'
    f.puts fm.compact.to_yaml.sub(/\A---\n/, '')
    f.puts '---'
    f.puts
    f.puts body unless body.empty?
  end
end

# ── Post extraction ───────────────────────────────────────────────────────────

def extract_posts(doc)
  dir     = File.join(__dir__, '_posts')
  written = 0
  skipped = 0

  items = doc.xpath('//item[@proto]').select { |n| (POST_PROTOS + DRAFT_PROTOS).include?(n['proto']) }
  puts "Found #{items.count} post items"

  items.each do |item|
    attrs = collect_attrs(item)
    slug  = attrs['Slug'] || attrs['HTMLExportFileName']
    unless slug&.present?
      warn "  [skip] no slug on item #{item['ID']}"
      skipped += 1
      next
    end

    body = inline_text(item)
    body = body_from_file(attrs['File']) || '' if body.empty?

    fm = {
      'title'             => attrs['PostTitle'],
      'slug'              => slug,
      'date'              => parse_date(attrs['BlogPublishDate']),
      'description'       => attrs['excerpt'].presence,
      'lede'              => attrs['postLede'].presence,
      'categories'        => split_list(attrs['Categories']).presence,
      'tags'              => split_list(attrs['tags'] || attrs['Tags']).presence,
      'topics'            => split_list(attrs['topics']).presence,
      'image_url'         => attrs['FeaturedImageURL'].presence,
      'image_focal_point' => attrs['ImageFocalPoint'].presence,
      'use_featured_image'=> (attrs['UseFeaturedImage'] == 'true') || nil,
      'layout'            => attrs['LayoutStyle'].presence,
      'accent'            => attrs['LayoutAccent'].presence,
      'has_sidenotes'     => (attrs['HasSidenotes'] == 'true') || nil,
      'featured'          => (attrs['HomePageEntryPointPost'] == 'true') || nil,
      'series'            => attrs['series'].presence,
      'related_posts'     => split_list(attrs['relatedPosts']).presence,
      'draft'             => DRAFT_PROTOS.include?(item['proto']) || nil,
    }

    if fm['date'].nil?
      if (m = (attrs['Name'] || '').match(/^(\d{4}-\d{2}-\d{2})/))
        fm['date'] = Date.parse(m[1])
      end
    end

    write_md(dir, slug, fm, body)
    puts "  post: #{slug}.md"
    written += 1
  end

  puts "  #{written} posts written, #{skipped} skipped"
end

# ── Photo extraction ──────────────────────────────────────────────────────────

def extract_photos(doc)
  dir   = File.join(__dir__, '_photos')
  count = 0

  doc.xpath('//item[@proto="photo"]').each do |item|
    attrs = collect_attrs(item)
    slug  = attrs['HTMLExportFileName'] || attrs['Name']
    next unless slug&.present?

    photo_date = parse_date(attrs['photoDate'])

    fm = {
      'title'        => attrs['photoTitle'].presence || slug,
      'slug'         => slug,
      'date'         => photo_date,
      'image_url'    => attrs['image'].presence,
      'image_alt'    => attrs['imageAlt'].presence,
      'image_size'   => attrs['imageSize'].presence,
      'focal_point'  => attrs['ImageFocalPoint'].presence,
      'location'     => attrs['location'].presence,
      'camera'       => attrs['camera'].presence,
      'caption'      => attrs['Caption'].presence,
      'series'       => attrs['series'].presence,
      'featured'     => (attrs['featuredphoto'] == 'true') || nil,
      'tags'         => split_list(attrs['tags']).presence,
    }

    write_md(dir, slug, fm, inline_text(item))
    puts "  photo: #{slug}.md"
    count += 1
  end

  puts "  #{count} photos written"
end

# ── Book extraction ───────────────────────────────────────────────────────────

def extract_books(doc)
  dir   = File.join(__dir__, '_books')
  count = 0

  doc.xpath('//item[@proto="book"]').each do |item|
    attrs = collect_attrs(item)
    slug  = attrs['HTMLExportFileName'] || attrs['Name']&.downcase&.gsub(/[^a-z0-9]+/, '-')
    next unless slug&.present?

    fm = {
      'title'       => (attrs['BookTitle'] || attrs['Name']).presence,
      'slug'        => slug,
      'author'      => attrs['BookAuthor'].presence,
      'status'      => attrs['BookStatus'].presence,
      'date_read'   => parse_date(attrs['DateRead']),
      'isbn'        => attrs['ISBN'].presence,
      'cover_url'   => attrs['BookCover'].presence,
      'on_now_page' => (attrs['OnNowPage'] == 'true') || nil,
    }

    write_md(dir, slug, fm, inline_text(item))
    puts "  book: #{slug}.md"
    count += 1
  end

  puts "  #{count} books written"
end

# ── Notes extraction ─────────────────────────────────────────────────────────

def extract_notes(doc)
  dir     = File.join(__dir__, '_notes')
  written = 0

  doc.xpath('//item[@proto]').select { |n| NOTE_PROTOS.include?(n['proto']) }.each do |item|
    attrs = collect_attrs(item)
    name  = attrs['Name'] || item['name'] || ''
    slug  = (attrs['Slug'] || attrs['HTMLExportFileName'] || name)
              .downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
    next if slug.empty?

    body = inline_text(item)

    fm = {
      'title' => attrs['NoteTitle'].presence || attrs['PostTitle'].presence,
      'slug'  => slug,
      'date'  => parse_date(attrs['BlogPublishDate']) || parse_date(attrs['CreationDate']),
      'draft' => (attrs['Status'] == 'draft') || nil,
    }

    write_md(dir, slug, fm, body)
    puts "  note: #{slug}.md"
    written += 1
  end

  puts "  #{written} notes written"
end

# ── Now page extraction ───────────────────────────────────────────────────────

NOW_SECTION_NAMES = %w[Making Travelling Growing Thinking-about].freeze

def extract_now(doc)
  FileUtils.mkdir_p(File.join(__dir__, '_data'))

  now_node = doc.xpath('//item[@name="now" or attribute[@name="HTMLExportFileName" and text()="now"]]').first
  unless now_node
    # Find by HTMLExportFileName attribute
    now_node = doc.xpath('//item[attribute[@name="HTMLExportFileName"][text()="now"]]').first
  end

  unless now_node
    warn "  [warn] now page node not found"
    return
  end

  updated_str = now_node.xpath('attribute[@name="NowUpdated"]').first&.text
  updated     = parse_date(decode(updated_str.to_s))

  sections = {}
  now_node.xpath('item').each do |child|
    name = decode(child.xpath('attribute[@name="Name"]').first&.text.to_s)
    next unless NOW_SECTION_NAMES.include?(name)
    text = inline_text(child)
    sections[name.downcase.gsub('-', '_')] = text unless text.empty?
  end

  # Books with $OnNowPage=true — just flag them, build.rb will pull from _books/
  data = { 'updated' => updated&.to_s, 'sections' => sections }

  File.write(
    File.join(__dir__, '_data', 'now.yml'),
    data.to_yaml,
    encoding: 'utf-8'
  )
  puts "  now: _data/now.yml written (#{sections.keys.join(', ')})"
end

# ── Main ──────────────────────────────────────────────────────────────────────

puts "Reading #{TBX_PATH} ..."
doc = Nokogiri::XML(File.read(TBX_PATH, encoding: 'utf-8')) { |c| c.noblanks }

puts "\n── Posts ──"
extract_posts(doc)

puts "\n── Photos ──"
extract_photos(doc)

puts "\n── Books ──"
extract_books(doc)

puts "\n── Notes ──"
extract_notes(doc)

puts "\n── Now page ──"
extract_now(doc)

puts "\nDone."
