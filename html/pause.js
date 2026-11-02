// Pause menu (Esc). Tiles, title and the player card come from pause.lua; picking a tile is sent
// back (pauseAction) and pause.lua does the rest.
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'vi-hud';
    const post = (name, data = {}) =>
        fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        }).then((r) => r.json()).catch(() => ({}));

    const root = document.getElementById('pause');
    const $ = (s) => root.querySelector(s);
    const titleEl = $('.pm-title');
    const headingEl = $('.pm-heading');
    const nameEl = $('.pm-name');
    const metaEl = $('.pm-meta');
    const bankEl = $('.pm-bank');
    const cashEl = $('.pm-cash');
    const avatarEl = $('.pm-avatar');
    const imgEl = $('.pm-avatar img');
    const railEl = $('.pm-rail');
    const linksEl = $('.pm-links');
    const trackEl = $('.pm-track');
    const thumbEl = $('.pm-track i');

    const ICONS = {
        resume: '<path d="M7.5 4.6v14.8L19.6 12z"/>',
        map: '<path d="M2.8 6.4 8.3 4.4v13.4l-5.5 2z"/><path opacity=".55" d="M9.5 4.4l5 1.9v13.4l-5-1.9z"/><path d="M15.7 6.3l5.5-2v13.4l-5.5 2z"/>',
        hud: '<path fill-rule="evenodd" d="M2.5 4.8h19v14.4h-19zm1.8 1.8v10.8h15.4V6.6z"/><path d="M5.6 12.3h5.6v3.4H5.6z"/><path d="M14.6 8.2h3.4v1.7h-3.4zm-1.6 2.9h5v1.7h-5z"/>',
        settings: '<path d="M3 5.8h18v1.7H3zm0 5.4h18v1.7H3zm0 5.4h18v1.7H3z"/><circle cx="8" cy="6.65" r="2.4"/><circle cx="16" cy="12.05" r="2.4"/><circle cx="10.5" cy="17.45" r="2.4"/>',
        keys: '<path fill-rule="evenodd" d="M2 6.2h20v11.6H2zm1.8 1.8v8h16.4V8z"/><path d="M5.4 9.6h1.9v1.9H5.4zm3.1 0h1.9v1.9H8.5zm3.1 0h1.9v1.9h-1.9zm3.1 0h1.9v1.9h-1.9zm3.1 0h1.9v1.9h-1.9zM8.5 12.8h7v1.9h-7z"/>',
        leave: '<path d="M3.5 3.5h9.6v4.2h-1.9V5.4H5.4v13.2h5.8v-2.3h1.9v4.2H3.5z"/><path d="M15.6 7.6 20.5 12l-4.9 4.4v-3.2H9.2v-2.4h6.4z"/>',
    };

    const asArray = (v) => (Array.isArray(v) ? v : v && typeof v === 'object' ? Object.values(v) : []);
    const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = (n) => `${n < 0 ? '-$' : '$'}${Math.abs(Math.round(n)).toLocaleString('en-US')}`;

    let buttons = [];
    let tiles = [];
    let sel = 0;
    let links = [];   // Config.PauseMenu.Buttons: small buttons in the bottom-right corner
    let linkEls = [];
    let lsel = 0;
    let row = 'rail'; // which row has the selection: 'rail' (main tiles) or 'links'
    let isOpen = false;
    let confirming = false;
    let confirmTimer = 0;
    let busy = false; // an action was sent; ignore input until the menu closes / reopens
    let nextSel = 0;  // tile selected on the next open: the one used (back from the map...), Resume after Esc

    // ------------------------------------------------------------ render

    function iconHtml(b) {
        if (ICONS[b.id]) return `<svg viewBox="0 0 24 24">${ICONS[b.id]}</svg>`;
        if (typeof b.fa === 'string' && b.fa) return `<i class="${esc(b.fa)}"></i>`;
        return `<b>${esc(String(b.label || '?').charAt(0))}</b>`;
    }

    function renderTiles() {
        railEl.innerHTML = '';
        tiles = buttons.map((b, i) => {
            const el = document.createElement('div');
            el.className = `pm-tile${b.danger ? ' pm-danger' : ''}`;
            el.style.animationDelay = `${0.04 + i * 0.03}s`;
            el.innerHTML = `<div class="pm-art"><div class="pm-ico">${iconHtml(b)}</div></div><div class="pm-strip"><span>${esc(b.label)}</span></div>`;
            railEl.appendChild(el);
            return el;
        });
    }

    function renderLinks() {
        linksEl.innerHTML = '';
        linkEls = links.map((b, i) => {
            const el = document.createElement('div');
            el.className = 'pm-link';
            el.style.animationDelay = `${0.08 + i * 0.03}s`;
            el.innerHTML = `<div class="pm-lico">${iconHtml(b)}</div><span>${esc(b.label)}</span>`;
            linksEl.appendChild(el);
            return el;
        });
        linksEl.hidden = !links.length;
    }

    function paint() {
        tiles.forEach((t, n) => t.classList.toggle('pm-sel', row === 'rail' && n === sel));
        linkEls.forEach((t, n) => t.classList.toggle('pm-sel', row === 'links' && n === lsel));
        trackEl.classList.toggle('pm-away', row === 'links');
    }

    function placeThumb() {
        const t = tiles[sel];
        if (!t) return;
        const last = tiles[tiles.length - 1];
        trackEl.style.width = `${last.offsetLeft + last.offsetWidth}px`; // ends with the last tile
        thumbEl.style.width = `${t.offsetWidth}px`;
        thumbEl.style.transform = `translateX(${t.offsetLeft}px)`;
        trackEl.classList.toggle('pm-danger', !!(buttons[sel] && buttons[sel].danger));
    }

    function label(i, text) {
        const span = tiles[i] && tiles[i].querySelector('.pm-strip span');
        if (span) span.textContent = text;
    }

    function cancelConfirm() {
        if (!confirming) return;
        confirming = false;
        clearTimeout(confirmTimer);
        tiles.forEach((t, i) => {
            t.classList.remove('pm-confirm');
            label(i, buttons[i].label);
        });
    }

    // r = 'rail' / 'links', i wraps around within that row
    function select(r, i, withSound) {
        const list = r === 'links' ? links : buttons;
        if (!list.length) return;
        const next = (i + list.length) % list.length;
        const el = (r === 'links' ? linkEls : tiles)[next];
        if (r === row && el && el.classList.contains('pm-sel')) return;
        cancelConfirm();
        row = r;
        if (r === 'links') lsel = next;
        else sel = next;
        paint();
        placeThumb();
        if (withSound) post('pauseSound', { name: 'move' });
    }

    const cur = () => (row === 'links' ? lsel : sel);
    const step = (d) => select(row, cur() + d, true);

    function renderInfo(d) {
        if (!d) return;
        nameEl.textContent = d.name || '';
        metaEl.textContent = [d.job, d.id != null ? `ID ${d.id}` : ''].filter(Boolean).join('  ·  ');
        const setChip = (el, v) => {
            el.classList.toggle('pm-off', typeof v !== 'number');
            if (typeof v === 'number') el.querySelector('span').textContent = money(v);
        };
        setChip(bankEl, d.bank);
        setChip(cashEl, d.cash);
    }

    // ------------------------------------------------------------ actions

    function activate() {
        const b = row === 'links' ? links[lsel] : buttons[sel];
        if (!b || busy) return;
        if (row === 'rail' && b.id === 'leave' && !confirming) {
            confirming = true;
            tiles[sel].classList.add('pm-confirm');
            label(sel, 'Confirm');
            post('pauseSound', { name: 'error' });
            clearTimeout(confirmTimer);
            confirmTimer = setTimeout(cancelConfirm, 4000);
            return;
        }
        if (b.url && typeof window.invokeNative === 'function') window.invokeNative('openUrl', b.url);
        if (!b.keepOpen) busy = true;
        nextSel = row === 'rail' && b.id !== 'resume' ? sel : 0;
        post('pauseAction', { id: b.id });
    }

    function back() {
        if (busy) return;
        if (confirming) {
            cancelConfirm();
            post('pauseSound', { name: 'back' });
            return;
        }
        busy = true;
        nextSel = 0;
        post('pauseAction', { id: 'resume' });
    }

    // ------------------------------------------------------------ input

    railEl.addEventListener('mouseover', (e) => {
        const t = e.target.closest('.pm-tile');
        if (t && isOpen) select('rail', tiles.indexOf(t), true);
    });

    railEl.addEventListener('click', (e) => {
        const t = e.target.closest('.pm-tile');
        if (!t || !isOpen) return;
        select('rail', tiles.indexOf(t), false);
        activate();
    });

    linksEl.addEventListener('mouseover', (e) => {
        const t = e.target.closest('.pm-link');
        if (t && isOpen) select('links', linkEls.indexOf(t), true);
    });

    linksEl.addEventListener('click', (e) => {
        const t = e.target.closest('.pm-link');
        if (!t || !isOpen) return;
        select('links', linkEls.indexOf(t), false);
        activate();
    });

    // right click anywhere = back, like GTA's menus
    root.addEventListener('contextmenu', (e) => {
        e.preventDefault();
        if (isOpen) back();
    });

    let wheelAt = 0;
    root.addEventListener('wheel', (e) => {
        if (!isOpen || Date.now() - wheelAt < 90) return;
        wheelAt = Date.now();
        step(e.deltaY > 0 || e.deltaX > 0 ? 1 : -1);
    }, { passive: true });

    window.addEventListener('keydown', (e) => {
        if (!isOpen) return;
        switch (e.key) {
            case 'ArrowLeft': case 'a': case 'A': case 'q': case 'Q':
                step(-1); break;
            case 'ArrowRight': case 'd': case 'D': case 'e': case 'E':
                step(1); break;
            // up / down: between the tiles and the link buttons (or along the tiles when there are none)
            case 'ArrowUp': case 'w': case 'W':
                if (links.length) select('rail', sel, true);
                else step(-1);
                break;
            case 'ArrowDown': case 's': case 'S':
                if (links.length) select('links', lsel, true);
                else step(1);
                break;
            case 'Tab':
                step(e.shiftKey ? -1 : 1); break;
            case 'Home': select(row, 0, true); break;
            case 'End': select(row, (row === 'links' ? links : buttons).length - 1, true); break;
            case 'Enter': case ' ':
                if (!e.repeat) activate();
                break;
            case 'Escape': case 'Backspace':
                if (!e.repeat) back();
                break;
            default:
                if (/^[1-9]$/.test(e.key) && +e.key <= buttons.length) select('rail', +e.key - 1, true);
                else return;
        }
        e.preventDefault();
    });

    window.addEventListener('resize', () => { if (isOpen) placeThumb(); });

    // ------------------------------------------------------------ messages

    imgEl.addEventListener('load', () => avatarEl.classList.add('pm-hasimg'));
    imgEl.addEventListener('error', () => avatarEl.classList.remove('pm-hasimg'));

    window.addEventListener('message', (e) => {
        const d = e.data;
        if (!d || d.type !== 'pause') return;

        if (d.action === 'open') {
            buttons = asArray(d.buttons);
            links = asArray(d.links);
            titleEl.textContent = d.title || '';
            headingEl.firstElementChild.textContent = d.heading || '';
            headingEl.hidden = !d.heading;
            renderInfo(d.info);
            avatarEl.classList.remove('pm-hasimg');
            imgEl.removeAttribute('src');
            confirming = false;
            busy = false;
            isOpen = true;
            renderTiles();
            renderLinks();
            root.classList.remove('pm-hidden');
            sel = Math.min(nextSel, Math.max(0, buttons.length - 1));
            nextSel = 0; // closed some other way (export, resource restart): Resume next time
            lsel = 0;
            row = 'rail';
            paint();
            requestAnimationFrame(placeThumb);
        } else if (d.action === 'info') {
            if (isOpen) renderInfo(d.info);
        } else if (d.action === 'avatar') {
            if (isOpen && typeof d.url === 'string') imgEl.src = d.url;
        } else if (d.action === 'close') {
            isOpen = false;
            busy = false;
            cancelConfirm();
            root.classList.add('pm-hidden');
        }
    });
})();
