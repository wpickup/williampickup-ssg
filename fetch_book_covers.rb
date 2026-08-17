#!/usr/bin/env ruby
# fetch_book_covers.rb — downloads book cover images into assets/books/ so
# the built site never hotlinks a third-party CDN (OpenLibrary, publit.io,
# etc.) for covers. Hotlinked covers were unreliable — OpenLibrary's cover
# service in particular is prone to slow or failed loads with no local
# fallback. Run manually whenever a book is added or its cover_url/isbn
# changes; output is committed to the repo like any other asset.

require_relative 'build'
require 'net/http'
require 'uri'
require 'fileutils'

COVERS_DIR  = File.join(SRC_DIR, 'assets', 'books')
MAX_WIDTH   = 360 # covers display at ≤180px (≤7rem on mobile); this covers 2x retina
MIN_BYTES   = 1000 # OpenLibrary returns an ~800-byte 1x1 placeholder GIF when it has no cover

FileUtils.mkdir_p(COVERS_DIR)

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
  existing = Dir[File.join(COVERS_DIR, "#{book.slug}.*")].first
  if existing
    puts "  = #{book.slug} (already have #{File.basename(existing)})"
    next
  end

  source = book.source_cover_url
  unless source
    puts "  · #{book.slug} — no cover_url or isbn, nothing to fetch"
    next
  end

  body = download(source)
  unless body
    puts "  ✗ #{book.slug} — couldn't fetch #{source}"
    next
  end

  tmp = File.join(COVERS_DIR, "#{book.slug}.download")
  File.binwrite(tmp, body)

  # Resize/normalise to jpg via ImageMagick so we never commit an
  # oversized source image (the publit.io cover was 1050×1400 for a
  # ≤180px display) or a format-guessing mismatch.
  dest = File.join(COVERS_DIR, "#{book.slug}.jpg")
  ok = system('magick', tmp, '-resize', "#{MAX_WIDTH}x#{MAX_WIDTH}>", '-quality', '85', dest)
  FileUtils.rm_f(tmp)

  if ok && File.exist?(dest)
    puts "  ↓ #{book.slug} (from #{URI.parse(source).host})"
  else
    puts "  ✗ #{book.slug} — downloaded but ImageMagick resize failed"
  end
end

puts "Done."
