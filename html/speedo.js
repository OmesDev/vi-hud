// GTA VI style speedometer. State comes from speedo.lua.
(() => {
    const root = document.getElementById('speedo');
    const NS = 'http://www.w3.org/2000/svg';

    // Arc: 240 degrees, gap at the bottom. Circle r=45 in a 100x100 box, rotated so the stroke
    // starts bottom-left (150 deg from 3 o'clock) and runs clockwise.
    const R = 45;
    const C = 2 * Math.PI * R;
    const SWEEP = 240;
    const ARC = (C * SWEEP) / 360;
    const START = 150;

    const svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('viewBox', '0 0 100 100');
    svg.setAttribute('class', 'sp-arc');

    function circle(cls, width) {
        const c = document.createElementNS(NS, 'circle');
        c.setAttribute('class', cls);
        c.setAttribute('cx', 50);
        c.setAttribute('cy', 50);
        c.setAttribute('r', R);
        c.setAttribute('fill', 'none');
        c.setAttribute('stroke-width', width);
        c.setAttribute('transform', `rotate(${START} 50 50)`);
        svg.appendChild(c);
        return c;
    }

    const track = circle('sp-track', 3.2);
    track.setAttribute('stroke-dasharray', `${ARC} ${C}`);
    const red = circle('sp-red', 3.2);
    const rpm = circle('sp-rpm', 3.2);
    rpm.setAttribute('stroke-dasharray', `0 ${C}`);

    // Ticks every 1/8 of the sweep, just inside the arc
    const ticks = document.createElementNS(NS, 'g');
    ticks.setAttribute('class', 'sp-ticks');
    for (let i = 0; i <= 8; i++) {
        const a = ((START + (SWEEP * i) / 8) * Math.PI) / 180;
        const r1 = 39.2;
        const r2 = i % 2 === 0 ? 41.6 : 40.8;
        const l = document.createElementNS(NS, 'line');
        l.setAttribute('x1', 50 + Math.cos(a) * r1);
        l.setAttribute('y1', 50 + Math.sin(a) * r1);
        l.setAttribute('x2', 50 + Math.cos(a) * r2);
        l.setAttribute('y2', 50 + Math.sin(a) * r2);
        ticks.appendChild(l);
    }
    svg.appendChild(ticks);
    root.prepend(svg);

    const speedEl = root.querySelector('.sp-speed');
    const unitEl = root.querySelector('.sp-unit');
    const gearEl = root.querySelector('.sp-gear');
    const RING_C = 2 * Math.PI * 22.5;
    function ring(sel) {
        const el = root.querySelector(sel);
        const fill = el.querySelector('.sp-ring-fill');
        fill.setAttribute('stroke-dasharray', `0 ${RING_C}`);
        return (pct) => {
            el.classList.toggle('off', pct < 0);
            if (pct < 0) return;
            const v = Math.max(0, Math.min(100, pct)) / 100;
            fill.setAttribute('stroke-dasharray', `${RING_C * v} ${RING_C}`);
            el.classList.toggle('low', pct <= LOW);
        };
    }
    const LOW = 15; // % at which a ring turns pink
    const setEngine = ring('.sp-engine');
    const setFuel = ring('.sp-fuel');
    const setBelt = ring('.sp-belt'); // -1 = hidden, 0 = unbuckled, 1 = buckled
    const beltEl = root.querySelector('.sp-belt');

    // Minimal style: sits just right of the minimap panel, level with its bottom edge
    // (the altitude line grows it upwards, the icon row stays put)
    const panel = document.getElementById('minimap');
    const altEl = root.querySelector('.sp-alt');
    const altVal = root.querySelector('.sp-alt-v');
    let minimal = false;
    // place() reads the layout (forces a reflow), so it only runs when the panel or the window
    // changed since the last time; the panel is positioned through its inline style (script.js)
    let placedKey = null;

    function place() {
        if (!minimal || !panel) return;
        const key = `${panel.style.cssText}|${window.innerWidth}x${window.innerHeight}`;
        if (key === placedKey) return;
        placedKey = key;
        const r = panel.getBoundingClientRect();
        const gap = parseFloat(getComputedStyle(root).getPropertyValue('--gap')) || 16;
        root.style.left = `${r.right + gap}px`;
        root.style.bottom = `${window.innerHeight - r.bottom}px`;
    }

    // The gear sits in the gap at the bottom of the gauge, or above the speed in the minimal style
    // (beside the speed it'd jump around as the digits change)
    function setStyle(style) {
        const m = style === 'minimal';
        if (m === minimal) return;
        minimal = m;
        placedKey = null;
        root.classList.toggle('sp-minimal', m);
        if (m) root.prepend(gearEl);
        else root.appendChild(gearEl);
        if (!m) {
            root.style.left = '';
            root.style.bottom = '';
        }
    }

    window.addEventListener('resize', place);
    window.addEventListener('message', (e) => {
        if (e.data && e.data.type === 'layout') requestAnimationFrame(place);
    });

    let redline = -1;
    function setRedline(v) {
        if (v === redline) return;
        redline = v;
        red.setAttribute('stroke-dasharray', `0 ${ARC * v} ${ARC * (1 - v)} ${C}`);
    }

    window.addEventListener('message', (e) => {
        const d = e.data;
        if (!d || d.type !== 'speedo') return;

        if (d.show === false) {
            root.classList.add('sp-hidden');
            return;
        }
        if (typeof d.margin === 'number') root.style.setProperty('--m', d.margin);
        if (typeof d.style === 'string') setStyle(d.style);
        if (typeof d.alt === 'number') {
            altEl.classList.toggle('off', d.alt < 0);
            if (d.alt >= 0) altVal.textContent = d.alt;
        }
        if (typeof d.redline === 'number') setRedline(d.redline);
        if (d.units) unitEl.textContent = d.units;
        if (typeof d.speed === 'number') speedEl.textContent = d.speed;
        if (typeof d.gear === 'string') gearEl.textContent = d.gear;

        if (typeof d.rpm === 'number') {
            root.classList.toggle('sp-norpm', d.rpm < 0);
            const v = Math.max(0, Math.min(1, d.rpm));
            rpm.setAttribute('stroke-dasharray', `${ARC * v} ${C}`);
            root.classList.toggle('sp-redline', d.rpm >= redline);
        }
        if (typeof d.engine === 'number') setEngine(d.engine);
        if (typeof d.fuel === 'number') setFuel(d.fuel);
        if (typeof d.belt === 'number') {
            setBelt(d.belt < 0 ? -1 : 100);
            beltEl.classList.toggle('unbuckled', d.belt === 0);
        }
        if (d.show === true) {
            place();
            root.classList.remove('sp-hidden');
        }
    });
})();
