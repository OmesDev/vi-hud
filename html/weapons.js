// GTA VI style weapon wheel. State comes from weapons.lua.
(() => {
    const root = document.getElementById('wheel');
    const tilesEl = root.querySelector('.ww-tiles');
    const nameEl = root.querySelector('.ww-name');
    const catEl = root.querySelector('.ww-cat');
    const keyEl = root.querySelector('.ww-key');
    const tabW = root.querySelector('.ww-tab-w');
    const tabI = root.querySelector('.ww-tab-i');
    const invDim = document.getElementById('invdim');

    function setTabs(items, key, active) {
        root.classList.toggle('ww-hasitems', !!items);
        keyEl.textContent = items && typeof key === 'string' ? key : '';
        tabW.classList.toggle('on', active === 'weapons');
        tabI.classList.toggle('on', active === 'items');
    }

    // Tile centres relative to the wheel centre (in --u), clockwise from the top.
    // Measured off the reference frame; slot order matches SLOT_ANGLE in weapons.lua.
    const POS = [
        [0, -14.24], [11.98, -8.93], [15.13, 0], [11.98, 9.01],
        [0, 13.81], [-11.98, 9.01], [-15.13, 0], [-12.05, -8.93],
    ];

    const tiles = POS.map(([x, y]) => {
        const el = document.createElement('div');
        el.className = 'ww-tile';
        el.style.setProperty('--x', x);
        el.style.setProperty('--y', y);
        el.innerHTML = '<div class="ww-art"></div><div class="ww-strip"><span></span></div><div class="ww-dots"></div>';
        tilesEl.appendChild(el);
        return {
            el,
            art: el.querySelector('.ww-art'),
            strip: el.querySelector('.ww-strip span'),
            dots: el.querySelector('.ww-dots'),
            shown: null, // weapon name whose icon is in the tile
            n: -1,
        };
    });

    let slots = [];
    let hover = -1;
    let iconUrls = []; // url templates to try after html/weapons/ (%s = lowercase name, %S = uppercase)

    const asArray = (v) => (Array.isArray(v) ? v : v && typeof v === 'object' ? Object.values(v) : []);

    // ------------------------------------------------------------- icons

    const resolved = {}; // weapon name -> working url, or '' when nothing loads

    function sources(name) {
        const list = [`weapons/${name}.png`];
        for (const u of iconUrls) list.push(u.replace(/%s/g, name.toLowerCase()).replace(/%S/g, name));
        return list;
    }

    function showAlt(t, item) {
        const alt = document.createElement('div');
        alt.className = 'ww-alt';
        alt.textContent = item.label;
        t.art.replaceChildren(alt);
    }

    function setIcon(t, item) {
        if (!item) {
            t.shown = null;
            t.art.replaceChildren();
            return;
        }
        if (t.shown === item.name) return;
        t.shown = item.name;

        const known = resolved[item.name];
        if (known === '') return showAlt(t, item);

        const img = new Image();
        img.alt = '';
        // Already trimmed (icons.js): straight in, no swap
        const trimmed = known && IconTrim.get(known);
        if (trimmed) {
            img.src = trimmed;
            t.art.replaceChildren(img);
            return;
        }
        const list = known ? [known] : sources(item.name);
        let i = 0;
        img.onerror = () => {
            if (t.shown !== item.name) return;
            i += 1;
            if (i < list.length) img.src = list[i];
            else {
                resolved[item.name] = '';
                showAlt(t, item);
            }
        };
        img.onload = () => {
            if (img.src.startsWith('data:')) return; // the trimmed copy
            const url = list[i];
            resolved[item.name] = url;
            IconTrim.load(url).then((src) => {
                if (t.shown === item.name && src !== url) img.src = src;
            });
        };
        img.src = list[0];
        t.art.replaceChildren(img);
    }

    // ------------------------------------------------------------ render

    function ammoText(item) {
        if (item.clip >= 0) return `${item.clip} ${item.reserve}`;
        if (item.count >= 0) return `${item.count}`;
        return '';
    }

    function render() {
        tiles.forEach((t, s) => {
            const slot = slots[s] || { items: [], idx: 0 };
            const items = slot.items;
            const item = items[slot.idx] || null;
            const ammo = item ? ammoText(item) : '';

            t.el.classList.toggle('ww-has', !!item);
            t.el.classList.toggle('ww-ammo', ammo !== '');
            t.el.classList.toggle('ww-sel', s === hover && !!item);
            t.el.classList.toggle('ww-eq', !!(item && item.equipped));
            t.el.classList.toggle('ww-last', !!(item && item.last && !item.equipped));
            t.strip.textContent = ammo;
            setIcon(t, item);

            if (t.n !== items.length) {
                t.n = items.length;
                t.dots.innerHTML = items.length > 1 ? '<i></i>'.repeat(items.length) : '';
            }
            Array.from(t.dots.children).forEach((d, i) => d.classList.toggle('on', i === slot.idx));
        });

        const slot = slots[hover];
        const item = slot && slot.items[slot.idx];
        nameEl.textContent = item ? item.label : '';
        catEl.textContent = item ? item.cat : '';
    }

    window.addEventListener('message', (e) => {
        const d = e.data;
        if (!d || d.type !== 'wheel') return;

        if (d.action === 'open') {
            iconUrls = (typeof d.iconUrl === 'string' ? [d.iconUrl] : asArray(d.iconUrl)).filter((u) => typeof u === 'string' && u);
            slots = asArray(d.slots).map((s) => ({ items: asArray(s && s.items), idx: (s && s.idx) || 0 }));
            hover = typeof d.hover === 'number' ? d.hover : -1;
            root.classList.toggle('ww-notabs', d.tabs === false);
            root.classList.remove('ww-items');
            invDim.classList.remove('on'); // the wheel has its own (inventory is closing)
            setTabs(d.items, d.key, 'weapons');
            render();
            root.classList.remove('ww-hidden');
        } else if (d.action === 'select') {
            hover = typeof d.hover === 'number' ? d.hover : -1;
            asArray(d.idx).forEach((v, s) => { if (slots[s]) slots[s].idx = v; });
            render();
        } else if (d.action === 'items') {
            // just the header, over the inventory
            root.classList.remove('ww-notabs');
            root.classList.add('ww-items');
            setTabs(true, d.key, 'items');
            root.classList.remove('ww-hidden');
        } else if (d.action === 'invdim') {
            invDim.classList.toggle('on', !!d.on);
        } else if (d.action === 'close' || d.action === 'itemsoff') {
            root.classList.add('ww-hidden');
        }
    });
})();
