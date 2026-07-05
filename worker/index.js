// wp-feed-proxy — Cloudflare Worker
//
// Fetches an RSS/Atom feed server-side and returns just the latest entry
// (title, url, date) as JSON. Exists because most blogs' RSS feeds don't
// send CORS headers, so the blogroll page's client-side enrichment
// (javascript/blogroll.js) can't fetch them directly from the browser.
//
// Deployed at https://wp-feed-proxy.williampickup.workers.dev/

const CACHE_TTL = 2 * 60 * 60; // 2 hours
const ALLOWED_ORIGIN = 'https://williampickup.org';
const USER_AGENT = 'WilliampickupFeedbot/1.0 (+https://williampickup.org)';

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }
    if (request.method !== 'GET') {
      return jsonResponse({ error: 'method_not_allowed' }, 405, request);
    }

    const { searchParams } = new URL(request.url);
    const feedUrl = searchParams.get('url');
    if (!feedUrl) {
      return jsonResponse({ error: 'missing_url' }, 400, request);
    }

    try {
      const parsed = new URL(feedUrl);
      if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
        throw new Error('bad protocol');
      }
    } catch {
      return jsonResponse({ error: 'invalid_url' }, 400, request);
    }

    const cache = caches.default;
    const cacheKey = new Request(`https://feedproxy.internal/v1/${encodeURIComponent(feedUrl)}`);
    const cached = await cache.match(cacheKey);
    if (cached) {
      const body = await cached.json();
      return jsonResponse(body, 200, request);
    }

    let feedText;
    try {
      const res = await fetch(feedUrl, {
        headers: {
          'User-Agent': USER_AGENT,
          'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
        },
        cf: { cacheTtl: CACHE_TTL, cacheEverything: false },
      });
      if (!res.ok) throw new Error(`upstream HTTP ${res.status}`);
      feedText = await res.text();
    } catch (err) {
      return jsonResponse({ error: 'fetch_failed', detail: err.message }, 502, request);
    }

    const result = parseFeed(feedText);
    if (!result) {
      return jsonResponse({ error: 'parse_failed' }, 422, request);
    }

    const cacheValue = new Response(JSON.stringify(result), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': `public, max-age=${CACHE_TTL}`,
      },
    });
    ctx.waitUntil(cache.put(cacheKey, cacheValue));

    return jsonResponse(result, 200, request);
  },
};

function parseFeed(xml) {
  const isAtom = /<feed[^>]+xmlns/.test(xml) || xml.includes('<entry>') || xml.includes('<entry ');
  return isAtom ? parseAtom(xml) : parseRss(xml);
}

function text(xml, tag) {
  const re = new RegExp(
    `<${tag}[^>]*><!\\[CDATA\\[([\\s\\S]*?)\\]\\]><\\/${tag}>|<${tag}[^>]*>([\\s\\S]*?)<\\/${tag}>`,
    'i'
  );
  const m = xml.match(re);
  if (!m) return null;
  return decode((m[1] ?? m[2] ?? '').trim());
}

function linkHref(xml) {
  const alt = xml.match(/<link[^>]+rel=["']alternate["'][^>]+href=["']([^"']+)["']/i)?.[1];
  if (alt) return alt.trim();
  const any = xml.match(/<link[^>]+href=["']([^"']+)["']/i)?.[1];
  return any?.trim() ?? null;
}

function parseRss(xml) {
  const m = xml.match(/<item[\s>]([\s\S]*?)<\/item>/i);
  if (!m) return null;
  const item = m[1];
  const title = text(item, 'title');
  const link = text(item, 'link') ?? linkHref(item);
  const date = text(item, 'pubDate') ?? text(item, 'dc:date') ?? text(item, 'published');
  if (!title || !link) return null;
  return { title, url: link, date: date ?? null };
}

function parseAtom(xml) {
  const m = xml.match(/<entry[\s>]([\s\S]*?)<\/entry>/i);
  if (!m) return null;
  const entry = m[1];
  const title = text(entry, 'title');
  const link = linkHref(entry) ?? text(entry, 'link');
  const date = text(entry, 'updated') ?? text(entry, 'published');
  if (!title || !link) return null;
  return { title, url: link, date: date ?? null };
}

function decode(str) {
  return str
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)))
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCharCode(parseInt(h, 16)));
}

function corsHeaders(request) {
  const origin = request.headers.get('Origin') ?? '';
  const allowed = origin === ALLOWED_ORIGIN || origin.startsWith('http://localhost');
  return {
    'Access-Control-Allow-Origin': allowed ? origin : ALLOWED_ORIGIN,
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin',
  };
}

function jsonResponse(body, status, request) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': status === 200 ? `public, max-age=${CACHE_TTL}` : 'no-store',
      ...corsHeaders(request),
    },
  });
}
