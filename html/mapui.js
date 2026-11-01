// Frame around GTA's screens opened from the pause menu, see pause.lua (frameUi / mapInfo).
// mode 'map' = waypoint card + map keys; 'settings' / 'keys' = bar over GTA's title bar + menu keys.
(() => {
    const root = document.getElementById('mapui');
    const $ = (s) => root.querySelector(s);
    const cardEl = $('.mu-card');
    const distEl = $('.mu-dist b');
    const unitEl = $('.mu-dist small');
    const hintsEl = $('.mu-hints');
    const nowEl = $('.mu-now');

    const MODES = {
        map: {
            hints: [[['PgUp', 'PgDn'], 'Zoom'], [['↑', '↓'], 'Legend'], [['Enter'], 'Waypoint'], [['Esc'], 'Back']],
        },
        settings: {
            title: 'Settings',
            hints: [[['↑', '↓'], 'Select'], [['←', '→'], 'Change'], [['Esc'], 'Back']],
        },
        keys: {
            title: 'Key Bindings',
            hints: [[['↑', '↓'], 'Select'], [['Enter'], 'Rebind'], [['Esc'], 'Back']],
        },
    };

    let mode = null;

    const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

    function setMode(m) {
        const def = MODES[m];
        if (!def) return;
        mode = m;
        root.classList.toggle('mu-m-map', m === 'map');
        root.classList.toggle('mu-m-page', !!def.title);
        nowEl.textContent = def.title || '';
        hintsEl.innerHTML = def.hints
            .map(([keys, label]) => `<span>${keys.map((k) => `<i class="mu-key">${esc(k)}</i>`).join('')}${esc(label)}</span>`)
            .join('');
    }

    function renderMap(d) {
        if (!d) return;
        const wp = d.wp;
        cardEl.classList.toggle('mu-nowp', !wp);
        distEl.textContent = wp ? wp.dist : 'None';
        unitEl.textContent = wp ? wp.unit : '';
    }

    window.addEventListener('message', (e) => {
        const d = e.data;
        if (!d || d.type !== 'mapui') return;
        if (!d.show) {
            root.classList.add('mu-hidden');
            return;
        }
        if (typeof d.mode === 'string' && d.mode !== mode) setMode(d.mode);
        if (typeof d.m === 'number') root.style.setProperty('--m', d.m);
        if (mode === 'map') renderMap(d.info);
        root.classList.remove('mu-hidden');
    });
})();
