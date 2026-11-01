// Status icons under the minimap. State comes from status.lua; the row follows the minimap
// panel (#minimap), so it moves with the minimap layout editor (/hud > Minimap) too.
(() => {
    const root = document.getElementById('status');
    const panel = document.getElementById('minimap');
    const NS = 'http://www.w3.org/2000/svg';

    // Glyphs drawn in a 100x100 box (disc = the whole box). y0/y1 = the glyph's top / bottom,
    // used to fill it from the bottom up as the value drops.
    const ICONS = {
        stamina: { y0: 25, y1: 78, svg: '<path d="M57.2 25.4 L55.6 43.1 H79.4 L46.1 77.9 L48.3 61.3 H19.4 Z"/>' },
        oxygen: {
            y0: 30, y1: 74,
            svg: '<ellipse class="stroke" cx="41" cy="51.5" rx="14" ry="17.5" stroke-width="8"/>' +
                '<text x="60" y="74" font-size="27">2</text>',
        },
        health: {
            y0: 28, y1: 77,
            svg: '<path d="M50 76.5 L29 55.5 C21.5 48 22.5 35 33 30.8 C40.5 27.8 46.5 31.5 50 36.5 C53.5 31.5 59.5 27.8 67 30.8 C77.5 35 78.5 48 71 55.5 Z"/>',
        },
        armour: { y0: 25, y1: 77, svg: '<path d="M50 25 L72 32.5 V48.5 C72 62.5 62.5 72.5 50 77 C37.5 72.5 28 62.5 28 48.5 V32.5 Z"/>' },
        // fork (three tines) + knife
        hunger: {
            y0: 25, y1: 77,
            svg: '<rect x="30.4" y="25" width="3.6" height="17" rx="1.8"/>' +
                '<rect x="37.2" y="25" width="3.6" height="17" rx="1.8"/>' +
                '<rect x="44" y="25" width="3.6" height="17" rx="1.8"/>' +
                '<path d="M30.4 39 H47.6 V42 C47.6 46 44.6 48.6 41.5 49.5 V74.5 A2.5 2.5 0 0 1 36.5 74.5 V49.5 C33.4 48.6 30.4 46 30.4 42 Z"/>' +
                '<path d="M60.5 25 C66.8 27.2 68.5 37.5 68.5 53 H58.5 V27 C58.5 25.9 59.4 25 60.5 25 Z"/>' +
                '<rect x="58.5" y="51" width="6.5" height="26" rx="3.25"/>',
        },
        thirst: { y0: 23, y1: 78, svg: '<path d="M50 23 C50 23 29.5 46 29.5 57.5 A20.5 20.5 0 0 0 70.5 57.5 C70.5 46 50 23 50 23 Z"/>' },
    };
    // microphone (see mic.lua): capsule + cradle + stand, filled up to the voice range
    ICONS.voice = {
        y0: 22, y1: 77,
        svg: '<rect x="40.5" y="22" width="19" height="32" rx="9.5"/>' +
            '<path class="stroke" d="M31 44.5 A19 19 0 0 0 69 44.5" stroke-width="6.5" stroke-linecap="round"/>' +
            '<path class="stroke" d="M50 64 V74 M40 76.5 H60" stroke-width="6.5" stroke-linecap="round"/>',
    };
    const ORDER = ['voice', 'health', 'armour', 'stamina', 'hunger', 'thirst', 'oxygen'];
    const LOW = 20;

    const items = {};
    ORDER.forEach((name) => {
        const ic = ICONS[name];
        const el = document.createElement('div');
        el.className = `st st-${name} off gone`;
        el.innerHTML =
            `<svg viewBox="0 0 100 100">` +
            `<defs><clipPath id="st-clip-${name}" class="st-fill"><rect x="0" y="${ic.y0}" width="100" height="100"/></clipPath></defs>` +
            `<circle class="st-disc" cx="50" cy="50" r="48.25"/>` +
            `<g class="st-glyph st-dim">${ic.svg}</g>` +
            `<g class="st-glyph" clip-path="url(#st-clip-${name})">${ic.svg}</g>` +
            (name === 'voice'
                ? '<g class="st-slash"><path class="cut" d="M27 25 L73 76"/><path class="line" d="M27 25 L73 76"/></g>'
                : '') +
            `</svg>`;
        root.appendChild(el);
        items[name] = { el, rect: el.querySelector('clipPath rect'), ic, v: null };
    });

    const nav = document.getElementById('navstack');
    let noMap = false;   // radar is hidden (e.g. on foot with Config.OnlyInVehicle)
    let drop = 0.55;     // how far below the map's bottom edge the row sits then, in icon sizes
    let editing = false; // the layout editor shows the panel even when the radar is off

    // Row sits on top of the street bar / turn card stack (#navstack), with the same spacing the
    // stack uses between its cards. Without any cards it drops to just above the panel, clear of
    // the N / waypoint markers riding on the panel's top edge.
    // With the radar hidden the panel is invisible, so the row sits where the map's bottom edge is.
    function place() {
        const r = panel.getBoundingClientRect();
        const size = root.getBoundingClientRect().height;
        if (noMap && !editing) {
            root.style.left = `${r.left}px`;
            root.style.top = `${r.bottom - size + size * drop}px`;
            return;
        }
        const nk = parseFloat(getComputedStyle(panel).getPropertyValue('--nk')) || 0.85;
        const n = nav ? nav.getBoundingClientRect() : null;
        const top = n && n.height > 0
            ? n.top - r.width * nk * 0.03 - size
            : r.top - Math.max(r.width * nk * 0.027, r.height * 0.044 + 3) - size;
        root.style.left = `${r.left}px`;
        root.style.top = `${top}px`;
    }

    // Follow the cards as they appear / disappear / change size
    if (nav && window.ResizeObserver) new ResizeObserver(() => place()).observe(nav);

    // Plain fade: fade out, then free the spot once it's invisible; take the spot, then fade in.
    const FADE = 300; // ms, matches the opacity transition in status.css
    function visible(it, on) {
        if (on === !it.el.classList.contains('off')) return;
        clearTimeout(it.hideTimer);
        if (on) {
            it.el.classList.remove('gone');
            void it.el.offsetWidth; // let it render at opacity 0 first so the fade-in runs
            it.el.classList.remove('off');
        } else {
            it.el.classList.add('off');
            it.hideTimer = setTimeout(() => it.el.classList.add('gone'), FADE);
        }
    }

    function set(name, v) {
        const it = items[name];
        if (typeof v !== 'number' || v === it.v) return;
        it.v = v;
        visible(it, v >= 0);
        if (v < 0) return;
        const p = Math.max(0, Math.min(100, v)) / 100;
        it.rect.setAttribute('y', it.ic.y1 - (it.ic.y1 - it.ic.y0) * p);
        it.el.classList.toggle('low', name !== 'voice' && v <= LOW);
    }

    // Voice: state from mic.lua. Shown all the time (or only while talking, see Config.Voice),
    // glyph filled to the range: 1/3 whisper, 2/3 normal, full shout.
    let voice = null;
    function applyVoice() {
        if (!voice) return;
        const it = items.voice;
        const live = voice.state === 'talk' || voice.state === 'radio';
        it.el.classList.toggle('talk', live);
        it.el.classList.toggle('radio', voice.state === 'radio');
        it.el.classList.toggle('mic-off', voice.state === 'off');
        set('voice', voice.visible ? Math.round(Math.max(0, Math.min(1, voice.level)) * 100) : -1);
    }

    window.addEventListener('message', (e) => {
        const d = e.data;
        if (!d) return;

        if (d.type === 'edit') {
            editing = !!d.state;
            requestAnimationFrame(place);
        } else if (d.type === 'layout' && d.status) {
            if (d.status.scale > 0) root.style.setProperty('--k', d.status.scale);
            requestAnimationFrame(place);
        } else if (d.type === 'mic') {
            voice = d.show === false ? null : d;
            if (!voice) set('voice', -1);
            else applyVoice();
        } else if (d.type === 'status' && d.state) {
            const s = d.state;
            root.classList.toggle('st-hidden', !s.show);
            if (!s.show) return;
            noMap = !!s.noMap;
            if (typeof s.drop === 'number') drop = s.drop;
            ORDER.forEach((n) => { if (n !== 'voice') set(n, s[n]); });
            applyVoice();
            place();
        }
    });

    window.addEventListener('resize', place);
})();
