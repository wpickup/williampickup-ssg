#!/usr/bin/env ruby
# send_webmentions.rb — send webmentions for outbound links in published posts
#
# Usage: WEBMENTION_TOKEN=xxx ruby send_webmentions.rb
#
# Uses Telegraph (https://telegraph.p3k.io) to discover each target's
# webmention endpoint and send on our behalf — we only need to know which
# URLs we linked to, not how to discover/POST to arbitrary endpoints
# ourselves. Get a token by signing in at telegraph.p3k.io with your domain.
#
# Tracks what's already been sent in _data/webmentions_sent.json (committed
# to the repo, not gitignored) so re-running this on every deploy doesn't
# re-send the same webmention for unchanged posts — only new outbound links
# trigger a send. That file is shared state between local deploys and CI,
# so it needs to be committed after this script updates it.

require_relative 'build'
require 'net/http'
require 'json'
require 'uri'

STATE_FILE = File.join(__dir__, '_data', 'webmentions_sent.json')
TOKEN      = ENV['WEBMENTION_TOKEN']

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
end

if TOKEN.nil? || TOKEN.empty?
  warn 'WEBMENTION_TOKEN not set — skipping webmention sending.'
  exit 0
end

state      = load_state
sent_count = 0
err_count  = 0

load_posts.each do |post|
  targets       = extract_targets(post.content_html)
  already_sent  = state[post.slug] || []
  new_targets   = targets - already_sent

  next if new_targets.empty?

  state[post.slug] ||= []

  new_targets.each do |target|
    code, body = send_webmention(post.url, target)
    if [200, 201].include?(code)
      puts "  ✓ #{post.slug} → #{target} (#{body['status']})"
      state[post.slug] << target
      sent_count += 1
    else
      puts "  ✗ #{post.slug} → #{target} (#{body['error'] || code})"
      err_count += 1
    end
  end
end

save_state(state)
puts "\n#{sent_count} webmention(s) sent, #{err_count} error(s)."
puts "State saved to #{STATE_FILE.sub(__dir__ + '/', '')} — remember to commit it." if sent_count > 0
