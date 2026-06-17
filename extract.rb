#!/usr/bin/env ruby
# extract.rb — one-time migration: Tinderbox .tbx → _posts/*.md
#
# Usage:
#   ruby extract.rb [path/to/file.tbx]
#
# Reads each mmdPost / mdPost item from the Tinderbox XML.
# Body comes from the linked external .md file (stripping old front matter),
# falling back to the inline <text> content if no file is set.
# Writes YAML front matter + body to ssg/_posts/SLUG.md.

require 'nokogiri'
require 'date'
require 'fileutils'
require 'yaml'

TBX_PATH  = ARGV[0] || File.expand_path(
  '~/Documents/Personal/Web-Development/williampickup.org/tinderbox-blog/wp-blog-tb-2026.tbx'
)
OUT_DIR   = File.join(__dir__, '_posts')
BLOG_POSTS_DIR = File.expand_path(
  '~/Documents/Personal/Web-Development/williampickup.org/blog-posts'
)

POST_PROTOS = %w[mmdPost mdPost].freeze

# Tinderbox XML entities aren't always decoded by Nokogiri's text() — do it manually.
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

# Parse a Tinderbox date string to a Ruby Date (drop time/tz for front matter).
def parse_date(str)
  return nil if str.nil? || str.empty? || str == 'never'
  DateTime.parse(str).to_date
rescue ArgumentError
  nil
end

# Split a semicolon-delimited Tinderbox list into a Ruby array, removing blanks.
def split_list(str)
  return [] if str.nil? || str.strip.empty?
  str.split(';').map(&:strip).reject(&:empty?)
end

# Read body from external .md file, stripping old YAML front matter.
def body_from_file(file_attr)
  return nil if file_attr.nil? || file_attr.strip.empty?

  path = file_attr.gsub(/^~/, Dir.home)

  # Try the path as-is, then look for any file matching the basename in BLOG_POSTS_DIR
  candidates = [
    path,
    File.join(BLOG_POSTS_DIR, File.basename(path))
  ]

  found = candidates.find { |p| File.exist?(p) }
  unless found
    warn "  [warn] external file not found: #{file_attr}"
    return nil
  end

  raw = File.read(found, encoding: 'utf-8')

  # Strip YAML front matter (--- ... ---) if present
  if raw.start_with?('---')
    raw = raw.sub(/\A---\s*\n.*?\n---\s*\n/m, '')
  end

  raw.strip
end

# Extract the inline <text> content from a Nokogiri item node.
def inline_text(item_node)
  text_node = item_node.at_xpath('text')
  return '' unless text_node
  decode(text_node.text).strip
end

# Build a YAML front matter hash from an item's <attribute> children.
def build_frontmatter(attrs)
  fm = {}

  fm['title']             = attrs['PostTitle']         if attrs['PostTitle']&.present?
  fm['slug']              = attrs['Slug']               if attrs['Slug']&.present?
  fm['date']              = parse_date(attrs['BlogPublishDate'])
  fm['description']       = attrs['excerpt']            if attrs['excerpt']&.present?
  fm['lede']              = attrs['postLede']           if attrs['postLede']&.present?

  categories = split_list(attrs['Categories'])
  fm['categories']        = categories                  unless categories.empty?

  tags = split_list(attrs['tags'] || attrs['Tags'])
  fm['tags']              = tags                        unless tags.empty?

  topics = split_list(attrs['topics'])
  fm['topics']            = topics                      unless topics.empty?

  fm['image_url']         = attrs['FeaturedImageURL']   if attrs['FeaturedImageURL']&.present?
  fm['image_focal_point'] = attrs['ImageFocalPoint']    if attrs['ImageFocalPoint']&.present?
  fm['use_featured_image'] = (attrs['UseFeaturedImage'] == 'true') if attrs.key?('UseFeaturedImage')

  fm['layout']            = attrs['LayoutStyle']        if attrs['LayoutStyle']&.present?
  fm['accent']            = attrs['LayoutAccent']       if attrs['LayoutAccent']&.present?
  fm['has_sidenotes']     = (attrs['HasSidenotes'] == 'true') if attrs.key?('HasSidenotes')

  fm['featured']          = (attrs['HomePageEntryPointPost'] == 'true') if attrs['HomePageEntryPointPost'] == 'true'
  fm['series']            = attrs['series']             if attrs['series']&.present?

  related = split_list(attrs['relatedPosts'])
  fm['related_posts']     = related                     unless related.empty?

  fm['draft']             = false  # published unless you set otherwise

  fm.compact
end

class String
  def present?
    !strip.empty?
  end
end

# ── Main ──────────────────────────────────────────────────────────────────────

puts "Reading #{TBX_PATH} ..."
doc = Nokogiri::XML(File.read(TBX_PATH, encoding: 'utf-8')) do |config|
  config.noblanks
end

items = doc.xpath('//item[@proto]').select { |n| POST_PROTOS.include?(n['proto']) }
puts "Found #{items.count} post items (mmdPost / mdPost)"

FileUtils.mkdir_p(OUT_DIR)

written = 0
skipped = 0

items.each do |item|
  # Collect all <attribute> children into a hash
  attrs = {}
  item.xpath('attribute').each do |a|
    attrs[a['name']] = decode(a.text)
  end

  slug = attrs['Slug'] || attrs['HTMLExportFileName']
  unless slug&.present?
    warn "  [skip] no slug on item #{item['ID']}"
    skipped += 1
    next
  end

  # Prefer inline Tinderbox <text>; fall back to external file
  body = inline_text(item)
  body = body_from_file(attrs['File']) if body.empty?

  if body.empty?
    warn "  [warn] empty body for #{slug}"
  end

  fm = build_frontmatter(attrs)

  # Ensure date exists — fall back to name-based date if missing
  if fm['date'].nil?
    name = attrs['Name'] || ''
    if (m = name.match(/^(\d{4}-\d{2}-\d{2})/))
      fm['date'] = Date.parse(m[1])
    end
  end

  out_path = File.join(OUT_DIR, "#{slug}.md")

  File.open(out_path, 'w', encoding: 'utf-8') do |f|
    f.puts '---'
    f.puts fm.to_yaml.sub(/\A---\n/, '')  # YAML adds its own --- header; sub it out
    f.puts '---'
    f.puts
    f.puts body
  end

  puts "  wrote #{slug}.md"
  written += 1
end

puts "\nDone. #{written} posts written, #{skipped} skipped."
puts "Output: #{OUT_DIR}"
