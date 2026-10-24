// =====================================================================
// UI kit - a set of ready-made pieces for #html Volt pages: cards,
// badges, alerts, a stat tile, a progress bar, an avatar, a styled
// button row, toasts and a modal dialog.
//
// Everything lives under ui-* CSS classes, so it's opt-in and won't
// restyle anything already on your page (it never touches bare `body`
// or `button` selectors). Paste this near the top of a #html Volt file,
// after your `title` line, then use the pieces below.
//
// DISPLAY pieces (card, badge, alertBox, divider, statTile, progressBar,
// avatar) are plain Volt functions that return an HTML string - show
// them with Volt's own `html` statement:
//   html card("Welcome", "Thanks for stopping by.")
//
// A STYLED BUTTON ROW uses Volt's real `button` statement (so clicks
// still run your own Volt code) wrapped in a coloured row:
//   html "<div class='ui-btn-row ui-primary'>"
//   button "Save" { print "Saved!" }
//   button "Cancel" { print "Cancelled" }
//   html "</div>"
// (swap ui-primary for ui-danger or ui-ghost for the other styles)
//
// INTERACTIVE pieces (toast, showModal, closeModal) are raw JS, same
// escape-hatch trick as the VFX engine library: everything lands on
// window.UI, with thin Volt fn wrappers below so your own code just
// calls toast("Saved!") or showModal("Delete item?", "This can't be undone.").
// Their markup is built directly on <body> (not through Volt's `html`
// statement) so a fixed-position modal/toast is never accidentally
// trapped inside some other element's stacking context - the same
// backdrop-filter containing-block bug the VFX engine's canvas hit.
// =====================================================================

## :root { --ui-accent: #4cc9f0; --ui-card: #1a1d29; --ui-border: #2a2d3d; --ui-text: #eef0ff; --ui-muted: #9aa0c0; --ui-radius: 12px; }

## .ui-card { background: var(--ui-card); border: 1px solid var(--ui-border); border-radius: var(--ui-radius); padding: 16px 18px; margin: 10px 0; }
## .ui-card h3 { margin: 0 0 8px; font-size: 1.05em; color: var(--ui-text); }
## .ui-card-body { color: var(--ui-muted); line-height: 1.5; }

## .ui-badge { display: inline-block; padding: 3px 10px; border-radius: 999px; font-size: 0.8em; font-weight: 700; letter-spacing: 0.02em; }
## .ui-badge-info { background: #1a3a4a; color: #7dd3fc; }
## .ui-badge-success { background: #15321f; color: #86efac; }
## .ui-badge-warning { background: #3a2f12; color: #fde68a; }
## .ui-badge-danger { background: #3a1818; color: #fca5a5; }

## .ui-alert { display: block; padding: 12px 14px; border-radius: 10px; border-left: 4px solid var(--ui-accent); background: var(--ui-card); margin: 10px 0; color: var(--ui-text); }
## .ui-alert-success { border-left-color: #4ade80; }
## .ui-alert-warning { border-left-color: #fbbf24; }
## .ui-alert-danger { border-left-color: #f87171; }

## .ui-divider { border: 0; border-top: 1px solid var(--ui-border); margin: 18px 0; }

## .ui-stat { display: inline-block; min-width: 120px; padding: 14px 18px; border-radius: var(--ui-radius); background: var(--ui-card); border: 1px solid var(--ui-border); margin: 6px 10px 6px 0; text-align: center; }
## .ui-stat-value { font-size: 1.6em; font-weight: 800; color: var(--ui-text); }
## .ui-stat-label { font-size: 0.8em; color: var(--ui-muted); margin-top: 2px; }

## .ui-progress { height: 10px; border-radius: 999px; background: var(--ui-border); overflow: hidden; margin: 10px 0; }
## .ui-progress-bar { height: 100%; background: var(--ui-accent); transition: width 0.3s ease; }

## .ui-avatar { display: inline-flex; align-items: center; justify-content: center; width: 42px; height: 42px; border-radius: 50%; background: var(--ui-accent); color: #04121a; font-weight: 800; }

## .ui-btn-row { display: flex; flex-wrap: wrap; gap: 8px; margin: 10px 0; }
## .ui-btn-row.ui-primary button { background: var(--ui-accent); color: #04121a; }
## .ui-btn-row.ui-danger button { background: #f87171; color: #2a0a0a; }
## .ui-btn-row.ui-ghost button { background: transparent; border: 1px solid var(--ui-border); color: var(--ui-text); }

