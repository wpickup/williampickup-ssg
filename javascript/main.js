/* ─────────────────────────────────────────────
   main.js
   ───────────────────────────────────────────── */

(function () {
  'use strict';

  /* ── Theme toggle ────────────────────────────────────────────────────
     Reads localStorage on load; falls back to prefers-color-scheme.
     Applies data-theme to <html>. Sun icon = dark mode, moon = light.
  ──────────────────────────────────────────────────────────────────── */
  (function initTheme() {
    const stored = localStorage.getItem('theme');
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const theme = stored || (prefersDark ? 'dark' : 'light');
    document.documentElement.setAttribute('data-theme', theme);
  })();

  const themeBtn = document.querySelector('.theme-toggle');
  if (themeBtn) {
    themeBtn.addEventListener('click', () => {
      const current = document.documentElement.getAttribute('data-theme');
      const next = current === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
      localStorage.setItem('theme', next);
    });
  }

  /* ── Promote markdown blockquotes to Quotebacks ──────────────────────
     Convention: blockquote whose last paragraph starts with — and
     contains a link:
       > Quote text here.
       >
       > — Author Name, [Article Title](https://example.com)
     The link provides the cite URL and title; text before the first
     comma is treated as the author.
  ──────────────────────────────────────────────────────────────────── */
  document.querySelectorAll('.post-body blockquote:not(.quoteback)').forEach(bq => {
    const paras = [...bq.querySelectorAll(':scope > p')];
    if (!paras.length) return;

    const attribution = paras[paras.length - 1];
    if (!/^[—–]/.test(attribution.textContent.trim())) return;

    const link = attribution.querySelector('a');
    if (!link) return;

    const cite      = link.href;
    const dataTitle = link.textContent.trim();
    const raw       = attribution.textContent.trim().replace(/^[—–]\s*/, '');
    const author    = raw.split(/,\s*/)[0].trim();

    const footer = document.createElement('footer');
    footer.innerHTML = `${author}<cite> <a href="${cite}">${dataTitle}</a></cite>`;

    attribution.remove();
    bq.appendChild(footer);
    bq.classList.add('quoteback');
    bq.setAttribute('cite', cite);
    bq.setAttribute('data-title', dataTitle);
    bq.setAttribute('data-author', author);
  });

  /* ── Scroll: add border to header when page scrolls ── */
  const header = document.querySelector('.site-header');
  if (header) {
    const onScroll = () => header.classList.toggle('scrolled', window.scrollY > 20);
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }

  /* ── Mobile nav toggle ── */
  const toggle = document.querySelector('.nav-toggle');
  const nav    = document.querySelector('.main-nav');
  if (toggle && nav) {
    toggle.addEventListener('click', () => {
      const expanded = toggle.getAttribute('aria-expanded') === 'true';
      toggle.setAttribute('aria-expanded', String(!expanded));
      nav.classList.toggle('open', !expanded);
      document.body.style.overflow = expanded ? '' : 'hidden';
    });
    nav.querySelectorAll('a').forEach(link => {
      link.addEventListener('click', () => {
        toggle.setAttribute('aria-expanded', 'false');
        nav.classList.remove('open');
        document.body.style.overflow = '';
      });
    });
  }

  /* ── Mark current page nav link ── */
  const path = window.location.pathname.split('/').pop() || 'index.html';
  document.querySelectorAll('.main-nav a').forEach(link => {
    const href = link.getAttribute('href');
    if (href === path || (path === '' && href === 'index.html')) {
      link.setAttribute('aria-current', 'page');
    }
  });

  /* ── Scroll-reveal: fade + rise elements into view ─────────────────
     Elements matching the selector start invisible (.will-animate).
     When they enter the viewport the observer adds .animate-in which
     triggers the CSS fadeUp keyframe. Siblings within a shared parent
     get a staggered delay so grouped items arrive in sequence.
     Respects prefers-reduced-motion via CSS — no JS branch needed.
  ──────────────────────────────────────────────────────────────────── */
  const REVEAL_SELECTOR = [
    '.home-masthead__name',
    '.home-hero',
    '.now-strip__item',
    '.post-card',
    '.gallery-item',
    '.now-section',
    '.page-hero',
    '.bio-layout > *',
    '.work-item',
  ].join(', ');

  const revealItems = document.querySelectorAll(REVEAL_SELECTOR);

  if ('IntersectionObserver' in window && revealItems.length) {
    // Mark all targets invisible before observation begins
    revealItems.forEach(el => el.classList.add('will-animate'));

    // Compute stagger delay: index among siblings that share the same selector
    revealItems.forEach(el => {
      const siblings = el.parentElement
        ? [...el.parentElement.querySelectorAll(REVEAL_SELECTOR)]
        : [];
      const idx = siblings.indexOf(el);
      if (idx > 0) el.style.animationDelay = (idx * 0.07) + 's';
    });

    const io = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.remove('will-animate');
          entry.target.classList.add('animate-in');
          io.unobserve(entry.target);
        }
      });
    }, { threshold: 0.06, rootMargin: '0px 0px -40px 0px' });

    revealItems.forEach(el => io.observe(el));
  }

  /* ── Hide featured posts from main blog list ── */
  document.querySelectorAll('.blog-list [data-featured="true"]').forEach(el => {
    el.style.display = 'none';
  });

  /* ── Tag filter via URL hash ── */
  const blogList = document.querySelector('.blog-list');

  function parseTags(str) {
    return (str || '').split(/[;\n]/).map(t => t.trim()).filter(Boolean);
  }

  function getListItems() {
    return Array.from(document.querySelectorAll('.blog-list .post-card:not([data-featured="true"])'));
  }

  function applyTagFilter(tag) {
    let count = 0;
    getListItems().forEach(el => {
      const match = parseTags(el.dataset.tags).includes(tag);
      el.style.display = match ? '' : 'none';
      if (match) count++;
    });
    const notice  = document.getElementById('tagFilterNotice');
    const label   = document.getElementById('tagFilterLabel');
    const countEl = document.getElementById('tagFilterCount');
    if (notice && label) {
      label.textContent = tag;
      if (countEl) countEl.textContent = count === 1 ? '1 post' : count + ' posts';
      notice.hidden = false;
    }
  }

  function clearTagFilter() {
    getListItems().forEach(el => { el.style.display = ''; });
    const notice = document.getElementById('tagFilterNotice');
    if (notice) notice.hidden = true;
    history.replaceState(null, '', location.pathname);
  }
  window.clearTagFilter = clearTagFilter;

  if (blogList && location.hash) {
    applyTagFilter(decodeURIComponent(location.hash.slice(1)));
  }

  /* ── Blog / portfolio filter buttons ── */
  const filterBtns = document.querySelectorAll('.filter-btn');
  const filterable = document.querySelectorAll('[data-category]');
  if (filterBtns.length && filterable.length) {
    filterBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        filterBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        clearTagFilter();
        const filter = btn.dataset.filter;
        filterable.forEach(item => {
          if (item.dataset.featured === 'true') return;
          const categories = item.dataset.category.split(';');
          const show = filter === 'all' || categories.includes(filter);
          item.style.transition    = 'opacity 0.3s ease';
          item.style.opacity       = show ? '1' : '0';
          item.style.pointerEvents = show ? '' : 'none';
          item.style.visibility    = show ? '' : 'hidden';
          item.style.position      = show ? '' : 'absolute';
        });
      });
    });
  }

  /* ── Writing page theme links ── */
  const filterLinks = document.querySelectorAll('[data-filter-link]');
  if (filterLinks.length && filterBtns.length) {
    filterLinks.forEach(link => {
      link.addEventListener('click', (event) => {
        event.preventDefault();
  
        const targetFilter = link.dataset.filterLink;
        const targetBtn = Array.from(filterBtns).find(
          btn => btn.dataset.filter === targetFilter
        );
  
        if (targetBtn) {
          targetBtn.click();
          const filtersNav = document.querySelector('.blog-filters');
          if (filtersNav) {
            filtersNav.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
          }
        }
      });
    });
  }


  /* ── Webmentions ───────────────────────────────────────────────────
     Fetches from webmention.io and renders replies, likes, and
     mentions. The target URL is read from data-url on the section
     so it works on local preview and live site alike.
  ──────────────────────────────────────────────────────────────────── */
  (function initWebmentions() {
    const section = document.getElementById('webmentions');
    if (!section) return;
    const targetUrl = section.dataset.url;
    if (!targetUrl) return;

    function esc(str) {
      return String(str)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;')
        .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    function fmtDate(iso) {
      if (!iso) return '';
      return new Date(iso).toLocaleDateString('en-AU', {
        year: 'numeric', month: 'long', day: 'numeric'
      });
    }

    fetch('https://webmention.io/api/mentions.jf2?per-page=50&target=' + encodeURIComponent(targetUrl))
      .then(r => r.json())
      .then(data => {
        const all = data.children || [];
        if (!all.length) return;

        const replies   = all.filter(m => m['wm-property'] === 'in-reply-to');
        const reactions = all.filter(m => ['like-of','repost-of','bookmark-of'].includes(m['wm-property']));
        const mentions  = all.filter(m => m['wm-property'] === 'mention-of');

        let html = '<p class="webmentions__heading">Webmentions <span class="webmentions__count">' + all.length + '</span></p>';

        if (replies.length) {
          html += '<ol class="webmentions__replies">';
          replies.forEach(m => {
            const a    = m.author || {};
            const name = esc(a.name || 'Someone');
            const href = esc(a.url  || m.url || '#');
            const src  = esc(m.url  || '#');
            const text = m.content && m.content.text ? esc(m.content.text) : '';
            html += '<li class="webmention webmention--reply">';
            html +=   '<div class="webmention__meta">';
            html +=     '<a href="' + href + '" class="webmention__author">';
            if (a.photo) html += '<img src="' + esc(a.photo) + '" alt="' + name + '" class="webmention__avatar" width="36" height="36" loading="lazy">';
            html +=       '<span>' + name + '</span>';
            html +=     '</a>';
            if (m.published) html += '<time class="webmention__date">' + fmtDate(m.published) + '</time>';
            html +=   '</div>';
            if (text) html += '<p class="webmention__text">' + text + '</p>';
            html +=   '<a href="' + src + '" class="webmention__source">source ↗</a>';
            html += '</li>';
          });
          html += '</ol>';
        }

        if (reactions.length) {
          html += '<div class="webmentions__reactions">';
          const rCount = reactions.length;
          html += '<p class="webmentions__reactions-label">' + rCount + ' ' + (rCount === 1 ? 'reaction' : 'reactions') + '</p>';
          html += '<ul class="webmentions__avatars">';
          reactions.forEach(m => {
            const a    = m.author || {};
            const name = esc(a.name || 'Someone');
            const href = esc(a.url  || m.url || '#');
            const prop = m['wm-property'];
            const verb = prop === 'repost-of' ? 'reposted' : prop === 'bookmark-of' ? 'bookmarked' : 'liked';
            html += '<li><a href="' + href + '" title="' + name + ' ' + verb + ' this">';
            if (a.photo) {
              html += '<img src="' + esc(a.photo) + '" alt="' + name + '" class="webmention__avatar" width="32" height="32" loading="lazy">';
            } else {
              html += '<span class="webmention__avatar-placeholder">' + esc((a.name || '?')[0].toUpperCase()) + '</span>';
            }
            html += '</a></li>';
          });
          html += '</ul></div>';
        }

        if (mentions.length) {
          html += '<ul class="webmentions__mentions">';
          mentions.forEach(m => {
            const a    = m.author || {};
            const name = esc(a.name || (m['wm-source'] ? new URL(m['wm-source']).hostname : 'Someone'));
            const src  = esc(m['wm-source'] || '#');
            html += '<li><a href="' + src + '">' + name + '</a> mentioned this</li>';
          });
          html += '</ul>';
        }

        section.innerHTML = html;
        section.removeAttribute('hidden');
      })
      .catch(() => {});
  })();

  /* ── Location ticker ────────────────────────────────────────────────
     Home page only. Fetches current temperature from Open-Meteo (free,
     no key, CORS-friendly) and shows coordinates + temp + local time.
     Hidden element revealed on success; silent failure on any error.
  ──────────────────────────────────────────────────────────────────── */
  (function initLocationTicker() {
    const el = document.getElementById('location-ticker');
    if (!el) return;

    const LAT  = -33.767;
    const LON  = 151.283;
    const TZ   = 'Australia/Sydney';

    function toDMS(deg, posDir, negDir) {
      const d   = Math.floor(Math.abs(deg));
      const mf  = (Math.abs(deg) - d) * 60;
      const m   = Math.floor(mf);
      const dir = deg >= 0 ? posDir : negDir;
      return d + '°' + (m < 10 ? '0' : '') + m + '′' + dir;
    }

    function localTime() {
      return new Date().toLocaleTimeString('en-AU', {
        timeZone: TZ, hour: 'numeric', minute: '2-digit', hour12: true
      }).replace(/\s?[AP]M/, m => m.trim().toLowerCase());
    }

    const url = 'https://api.open-meteo.com/v1/forecast'
      + '?latitude=' + LAT + '&longitude=' + LON
      + '&current=temperature_2m&timezone=' + encodeURIComponent(TZ);

    fetch(url)
      .then(r => r.json())
      .then(data => {
        const temp = Math.round(data.current.temperature_2m);
        const lat  = toDMS(LAT, 'N', 'S');
        const lon  = toDMS(LON, 'E', 'W');
        const text = lat + ' ' + lon + ' · ' + temp + '°C · ' + localTime();
        const sep  = '             ';
        const track = document.createElement('span');
        track.className = 'location-ticker__track';
        track.textContent = text + sep + text + sep;
        el.textContent = '';
        el.appendChild(track);
        el.hidden = false;
        requestAnimationFrame(() => el.classList.add('is-loaded'));
      })
      .catch(() => {});
  })();

})();