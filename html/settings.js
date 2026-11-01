// HUD settings menu (/hud). Options and values come from settings.lua; every change is sent
// straight back (settingsSet) so the HUD updates live while the menu is open.
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'vi-hud';
    const post = (name, data = {}) =>
        fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        }).then((r) => r.json()).catch(() => ({}));

    const root = document.getElementById('settings');
    const tabsEl = root.querySelector('.hs-tabs');
    const listEl = root.querySelector('.hs-list');
    const descEl = root.querySelector('.hs-desc');
    const cmdEl = root.querySelector('.hs-cmd');
    const resetBtn = root.querySelector('.hs-reset');
    const closeBtn = root.querySelector('.hs-close');

    const ARROW_L = '<svg viewBox="0 0 24 24"><path d="M16 4 7 12l9 8z"/></svg>';
    const ARROW_R = '<svg viewBox="0 0 24 24"><path d="M8 4l9 8-9 8z"/></svg>';

    const asArray = (v) => (Array.isArray(v) ? v : v && typeof v === 'object' ? Object.values(v) : []);

    let tabs = [];
    let tab = 0;
    let sel = 0;
    let isOpen = false;
    let rows = []; // row elements of the current tab

    // ------------------------------------------------------------ values

    const same = (a, b) => (typeof a === 'number' && typeof b === 'number' ? Math.abs(a - b) < 1e-6 : a === b);

    function fmt(o, v) {
        if (o.kind === 'slider') {
            if (o.fmt === 'pct') return `${Math.round(v)}%`;
            if (o.fmt === 'frac') return `${Math.round(v * 100)}%`;
            if (o.fmt === 'x') return `${(+v).toFixed(2).replace(/0$/, '')}×`;
            return String(v);
        }
        return String(v);
    }

    function stepSlider(o, v, dir) {
        const n = Math.round((v + dir * o.step - o.min) / o.step);
        const out = o.min + n * o.step;
        return Math.round(Math.min(o.max, Math.max(o.min, out)) * 1000) / 1000;
    }

    function setValue(o, v) {
        if (same(o.value, v)) return;
        o.value = v;
        refreshRow(o);
        post('settingsSet', { id: o.id, value: v }).then((r) => {
            if (r && r.value !== undefined && !same(r.value, o.value)) {
                o.value = r.value;
                refreshRow(o);
            }
        });
    }

    function change(o, dir) {
        if (o.kind === 'toggle') setValue(o, dir === 0 ? !o.value : dir > 0);
        else if (o.kind === 'choice') {
            const list = asArray(o.choices);
            let i = list.findIndex((c) => c.value === o.value);
            i = (i + (dir || 1) + list.length) % list.length;
            setValue(o, list[i].value);
        } else if (o.kind === 'slider') {
            if (dir !== 0) setValue(o, stepSlider(o, o.value, dir));
        } else if (o.kind === 'action' && dir === 0) {
            post('settingsAction', { id: o.id });
        }
    }

    // ------------------------------------------------------------ render

    function valueHtml(o) {
        if (o.kind === 'toggle') {
            return `<div class="hs-toggle"><span data-v="0" class="${o.value ? '' : 'on'}">Off</span><span data-v="1" class="${o.value ? 'on' : ''}">On</span></div>`;
        }
        if (o.kind === 'choice') {
            const c = asArray(o.choices).find((x) => x.value === o.value);
            return `<div class="hs-arrow" data-d="-1">${ARROW_L}</div><div class="hs-choice">${c ? c.label : ''}</div><div class="hs-arrow" data-d="1">${ARROW_R}</div>`;
        }
        if (o.kind === 'slider') {
            const f = (o.value - o.min) / (o.max - o.min);
            return `<div class="hs-slider"><div class="hs-meter"><i style="width:${Math.max(0, Math.min(1, f)) * 100}%"></i></div><div class="hs-num">${fmt(o, o.value)}</div></div>`;
        }
        if (o.kind === 'action') return `<div class="hs-btn">${o.button || 'Open'}</div>`;
        return '';
    }

    function options() {
        return tabs[tab] ? asArray(tabs[tab].options) : [];
    }

    function refreshRow(o) {
        const i = options().indexOf(o);
        const el = rows[i];
        if (!el) return;
        el.querySelector('.hs-value').innerHTML = valueHtml(o);
        el.classList.toggle('changed', o.kind !== 'action' && !same(o.value, o.default));
    }

    function select(i, scroll) {
        const opts = options();
        if (!opts.length) return;
        sel = (i + opts.length) % opts.length;
        rows.forEach((el, n) => el.classList.toggle('sel', n === sel));
        descEl.textContent = opts[sel].desc || '';
        if (scroll && rows[sel]) rows[sel].scrollIntoView({ block: 'nearest' });
    }

    function renderTabs() {
        const keyL = '<span class="hs-key" data-t="-1">Q</span>';
        const keyR = '<span class="hs-key" data-t="1">E</span>';
        tabsEl.innerHTML = keyL + tabs.map((t, i) => `<div class="hs-tab${i === tab ? ' on' : ''}" data-i="${i}"><span>${t.label}</span></div>`).join('') + keyR;
    }

    function renderList() {
        const opts = options();
        listEl.innerHTML = '';
        rows = opts.map((o, i) => {
            const el = document.createElement('div');
            el.className = 'hs-row';
            el.style.animationDelay = `${i * 0.018}s`;
            el.innerHTML = `<div class="hs-label">${o.label}</div><div class="hs-value"></div>`;
            listEl.appendChild(el);
            return el;
        });
        opts.forEach(refreshRow);
        select(Math.min(sel, opts.length - 1), true);
    }

    function setTab(i) {
        if (!tabs.length) return;
        tab = (i + tabs.length) % tabs.length;
        sel = 0;
        renderTabs();
        renderList();
    }

    // ------------------------------------------------------------ mouse

    tabsEl.addEventListener('click', (e) => {
        const t = e.target.closest('[data-i]');
        if (t) return setTab(+t.dataset.i);
        const k = e.target.closest('[data-t]');
        if (k) setTab(tab + +k.dataset.t);
    });

    let dragging = null; // { o, meter }

    function sliderFromX(o, meter, x) {
        const r = meter.getBoundingClientRect();
        const f = Math.min(1, Math.max(0, (x - r.left) / r.width));
        setValue(o, stepSlider(o, o.min + f * (o.max - o.min), 0));
    }

    listEl.addEventListener('mouseover', (e) => {
        const row = e.target.closest('.hs-row');
        if (row && !dragging) select(rows.indexOf(row), false);
    });

    listEl.addEventListener('mousedown', (e) => {
        const row = e.target.closest('.hs-row');
        if (!row) return;
        const o = options()[rows.indexOf(row)];
        if (!o) return;

        const meter = e.target.closest('.hs-meter');
        if (meter && o.kind === 'slider') {
            dragging = { o, meter };
            sliderFromX(o, meter, e.clientX);
            return;
        }
        const arrow = e.target.closest('.hs-arrow');
        if (arrow) return change(o, +arrow.dataset.d);
        const seg = e.target.closest('.hs-toggle span');
        if (seg) return setValue(o, seg.dataset.v === '1');
        if (o.kind !== 'slider') change(o, 0);
    });

    window.addEventListener('mousemove', (e) => {
        if (dragging) sliderFromX(dragging.o, dragging.meter, e.clientX);
    });
    window.addEventListener('mouseup', () => { dragging = null; });

    // ------------------------------------------------------------ keys

    window.addEventListener('keydown', (e) => {
        if (!isOpen) return;
        const o = options()[sel];
        switch (e.key) {
            case 'ArrowUp': select(sel - 1, true); break;
            case 'ArrowDown': select(sel + 1, true); break;
            case 'ArrowLeft': if (o) change(o, -1); break;
            case 'ArrowRight': if (o) change(o, 1); break;
            case 'Enter': case ' ': if (o) change(o, 0); break;
            case 'q': case 'Q': case 'PageUp': setTab(tab - 1); break;
            case 'e': case 'E': case 'PageDown': setTab(tab + 1); break;
            case 'Backspace': if (o && o.kind !== 'action') setValue(o, o.default); break;
            case 'Escape': post('settingsClose'); break;
            default: return;
        }
        e.preventDefault();
    });

    // ------------------------------------------------------------ buttons

    let confirmUntil = 0;
    resetBtn.addEventListener('click', () => {
        if (Date.now() > confirmUntil) {
            confirmUntil = Date.now() + 3000;
            resetBtn.textContent = 'Click again to reset';
            resetBtn.classList.add('confirm');
            setTimeout(() => {
                if (Date.now() >= confirmUntil) {
                    resetBtn.textContent = 'Reset all';
                    resetBtn.classList.remove('confirm');
                }
            }, 3050);
            return;
        }
        confirmUntil = 0;
        resetBtn.textContent = 'Reset all';
        resetBtn.classList.remove('confirm');
        post('settingsReset').then((r) => {
            if (r && r.tabs) {
                tabs = asArray(r.tabs);
                setTab(Math.min(tab, tabs.length - 1));
            }
        });
    });

    closeBtn.addEventListener('click', () => post('settingsClose'));

    // ------------------------------------------------------------ messages

    window.addEventListener('message', (e) => {
        const d = e.data;
        if (!d || d.type !== 'settings') return;
        if (d.action === 'open') {
            tabs = asArray(d.tabs).map((t) => ({ ...t, options: asArray(t.options) }));
            if (cmdEl && d.command) cmdEl.textContent = `/${d.command}`;
            isOpen = true;
            root.classList.remove('hs-hidden');
            setTab(Math.min(tab, tabs.length - 1)); // reopens on the last tab used
        } else if (d.action === 'close') {
            isOpen = false;
            dragging = null;
            root.classList.add('hs-hidden');
        }
    });
})();
