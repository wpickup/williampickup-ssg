(function () {
  'use strict';

  // ── Phase 1: Filter ──────────────────────────────────────────────────────────

  const items   = Array.from(document.querySelectorAll('.blogroll-item'));
  const buttons = Array.from(document.querySelectorAll('.blogroll-filters .filter-btn'));

  if (!items.length || !buttons.length) return;

  // Count items per category and annotate button labels
  const counts = {};
  items.forEach(item => {
    const cat = item.dataset.category;
    counts[cat] = (counts[cat] || 0) + 1;
  });

  buttons.forEach(btn => {
    const filter = btn.dataset.filter;
    if (filter === 'all') {
      btn.textContent = `All (${items.length})`;
    } else if (counts[filter]) {
      btn.textContent = `${btn.textContent} (${counts[filter]})`;
    } else {
      btn.hidden = true; // category in markup but no items
    }
  });

  // Filter on click
  buttons.forEach(btn => {
    btn.addEventListener('click', () => {
      const filter = btn.dataset.filter;
      buttons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      items.forEach(item => {
        item.hidden = filter !== 'all' && item.dataset.category !== filter;
      });
      document.getElementById('blogroll')?.focus();
    });
  });

  // Sync filter from URL hash on load (e.g. blogroll.html#craft)
  const hash = location.hash.slice(1);
  if (hash) {
    const matchBtn = buttons.find(b => b.dataset.filter === hash);
    if (matchBtn) matchBtn.click();
  }


  // ── Phase 2: Idle-time RSS enrichment ────────────────────────────────────────
  //
  // Fetches the most recent post from each feed via the Cloudflare Worker proxy
  // (worker/index.js). Only runs when the browser is idle and the connection
  // isn't metered or slow. Results are cached in localStorage for CACHE_TTL.

  const API = 'https://wp-feed-proxy.williampickup.workers.dev/?url=';

  const CACHE_KEY  = 'wp.blogroll.v2';          // bump version if response shape changes
  const CACHE_TTL  = 6 * 60 * 60 * 1000;        // 6 hours
  const BATCH_SIZE = 5;                          // worker has no rate limit — larger batches fine
  const BATCH_GAP  = 200;                        // ms between batches

  // Skip enrichment on metered or very slow connections
  function shouldSkip() {
    const c = navigator.connection;
    return c && (c.saveData ||
                 c.effectiveType === 'slow-2g' ||
                 c.effectiveType === '2g');
  }

  // ── Cache helpers ─────────────────────────────────────────────────────────

  function loadCache() {
    try {
      const raw = localStorage.getItem(CACHE_KEY);
      if (!raw) return null;
      const obj = JSON.parse(raw);
      if (Date.now() - obj.ts > CACHE_TTL) return null;
      return obj.feeds;
    } catch { return null; }
  }

  function saveCache(feeds) {
    try {
      localStorage.setItem(CACHE_KEY, JSON.stringify({ ts: Date.now(), feeds }));
    } catch {} // quota exceeded — fail silently
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  function ago(dateStr) {
    const d = Math.floor((Date.now() - new Date(dateStr)) / 86400000);
    if (d <= 0)  return 'today';
    if (d === 1) return 'yesterday';
    if (d < 7)   return `${d} days ago`;
    if (d < 30)  return `${Math.floor(d / 7)}w ago`;
    if (d < 365) return `${Math.floor(d / 30)}mo ago`;
    return       `${Math.floor(d / 365)}y ago`;
  }

  // ── DOM update ───────────────────────────────────────────────────────────

  // Classify last-post date into a recency bucket for CSS styling
  function recencyClass(dateStr) {
    if (!dateStr) return 'is-dormant';
    const days = Math.floor((Date.now() - new Date(dateStr)) / 86400000);
    if (days <=  7)  return 'is-fresh';
    if (days <= 60)  return 'is-recent';
    if (days <= 365) return 'is-quiet';
    return 'is-dormant';
  }

  function applyEnrichment(item, data) {
    item.classList.remove('is-loading');
    if (!data?.title) return;

    // Apply recency class to card (remove any previous bucket first)
    item.classList.remove('is-fresh', 'is-recent', 'is-quiet', 'is-dormant');
    item.classList.add(recencyClass(data.date));

    // Reuse existing element (from loading state) or create fresh
    const el = item.querySelector('.blogroll-item__last-post')
             ?? (() => {
               const d = document.createElement('div');
               item.appendChild(d);
               return d;
             })();

    const link       = document.createElement('a');
    link.href        = data.url;
    link.textContent = data.title;
    link.target      = '_blank';
    link.rel         = 'noopener';

    const date           = document.createElement('span');
    date.className       = 'blogroll-item__last-date';
    date.textContent     = ago(data.date);

    el.className = 'blogroll-item__last-post';
    el.replaceChildren(link, date);
    el.style.display = 'flex'; // overrides the CSS display:none default
  }

  // ── Fetch ────────────────────────────────────────────────────────────────

  async function fetchFeed(feedUrl) {
    const res = await fetch(API + encodeURIComponent(feedUrl));
    if (!res.ok) throw new Error(res.status);
    const json = await res.json();
    if (json.error || !json.title || !json.url) throw new Error(json.error ?? 'empty');
    return { title: json.title, url: json.url, date: json.date };
  }

  // ── Main enrichment routine ───────────────────────────────────────────────

  async function enrichAll() {
    if (shouldSkip()) return;

    const withFeed = items.filter(i => i.dataset.feed);
    const cache    = loadCache() || {};
    const pending  = [];
    const live     = { ...cache };

    // Apply anything already cached — instant, no requests needed
    withFeed.forEach(item => {
      if (cache[item.dataset.feed]) {
        applyEnrichment(item, cache[item.dataset.feed]);
      } else {
        pending.push(item);
      }
    });

    if (!pending.length) return;

    // Show loading shimmer on cards we're about to fetch
    pending.forEach(item => {
      const el = document.createElement('div');
      el.className = 'blogroll-item__last-post';
      item.appendChild(el);
      item.classList.add('is-loading');
    });

    // Fetch in batches — small gap gives the worker breathing room
    for (let i = 0; i < pending.length; i += BATCH_SIZE) {
      const batch = pending.slice(i, i + BATCH_SIZE);

      await Promise.allSettled(batch.map(async item => {
        try {
          const data = await fetchFeed(item.dataset.feed);
          live[item.dataset.feed] = data;
          applyEnrichment(item, data);
        } catch {
          // Feed unavailable or parse error — remove shimmer, leave card as-is
          item.classList.remove('is-loading');
        }
      }));

      // Pause between batches (not after the last one)
      if (i + BATCH_SIZE < pending.length) {
        await new Promise(r => setTimeout(r, BATCH_GAP));
      }
    }

    saveCache(live);
  }

  // Kick off when the browser reports it has idle time.
  // timeout:10000 means "run within 10s even if never truly idle."
  if ('requestIdleCallback' in window) {
    requestIdleCallback(() => enrichAll(), { timeout: 10000 });
  } else {
    setTimeout(enrichAll, 3000); // Safari fallback
  }

})();
