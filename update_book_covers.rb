#!/usr/bin/env ruby
# update_book_covers.rb — normalises assets/books/<slug>.jpg for every book,
# so the site never hotlinks a third-party CDN for covers. For each book:
#
#   1. If assets/books/<slug>.* already exists (e.g. you AirDropped/saved a
#      phone photo of the cover straight in there), resize it down to a
#      sane display size and convert it to <slug>.jpg — safe to re-run any
#      time, e.g. after replacing the photo with a better one; resizing an
#      already-small image is a harmless no-op.
#   2. Otherwise, fall back to cover_url / isbn (via OpenLibrary), fetched
#      over the network. Skipped if <slug>.jpg already exists, so re-runs
#      don't hammer a third party — delete the file to force a re-fetch.
#
# Not part of the regular build — build.rb never touches the network.

require_relative 'build'
require 'net/http'
require 'uri'
require 'fileutils'

COVERS_DIR = File.join(SRC_DIR, 'assets', 'books')
MAX_WIDTH  = 360 # covers display at ≤180px (≤7rem on mobile); this covers 2x retina
MIN_BYTES  = 1000 # OpenLibrary returns an ~800-byte 1x1 placeholder GIF when it has no cover

FileUtils.mkdir_p(COVERS_DIR)

def resize_into(src_path, dest_path)
  system('magick', src_path, '-auto-orient', '-resize', "#{MAX_WIDTH}x#{MAX_WIDTH}>", '-quality', '85', dest_path) &&
    File.exist?(dest_path)
end

def download(url)
  uri = URI.parse(url)
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 10, read_timeout: 15) do |http|
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'williampickup.org cover fetcher (will@williampickup.org)'
    response = http.request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    body = response.body
    return nil if body.nil? || body.bytesize < MIN_BYTES

    body
  end
rescue StandardError => e
  warn "  error: #{url} → #{e.message}"
  nil
end

books = load_books
puts "Checking covers for #{books.length} books…"

books.each do |book|
  dest    = File.join(COVERS_DIR, "#{book.slug}.jpg")
  present = Dir[File.join(COVERS_DIR, "#{book.slug}.*")]
  local   = present.find { |p| p != dest } # a raw photo dropped in under any other extension

  if local
    tmp = "#{dest}.tmp"
    if resize_into(local, tmp)
      FileUtils.mv(tmp, dest)
      FileUtils.rm_f(local) # drop the raw original once we have the normalised .jpg
      puts "  ↻ #{book.slug} (from #{File.basename(local)})"
    else
      FileUtils.rm_f(tmp)
      puts "  ✗ #{book.slug} — found #{File.basename(local)} but ImageMagick couldn't process it"
    end
    next
  end

  if present.include?(dest)
    puts "  = #{book.slug} (already have a cover)"
    next
  end

  source = book.source_cover_url
  unless source
    puts "  · #{book.slug} — no photo, cover_url, or isbn — nothing to do"
    next
  end

  body = download(source)
  unless body
    puts "  ✗ #{book.slug} — couldn't fetch #{source}"
    next
  end

  tmp = File.join(COVERS_DIR, "#{book.slug}.download")
  File.binwrite(tmp, body)
  ok = resize_into(tmp, dest)
  FileUtils.rm_f(tmp)

  if ok
    puts "  ↓ #{book.slug} (from #{URI.parse(source).host})"
  else
    puts "  ✗ #{book.slug} — downloaded but ImageMagick resize failed"
  end
end

puts "Done."
