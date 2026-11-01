// GTA VI style radio station strip. State comes from radio.lua.
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'vi-hud';
    const root = document.getElementById('radio');
    const tilesEl = root.querySelector('.rs-tiles');
    const nameEl = root.querySelector('.rs-name');
    const titleEl = root.querySelector('.rs-title');
    const artistEl = root.querySelector('.rs-artist');

    const SIDE = 2; // tiles shown either side of the selected one

    // ------------------------------------------------------------- logos
    // Generated tiles for stations without a PNG in html/stations/<NAME>.png

    const BC = 'Barlow Condensed';
    const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
    const t = (text, size, font, color, css = '') =>
        `<span style="font-family:'${font}';font-size:calc(var(--tile) * ${size});color:${color};${font === 'Anton' ? 'line-height:1.18;' : ''}${css}">${esc(text)}</span>`;
    const wide = (ls, w = 700) => `font-weight:${w};letter-spacing:${ls}em`;

    const LOGOS = {
        RADIO_01_CLASS_ROCK: { bg: '#161618', html: t('LOS SANTOS', 0.12, BC, '#fff', wide(0.06)) + t('ROCK', 0.36, 'Anton', '#e8402f') + t('RADIO', 0.17, BC, '#fff', wide(0.12, 800)) },
        RADIO_02_POP: { bg: 'linear-gradient(140deg, #ff6aa8, #f2306f)', html: `<div style="transform:rotate(-8deg)">${t('NON', 0.19, 'Bungee', '#fff') + t('STOP', 0.22, 'Bungee', '#fff') + t('POP', 0.26, 'Bungee', '#ffe45c')}</div>` },
        RADIO_03_HIPHOP_NEW: { bg: '#0d0d0d', html: t('RADIO', 0.12, BC, '#fff', wide(0.2)) + t('Los Santos', 0.16, 'Pacifico', '#f2c14e', 'line-height:1.3') },
        RADIO_04_PUNK: { bg: '#ededed', html: t('X', 0.66, 'Rubik Mono One', '#111') + `<div style="position:absolute;left:0;right:0;top:41%;height:20%;background:#d32a2a;display:flex;align-items:center;justify-content:center">${t('CHANNEL', 0.15, BC, '#fff', wide(0.1, 800))}</div>` },
        RADIO_05_TALK_01: { bg: '#1f3a63', html: t('WCTR', 0.3, 'Anton', '#fff') + t('WEST COAST', 0.1, BC, '#cfe0ff', wide(0.08) + ';margin-top:4%') + t('TALK RADIO', 0.1, BC, '#cfe0ff', wide(0.08)) },
        RADIO_06_COUNTRY: { bg: '#6e1b12', html: t('REBEL', 0.25, 'Rye', '#f3e3c0') + t('RADIO', 0.15, 'Rye', '#f3e3c0', 'margin-top:4%') },
        RADIO_07_DANCE_01: { bg: '#000', html: t('SOULWAX', 0.17, 'Bebas Neue', '#fff', 'letter-spacing:0.04em') + t('FM', 0.28, 'Bebas Neue', '#ffd500') },
        RADIO_08_MEXICAN: { bg: '#0e4d33', html: t('EL', 0.46, 'UnifrakturMaguntia', '#fff') + t('EAST LOS FM', 0.1, BC, '#d8f0e2', wide(0.08)) },
        RADIO_09_HIPHOP_OLD: { bg: '#ece0c6', html: t('WEST COAST', 0.15, BC, '#1d1d1d', 'font-weight:800') + t('CLASSICS', 0.19, 'Anton', '#c4262e') },
        RADIO_11_TALK_02: { bg: '#31502f', html: t('BLAINE', 0.19, 'Rye', '#f1e6c8') + t('COUNTY', 0.19, 'Rye', '#f1e6c8') + t('TALK RADIO', 0.09, BC, '#d9caa0', wide(0.1) + ';margin-top:5%') },
        RADIO_12_REGGAE: { bg: '#1a4c9c', html: t('THE', 0.11, BC, '#ffd23f', 'font-weight:700') + t('BLUE', 0.24, 'Righteous', '#fff') + t('ARK', 0.24, 'Righteous', '#ffd23f') },
        RADIO_13_JAZZ: { bg: '#f3efe6', html: t('WORLDWIDE', 0.16, BC, '#111', wide(0.02, 800)) + `<span style="margin-top:6%;width:calc(var(--tile) * 0.24);height:calc(var(--tile) * 0.24);border-radius:50%;background:#111;display:flex;align-items:center;justify-content:center">${t('FM', 0.12, BC, '#f3efe6', 'font-weight:800')}</span>` },
        RADIO_14_DANCE_02: { bg: '#ffd400', html: t('FLYLO', 0.3, 'Anton', '#111') + t('FM', 0.2, 'Anton', '#111') },
        RADIO_15_MOTOWN: { bg: '#4b2378', html: t('THE', 0.1, BC, '#f6c9ff', wide(0.14)) + t('Lowdown', 0.19, 'Pacifico', '#fff', 'line-height:1.3') + t('91.1', 0.14, BC, '#f6c9ff', 'font-weight:800') },
        RADIO_16_SILVERLAKE: { bg: '#cfe8ee', html: t('RADIO', 0.13, BC, '#2b5866', wide(0.1, 800)) + t('MIRROR', 0.2, 'Permanent Marker', '#e0447a') + t('PARK', 0.2, 'Permanent Marker', '#e0447a') },
        RADIO_17_FUNK: { bg: 'radial-gradient(circle at 50% 40%, #3b1670, #150727)', html: t('SPACE', 0.17, 'Monoton', '#ff7ad9') + t('103.2', 0.14, BC, '#fff', 'font-weight:700;margin-top:6%') },
        RADIO_18_90S_ROCK: { bg: '#f4f4f4', html: t('VINEWOOD', 0.18, 'Anton', '#111') + t('BOULEVARD', 0.12, BC, '#c62828', wide(0.06, 800)) + t('RADIO', 0.12, BC, '#111', wide(0.2, 800)) },
        RADIO_19_USER: { bg: '#2d2d30', html: t('SELF', 0.24, 'Anton', '#fff') + t('RADIO', 0.15, BC, '#9ad0ff', wide(0.12, 800)) },
        RADIO_20_THELAB: { bg: '#0b0b0b', html: t('THE', 0.12, 'Black Ops One', '#a6ff3d') + t('LAB', 0.32, 'Black Ops One', '#a6ff3d') },
        RADIO_21_DLC_XM17: { bg: '#f5efe1', html: t('blonded', 0.22, 'Playfair Display', '#222', 'font-style:italic;font-weight:700') + t('LOS SANTOS 97.8 FM', 0.08, BC, '#555', wide(0.08) + ';margin-top:6%') },
        RADIO_22_DLC_BATTLE_MIX1_RADIO: { bg: '#0f141b', html: t('LS', 0.28, 'Rubik Mono One', '#fff') + t('UR', 0.28, 'Rubik Mono One', '#5ad1ff') },
        RADIO_23_DLC_XM19_RADIO: { bg: '#e33a4d', html: t('iFruit', 0.24, 'Righteous', '#fff') + t('RADIO', 0.12, BC, '#ffe0e4', wide(0.14, 800)) },
        RADIO_27_DLC_PRHEI4: { bg: '#0b0b0b', html: t('STILL', 0.2, 'Anton', '#fff') + t('SLIPPING', 0.18, 'Anton', '#ff3d3d') + t('LOS SANTOS', 0.08, BC, '#bbb', wide(0.14) + ';margin-top:4%') },
        RADIO_34_DLC_HEI4_KULT: { bg: '#cbb57f', html: t('K.U.L.T.', 0.2, 'Anton', '#2a2216') + t('99.1 FM', 0.12, BC, '#2a2216', 'font-weight:800') },
        RADIO_35_DLC_HEI4_MLR: { bg: '#121212', html: t('THE MUSIC', 0.12, BC, '#d4af37', wide(0.12)) + t('LOCKER', 0.24, 'Anton', '#d4af37') },
        RADIO_36_AUDIOPLAYER: { bg: '#262629', html: t('▶', 0.3, 'Arial', '#fff') + t('MEDIA PLAYER', 0.1, BC, '#ddd', wide(0.08) + ';margin-top:4%') },
        RADIO_37_MOTOMAMI: { bg: '#e3001b', html: t('MOTOMAMI', 0.17, 'Anton', '#fff') + t('LOS SANTOS', 0.09, BC, '#fff', wide(0.14)) },
    };

    function fallbackLogo(s) {
        let h = 0;
        for (const c of s.name) h = (h * 31 + c.charCodeAt(0)) % 360;
        const words = String(s.label).toUpperCase().split(/\s+/).slice(0, 3);
        return {
            bg: `hsl(${h}, 42%, 26%)`,
            html: words.map((w) => t(w, w.length > 7 ? 0.13 : 0.17, BC, '#fff', 'font-weight:800')).join(''),
        };
    }

    // ------------------------------------------------------------- state

    let stations = [];
    let tiles = [];
    let st = { show: false, sel: 0, muted: false, playing: null, title: null, artist: null };

    function buildTiles() {
        tilesEl.innerHTML = '';
        tiles = stations.map((s) => {
            const el = document.createElement('div');
            el.className = 'rs-tile rs-jump rs-out';
            const logo = LOGOS[s.name] || fallbackLogo(s);
            el.innerHTML = `<div class="rs-logo" style="background:${logo.bg}">${logo.html}</div>`;

            // Custom PNG wins if there is one
            const img = new Image();
            img.onload = () => el.appendChild(img);
            img.src = `stations/${s.name}.png`;

            tilesEl.appendChild(el);
            return el;
        });
    }

    function render(instant) {
        const n = stations.length;
        const side = Math.min(SIDE, Math.floor((n - 1) / 2));

        tiles.forEach((el, i) => {
            let off = (((i - st.sel) % n) + n) % n;
            if (off > n / 2) off -= n;
            // tiles out of view wait just past either end, so they slide in from there
            const park = Math.max(-(side + 1), Math.min(side + 1, off));
            const prev = el._park;
            el.classList.toggle('rs-jump', instant || prev === undefined || Math.abs(park - prev) > 1);
            el.style.setProperty('--off', park);
            el.classList.toggle('rs-out', Math.abs(off) > side);
            el.classList.toggle('rs-sel', off === 0 && !st.muted);
            el._park = park;
        });

        const s = stations[st.sel];
        const live = !st.muted && s && s.name === st.playing;
        nameEl.textContent = st.muted ? 'Radio Off' : s ? s.label : '';
        titleEl.textContent = (live && st.title) || '';
        artistEl.textContent = (live && st.artist) || '';
        root.classList.toggle('rs-muted', !!st.muted);
    }

    window.addEventListener('message', (e) => {
        const d = e.data;
        if (!d || d.type !== 'radio') return;

        if (d.action === 'stations') {
            stations = Array.isArray(d.stations) ? d.stations : [];
            buildTiles();
            if (stations.length) render(true);
        } else if (d.action === 'state') {
            const was = st.show;
            st = { ...st, ...d.state };
            if (stations.length && st.sel >= stations.length) st.sel = 0;
            if (st.show && stations.length) render(!was);
            root.classList.toggle('rs-hidden', !st.show || !stations.length);
        }
    });

    fetch(`https://${RES}/radioReady`, { method: 'POST', body: '{}' }).catch(() => {});
})();
