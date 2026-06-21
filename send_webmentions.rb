#!/usr/bin/env ruby
# send_webmentions.rb — send webmentions for outbound links in published posts
#
# Usage:
#   WEBMENTION_TOKEN=xxx ruby send_webmentions.rb            # send new ones
#   ruby send_webmentions.rb --seed                          # see header below
#
# Uses Telegraph (https://telegraph.p3k.io) to discover each target's
# webmention endpoint and send on our behalf — we only need to know which
# URLs we linked to, not how to discover/POST to arbitrary endpoints
# ourselves. Get a token by signing in at telegraph.p3k.io with your domain.
#
# Tracks what's already been settled (sent, or definitively rejected by
# Telegraph) in _data/webmentions_sent.json, committed to the repo since
# it's shared state between local deploys and CI — both need to agree on
# what's already gone out or risk duplicate sends. Saved incrementally,
# after every single target, so an interrupted run never loses progress
# (this bit us once already — the previous version only saved once at the
# very end, so killing it mid-run meant the next run would resend
# everything it had already sent).
#
# --seed marks every current post/target pair as already-settled without
# sending anything — no network calls at all. Use this once when adopting
# webmention sending on a site with an existing backlog of old posts:
# without it, the very first run treats the *entire* back-catalogue as new
# and fires off webmentions for years-old posts all at once, which isn't
# really what the protocol is for and looks like spam to whoever's on the
# other end. After seeding, only posts/links that didn't exist at seed time
# will ever trigger a real send.

require_relative 'build'
require 'net/http'
require 'json'
require 'uri'

STATE_FILE = File.join(__dir__, '_data', 'webmentions_sent.json')
TOKEN      = ENV['WEBMENTION_TOKEN']
SEED_MODE  = ARGV.include?('--seed')

# Telegraph error codes that mean "don't bother retrying this target" —
# distinct from a network blip or an unexpected response, which should
# still be retried on the next run.
SETTLED_ERRORS = %w[not_supported invalid_parameter no_link_found source_not_html].freeze

EXCLUDED_HOSTS = [
  URI(SITE_URL).host,
  'media.publit.io', # image host — never has a webmention endpoint
].freeze

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

def extract_targets(html)
  html.scan(/href="(https?:\/\/[^"]+)"/).flatten.uniq.select do |url|
    host = URI(url).host
    host && !EXCLUDED_HOSTS.include?(host)
  rescue URI::InvalidURIError
    false
  end
end

def send_webmention(source, target)
  uri = URI('https://telegraph.p3k.io/webmention')
  res = Net::HTTP.post_form(uri, 'token' => TOKEN, 'source' => source, 'target' => target)
  body = begin
    JSON.parse(res.body)
  rescue JSON::ParserError, TypeError
    {}
  end
  [res.code.to_i, body]
rescue StandardError => e
  [nil, { 'error' => e.message }]
end

state = load_state

if SEED_MODE
  load_posts.each do |post|
    targets = extract_targets(post.content_html)
    next if targets.empty?
    state[post.slug] = (state[post.slug] || []) | targets
    save_state(state)
  end
  puts "Seeded #{state.values.flatten.length} existing post/target pairs as already-settled."
  puts "State saved to #{STATE_FILE.sub(__dir__ + '/', '')} — commit it."
  exit 0
end

if TOKEN.nil? || TOKEN.empty?
  warn 'WEBMENTION_TOKEN not set — skipping webmention sending.'
  exit 0
end

sent_count = 0
err_count  = 0

load_posts.each do |post|
  targets      = extract_targets(post.content_html)
  already_done = state[post.slug] || []
  new_targets  = targets - already_done

  next if new_targets.empty?

  state[post.slug] ||= []

  new_targets.each do |target|
    code, body = send_webmention(post.url, target)

    if [200, 201].include?(code)
      puts "  ✓ #{post.slug} → #{target} (#{body['status']})"
      state[post.slug] << target
      sent_count += 1
    elsif SETTLED_ERRORS.include?(body['error'])
      puts "  ✗ #{post.slug} → #{target} (#{body['error']}, won't retry)"
      state[post.slug] << target
      err_count += 1
    else
      puts "  ✗ #{post.slug} → #{target} (#{body['error'] || 'unknown error'}, will retry)"
      err_count += 1
    end

    # Saved after every single target, not just at the end — an
    # interrupted run must never lose track of what already went out.
    save_state(state)
  end
end

puts "\n#{sent_count} webmention(s) sent, #{err_count} error(s)."
puts "State saved to #{STATE_FILE.sub(__dir__ + '/', '')} — remember to commit it." if sent_count > 0 || err_count > 0
