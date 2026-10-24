// =====================================================================
// Studio kit - build a full, multi-page, animated website in #html Volt,
// in the spirit of a big studio's splashy show/franchise site: a sticky
// nav, full-bleed hero banners, pages that switch instead of reload, and
// scroll-triggered reveal animations.
//
// PAGES - wrap each page's content between pageOpen/pageClose. Only one
// page is visible at a time; switching is instant (no reload), and the
// URL's #hash tracks which page is open so links/back-button work. You
// can put ANY normal Volt content inside a page - show, button, print,
// not just html strings:
//   html pageOpen("home", "Home")
//   html heroBanner("Fall 2026 Lineup", "New simulcasts every week", "bg.jpg")
//   html revealDiv(card("Welcome", "Pick a show below to get started."))
//   button "Surprise me" { print "Try Shows -> Random Pick!" }
//   html pageClose()
//
// NAV - put this once, right after title, before your first page:
//   html navOpen()
//   html navLink("Home", "home")
//   html navLink("Shows", "shows")
//   html navClose()
//
// REVEAL ANIMATION - wrap any chunk of HTML in revealDiv(...) and it
// fades/slides up into place the first time it scrolls into view:
//   html revealDiv("<h2>About the studio</h2><p>...</p>")
//
// Everything lives under studio-* classes/ids, so it won't clash with
// other addons on the same page (ui-kit, vfx-engine, etc. all compose).
// =====================================================================

## :root { --studio-bg: #0b0c10; --studio-panel: #15171f; --studio-border: #262936; --studio-text: #f1f2f8; --studio-muted: #9aa0b4; --studio-accent: #ff3d68; --studio-accent-2: #4cc9f0; }
## body { background: var(--studio-bg); color: var(--studio-text); margin: 0; }
## body #volt { max-width: none !important; padding: 0 !important; }

## .studio-nav { position: sticky; top: 0; z-index: 500; display: flex; align-items: center; gap: 4px; padding: 14px 24px; background: rgba(11,12,16,0.75); backdrop-filter: blur(10px); border-bottom: 1px solid var(--studio-border); }
## .studio-nav a { color: var(--studio-muted); text-decoration: none; font-weight: 600; font-size: 0.95em; padding: 8px 14px; border-radius: 999px; cursor: pointer; transition: color 0.2s ease, background 0.2s ease; }
## .studio-nav a:hover { color: var(--studio-text); background: rgba(255,255,255,0.06); }
## .studio-nav a.studio-nav-active { color: var(--studio-bg); background: var(--studio-accent); }

## .studio-page { display: none; opacity: 0; }
## .studio-page.studio-page-active { display: block; animation: studio-page-in 0.35s ease forwards; }
## @keyframes studio-page-in { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }

## .studio-hero { position: relative; min-height: 56vh; display: flex; align-items: flex-end; padding: 60px 40px; background-size: cover; background-position: center; isolation: isolate; }
## .studio-hero::before { content: ''; position: absolute; inset: 0; background: linear-gradient(0deg, rgba(11,12,16,0.95) 0%, rgba(11,12,16,0.35) 55%, rgba(11,12,16,0.1) 100%); z-index: -1; }
## .studio-hero-title { font-size: clamp(2em, 5vw, 3.4em); font-weight: 800; margin: 0 0 8px; letter-spacing: -0.01em; }
## .studio-hero-sub { font-size: 1.15em; color: var(--studio-muted); max-width: 640px; }

## .studio-reveal { opacity: 0; transform: translateY(26px); transition: opacity 0.7s ease, transform 0.7s ease; }
## .studio-reveal.studio-in { opacity: 1; transform: translateY(0); }

## .studio-footer { padding: 30px 40px 50px; text-align: center; color: var(--studio-muted); font-size: 0.9em; border-top: 1px solid var(--studio-border); margin-top: 20px; }
## .studio-group-start, .studio-group-end { display: none !important; }

