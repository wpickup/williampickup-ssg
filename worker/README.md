# wp-feed-proxy

Cloudflare Worker that fetches an RSS/Atom feed and returns just the latest
entry as JSON (`{ title, url, date }`). Used by the blogroll page's
client-side enrichment (`../javascript/blogroll.js`) to show each blog's
most recent post, since most feeds don't send CORS headers and can't be
fetched directly from the browser.

Live at: https://wp-feed-proxy.williampickup.workers.dev/?url=&lt;feed-url&gt;

This was originally created via Cloudflare's dashboard "quick edit" mode
with no local source — this directory brings it into the repo.

## Requirements

- `wrangler` (installed globally already if you've used other Workers on
  this machine; otherwise `npm install -g wrangler`)
- Logged in via `wrangler login`, authorized against the account that owns
  the `williampickup.workers.dev` subdomain

## Local development

```sh
cd worker
wrangler dev
```

## Deploy

```sh
cd worker
wrangler deploy
```

This publishes to the existing `wp-feed-proxy` Worker — same name as the
one currently live, so it overwrites it rather than creating a new one.

## Notes

- No environment variables or bindings. Caching is done via the platform
  Cache API (`caches.default`), keyed per feed URL, 2-hour TTL.
- CORS is locked to `https://williampickup.org` (plus `localhost` for local
  dev) — see `ALLOWED_ORIGIN` in `index.js`.
