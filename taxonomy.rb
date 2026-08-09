#!/usr/bin/env ruby
# taxonomy.rb — cheatsheet of categories/tags/topics already in use across
# _posts and _drafts, so new posts can reuse an existing value instead of
# accidentally creating a near-duplicate (e.g. "Photography" vs "photography").
#
# Regenerate with the "Taxonomy Cheatsheet" Nova task, or directly:
#   ruby taxonomy.rb
#
# Writes taxonomy.md (gitignored — it's derived from _posts/_drafts, not a
# source of truth) and opens it in Nova.

require 'yaml'
require 'date'

ROOT       = __dir__
POSTS_DIR  = File.join(ROOT, '_posts')
DRAFTS_DIR = File.join(ROOT, '_drafts')
OUT_FILE   = File.join(ROOT, 'taxonomy.md')

# Same frontmatter parsing as build.rb's parse_frontmatter, kept in sync by
# hand since this script intentionally doesn't require build.rb (which runs
# a full site build as a side effect of loading).
def parse_frontmatter(path)
  raw = File.read(path, encoding: 'utf-8')
  if raw =~ /\A---\s*\n(.*?)\n---\s*\n(.*)\z/m
    YAML.safe_load($1, permitted_classes: [Date, Time]) || {}
  else
    {}
  end
end

# Topics are a closed vocabulary defined in build.rb's TOPIC_LABELS, not
# freely invented per-post — pulled from source rather than duplicated here
# so it can't drift out of sync. build.rb itself isn't require'd (it runs
# the whole build as a side effect of loading); just its constant is lifted.
def topic_labels
  src = File.read(File.join(ROOT, 'build.rb'), encoding: 'utf-8')
  src =~ /^TOPIC_LABELS = (\{.*?\})\.freeze/m
  eval($1) # rubocop:disable Security/Eval -- trusted local file, not user input
end

def tally(field)
  counts = Hash.new(0)
  paths = Dir.glob(File.join(POSTS_DIR, '*.md')) + Dir.glob(File.join(DRAFTS_DIR, '*.md'))
  paths.each do |path|
    fm = parse_frontmatter(path)
    Array(fm[field]).reject { |v| v.nil? || v.to_s.strip.empty? }.each { |v| counts[v] += 1 }
  end
  counts
end

def render_counts(counts)
  return "_none yet_\n" if counts.empty?

  counts.sort_by { |value, count| [-count, value.to_s.downcase] }
        .map { |value, count| "- #{value} (#{count})" }
        .join("\n") + "\n"
end

# Values that only differ by case are the exact "Photography" vs
# "photography" problem this file exists to catch — surface them up top.
def case_collisions(counts)
  counts.keys
        .group_by { |v| v.to_s.downcase }
        .select { |_, variants| variants.uniq.length > 1 }
end

def render_collisions(field, counts)
  collisions = case_collisions(counts)
  return '' if collisions.empty?

  lines = collisions.map { |_, variants| "- #{variants.map { |v| "\"#{v}\" (#{counts[v]})" }.join(' vs ')}" }
  "\n⚠ **Possible #{field} duplicates (case only):**\n#{lines.join("\n")}\n"
end

categories = tally('categories')
tags       = tally('tags')

timestamp = Time.now.strftime('%-d %b %Y, %H:%M')

File.write(OUT_FILE, <<~MD)
  # Taxonomy cheatsheet

  _Regenerated #{timestamp} from _posts/ and _drafts/ — run the "Taxonomy Cheatsheet" Nova task to refresh. This file is derived, not a source of truth; don't hand-edit it._

  ## Topics (closed set — pick one of these six, don't invent new ones)

  #{topic_labels.map { |id, label| "- #{id} — #{label}" }.join("\n")}

  ## Categories (#{categories.size} in use)
  #{render_collisions('category', categories)}
  #{render_counts(categories)}

  ## Tags (#{tags.size} in use)
  #{render_collisions('tag', tags)}
  #{render_counts(tags)}
MD

puts "Wrote #{OUT_FILE}"
puts "  #{topic_labels.size} topics · #{categories.size} categories · #{tags.size} tags"