# (function () {
#   // html-statement calls each parse their own markup independently, so
#   // an opening tag in one call and its children in later calls never
#   // actually nest in the DOM. Instead, pageOpen/navOpen etc. drop a
#   // tiny self-closing marker div, and this runs once after the page's
#   // own top-level Volt code has built everything, re-parenting whatever
#   // sits between a start/end marker into a real wrapper element -
#   // which means pages and the nav can contain ANY Volt content (show,
#   // button, print...), not just html strings.
#   // `html x` always wraps x in its own <div class="volt-html"> before
#   // appending it, so a marker div dropped by pageOpen/navOpen etc. is
#   // actually one level deeper than a direct child of #volt - nested
#   // inside that wrapper. This unwraps it to find the real marker.
#   function marker(node) {
#     if (node.nodeType !== 1) return null;
#     if (node.classList.contains('studio-group-start')) return { kind: 'start', data: node.dataset };
#     if (node.classList.contains('studio-group-end')) return { kind: 'end', data: node.dataset };
#     if (node.classList.contains('volt-html') && node.children.length === 1) return marker(node.firstElementChild);
#     return null;
#   }
#   function reflow() {
#     const root = document.getElementById('volt');
#     if (!root) return;
#     const kids = Array.from(root.childNodes);
#     const stack = [{ el: root, out: [] }];
#     kids.forEach((node) => {
#       const m = marker(node);
#       if (m && m.kind === 'start') {
#         const wrap = document.createElement(m.data.tag || 'div');
#         if (m.data.class) wrap.className = m.data.class;
#         if (m.data.page) wrap.dataset.page = m.data.page;
#         if (m.data.label) wrap.setAttribute('aria-label', m.data.label);
#         stack.push({ el: wrap, out: [] });
#       } else if (m && m.kind === 'end' && stack.length > 1) {
#         const finished = stack.pop();
#         finished.out.forEach((c) => finished.el.appendChild(c));
#         stack[stack.length - 1].out.push(finished.el);
#       } else {
#         stack[stack.length - 1].out.push(node);
#       }
#     });
#     while (stack.length > 1) {
#       const finished = stack.pop();
#       finished.out.forEach((c) => finished.el.appendChild(c));
#       stack[stack.length - 1].out.push(finished.el);
#     }
#     root.innerHTML = '';
#     stack[0].out.forEach((c) => root.appendChild(c));
#   }
#
#   function showPage(id, push) {
#     document.querySelectorAll('.studio-page').forEach((p) => p.classList.toggle('studio-page-active', p.dataset.page === id));
#     document.querySelectorAll('.studio-nav a[data-page]').forEach((a) => a.classList.toggle('studio-nav-active', a.dataset.page === id));
#     if (push !== false && location.hash.slice(1) !== id) history.pushState(null, '', '#' + id);
#     window.scrollTo(0, 0);
#   }
#   window.STUDIO = { showPage };
#
#   window.addEventListener('DOMContentLoaded', () => {
#     reflow();
#     const first = document.querySelector('.studio-page');
#     const wanted = location.hash.slice(1) || (first && first.dataset.page);
#     if (wanted) showPage(wanted, false);
#
#     const io = new IntersectionObserver((entries) => {
#       entries.forEach((entry) => { if (entry.isIntersecting) { entry.target.classList.add('studio-in'); io.unobserve(entry.target); } });
#     }, { threshold: 0.15 });
#     document.querySelectorAll('.studio-reveal').forEach((el) => io.observe(el));
#   });
#   window.addEventListener('hashchange', () => { const id = location.hash.slice(1); if (id) showPage(id, false); });
# })();

// ---------------------------------------------------------------------
// Volt wrappers - call with `html`
// ---------------------------------------------------------------------

fn navOpen() {
  return "<div class='studio-group-start' data-tag='nav' data-class='studio-nav'></div>"
}

fn navClose() {
  return "<div class='studio-group-end'></div>"
}

fn navLink(label, pageId) {
  return "<a data-page='" + pageId + "' onclick=\"STUDIO.showPage('" + pageId + "')\">" + label + "</a>"
}

fn pageOpen(pageId, pageTitle) {
  return "<div class='studio-group-start' data-tag='section' data-class='studio-page' data-page='" + pageId + "' data-label='" + pageTitle + "'></div>"
}

fn pageClose() {
  return "<div class='studio-group-end'></div>"
}

fn heroBanner(bannerTitle, bannerSub, imageUrl) {
  return "<header class='studio-hero' style=\"background-image:url('" + imageUrl + "')\"><div><div class='studio-hero-title'>" + bannerTitle + "</div><div class='studio-hero-sub'>" + bannerSub + "</div></div></header>"
}

fn revealDiv(innerHtml) {
  return "<div class='studio-reveal'>" + innerHtml + "</div>"
}

fn siteFooter(footerText) {
  return "<footer class='studio-footer'>" + footerText + "</footer>"
}