## .ui-toast-wrap { position: fixed; right: 16px; bottom: 16px; z-index: 9999; display: flex; flex-direction: column; gap: 8px; pointer-events: none; }
## .ui-toast { padding: 10px 16px; border-radius: 10px; background: var(--ui-card); border: 1px solid var(--ui-border); color: var(--ui-text); box-shadow: 0 8px 24px rgba(0,0,0,0.35); opacity: 0; transform: translateY(8px); transition: opacity 0.2s ease, transform 0.2s ease; }
## .ui-toast.ui-show { opacity: 1; transform: translateY(0); }

## .ui-modal-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: none; align-items: center; justify-content: center; z-index: 9998; }
## .ui-modal-backdrop.ui-show { display: flex; }
## .ui-modal { max-width: 420px; width: calc(100% - 40px); background: var(--ui-card); border: 1px solid var(--ui-border); border-radius: var(--ui-radius); padding: 20px; color: var(--ui-text); }
## .ui-modal h3 { margin: 0 0 10px; }
## .ui-modal-body { color: var(--ui-muted); line-height: 1.5; }
## .ui-modal-actions { display: flex; justify-content: flex-end; margin-top: 16px; }

# (function () {
#   const toastWrap = document.createElement('div');
#   toastWrap.className = 'ui-toast-wrap';
#   document.body.appendChild(toastWrap);
#
#   const backdrop = document.createElement('div');
#   backdrop.className = 'ui-modal-backdrop';
#   backdrop.innerHTML = '<div class="ui-modal"><h3 id="uiModalTitle"></h3><div class="ui-modal-body" id="uiModalBody"></div><div class="ui-modal-actions"><button type="button" id="uiModalOk">OK</button></div></div>';
#   document.body.appendChild(backdrop);
#   const modalOk = backdrop.querySelector('#uiModalOk');
#   const modalTitle = backdrop.querySelector('#uiModalTitle');
#   const modalBody = backdrop.querySelector('#uiModalBody');
#   function closeModal() { backdrop.classList.remove('ui-show'); }
#   modalOk.onclick = closeModal;
#   backdrop.onclick = (e) => { if (e.target === backdrop) closeModal(); };
#
#   window.UI = {};
#   window.UI.toast = function (message, ms) {
#     const t = document.createElement('div');
#     t.className = 'ui-toast';
#     t.textContent = String(message);
#     toastWrap.appendChild(t);
#     requestAnimationFrame(() => t.classList.add('ui-show'));
#     setTimeout(() => {
#       t.classList.remove('ui-show');
#       setTimeout(() => t.remove(), 250);
#     }, ms || 2800);
#   };
#   window.UI.showModal = function (title, body) {
#     modalTitle.textContent = String(title);
#     modalBody.textContent = String(body);
#     backdrop.classList.add('ui-show');
#   };
#   window.UI.closeModal = closeModal;
# })();

// ---------------------------------------------------------------------
// Display pieces - call with `html`, e.g. html card("Title", "Body")
// ---------------------------------------------------------------------

fn card(title, body) {
  return "<div class='ui-card'><h3>" + title + "</h3><div class='ui-card-body'>" + body + "</div></div>"
}

fn badge(label, variant) {
  return "<span class='ui-badge ui-badge-" + variant + "'>" + label + "</span>"
}

fn alertBox(message, variant) {
  return "<div class='ui-alert ui-alert-" + variant + "'>" + message + "</div>"
}

fn divider() {
  return "<hr class='ui-divider'>"
}

fn statTile(label, value) {
  return "<div class='ui-stat'><div class='ui-stat-value'>" + value + "</div><div class='ui-stat-label'>" + label + "</div></div>"
}

fn progressBar(percent) {
  return "<div class='ui-progress'><div class='ui-progress-bar' style='width:" + percent + "%'></div></div>"
}

fn avatar(initials) {
  return "<span class='ui-avatar'>" + initials + "</span>"
}

// ---------------------------------------------------------------------
// Interactive pieces - call directly, no `html` needed
// ---------------------------------------------------------------------

fn toast(message) {
  # window.UI.toast(message)
}

fn showModal(title, body) {
  # window.UI.showModal(title, body)
}

fn closeModal() {
  # window.UI.closeModal()
}
