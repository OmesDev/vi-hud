const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'vi-hud';
const RADIUS_RATIO = 0.09; // must match RADIUS in client.lua

const $ = (id) => document.getElementById(id);
const root = $('minimap');
const arrow = $('arrow');
const north = $('north');
const distanceEl = $('distance');
const tintDay = $('tint-day');
const tintNight = $('tint-night');
const editor = $('editor');
const boundsEl = $('bounds');
const valuesEl = $('values');

// Screen fractions. x/y/w/h = frame, px/py = where GTA draws the player on the radar.
let layout = { x: 0.0, y: 0.8, w: 0.14, h: 0.14, px: 0.07, py: 0.95 };
// Area the map can be shown in (the minimap_blur component); the frame is kept inside it.
let bounds = null;
let units = 'mi';
let tilt = 0.66;
let stretch = 1.0; // horizontal stretch applied to GTA's radar (Config.StretchRadar)
let editing = false;
let layoutBeforeEdit = null;

// Angles (degrees, clockwise from "up" on the radar). target = latest from game, cur = smoothed.
const target = { north: 0, arrow: 0 };
const cur = { north: 0, arrow: 0 };

function post(name, data = {}) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => ({}));
}

// ------------------------------------------------------------------ layout

function px() {
    const W = window.innerWidth, H = window.innerHeight;
    return {
        x: layout.x * W, y: layout.y * H, w: layout.w * W, h: layout.h * H,
        px: layout.px * W, py: layout.py * H,
    };
}

function applyLayout() {
    const p = px();
    root.style.left = `${p.x}px`;
    root.style.top = `${p.y}px`;
    root.style.width = `${p.w}px`;
    root.style.height = `${p.h}px`;
    root.style.setProperty('--w', `${p.w}px`);
    root.style.setProperty('--h', `${p.h}px`);
    root.style.setProperty('--r', `${Math.min(p.h * RADIUS_RATIO, p.w / 2, p.h / 2)}px`);
    arrow.style.left = `${p.px - p.x}px`;
    arrow.style.top = `${p.py - p.y}px`;

    if (bounds) {
        const W = window.innerWidth, H = window.innerHeight;
        boundsEl.style.left = `${bounds.x * W}px`;
        boundsEl.style.top = `${bounds.y * H}px`;
        boundsEl.style.width = `${bounds.w * W}px`;
        boundsEl.style.height = `${bounds.h * H}px`;
    }
    if (editing) showValues(false);
    kick(); // the N marker's spot on the frame edge depends on the layout
}

window.addEventListener('resize', applyLayout);

// --------------------------------------------------- edge projection math

// Where a ray from the player in direction `deg` leaves the rounded frame. Frame-local px.
function edgePoint(deg) {
    const p = px();
    const hw = p.w / 2, hh = p.h / 2;
    const r = Math.min(p.h * RADIUS_RATIO, hw, hh);
    const ox = Math.max(-hw, Math.min(hw, p.px - p.x - hw));
    const oy = Math.max(-hh, Math.min(hh, p.py - p.y - hh));
    // The radar is tilted: forward/back distances are squashed on screen by `tilt`.
    // A straight ground line stays straight under perspective, so its on-screen
    // direction from the player is the world direction with the forward part scaled.
    const rad = (deg * Math.PI) / 180;
    const sx = Math.sin(rad) * stretch, sy = -Math.cos(rad) * tilt;
    const len = Math.hypot(sx, sy) || 1;
    const dx = sx / len, dy = sy / len;

    let t = Infinity;
    if (dx > 1e-6) t = Math.min(t, (hw - ox) / dx);
    if (dx < -1e-6) t = Math.min(t, (-hw - ox) / dx);
    if (dy > 1e-6) t = Math.min(t, (hh - oy) / dy);
    if (dy < -1e-6) t = Math.min(t, (-hh - oy) / dy);
    if (!isFinite(t)) t = 0;

    let x = ox + t * dx, y = oy + t * dy;

    if (Math.abs(x) > hw - r && Math.abs(y) > hh - r) {
        const cx = Math.sign(x) * (hw - r), cy = Math.sign(y) * (hh - r);
        const mx = ox - cx, my = oy - cy;
        const b = mx * dx + my * dy;
        const disc = b * b - (mx * mx + my * my - r * r);
        if (disc >= 0) {
            t = -b + Math.sqrt(disc);
            x = ox + t * dx;
            y = oy + t * dy;
        }
    }
    return { x: x + hw, y: y + hh };
}

// --------------------------------------------------------------- render

const wrap = (a) => ((a % 360) + 540) % 360 - 180; // -> [-180, 180)

// Runs while the angles are still easing towards their targets, then stops until the next
// update / layout change kicks it again (a page that redraws every frame costs the game FPS).
const ANGLES = Object.keys(cur);
const SETTLED = 0.01; // degrees
let raf = 0;
let last = 0;
function frameLoop(now) {
    raf = 0;
    const dt = last ? Math.min(0.1, (now - last) / 1000) : 1 / 60;
    last = now;
    const k = 1 - Math.exp(-dt * 18);
    let moving = false;
    for (const key of ANGLES) {
        const diff = wrap(target[key] - cur[key]);
        if (Math.abs(diff) < SETTLED) {
            cur[key] += diff; // land exactly on it (same angle, no jump)
        } else {
            cur[key] += diff * k;
            moving = true;
        }
    }

    const n = edgePoint(cur.north);
    north.style.transform = `translate(${n.x}px, ${n.y}px)`;

    arrow.style.transform = `rotate(${cur.arrow}deg)`;
    if (moving) raf = requestAnimationFrame(frameLoop);
    else last = 0;
}

function kick() {
    if (!raf) raf = requestAnimationFrame(frameLoop);
}
kick();

function formatDistance(m) {
    if (units === 'km') return `${(m / 1000).toFixed(2)} km`;
    return `${(m / 1609.344).toFixed(2)} mi`;
}

function onUpdate(d) {
    if (!d.visible) {
        root.classList.add('fade');
        return;
    }
    root.classList.remove('fade');

    // Radar "up" = gameplay camera heading. GTA headings are counter-clockwise from north,
    // screen angles here are clockwise from up, so screenAngle = cam - worldHeading.
    target.north = d.cam;
    // Pass the facing direction through the same tilt/stretch as the map so the arrow
    // stays parallel to the road it's driving along.
    const rel = ((d.cam - d.player) * Math.PI) / 180;
    target.arrow = (Math.atan2(Math.sin(rel) * stretch, Math.cos(rel) * tilt) * 180) / Math.PI;
    // The waypoint marker itself is a GTA blip (see client.lua), so GTA positions it.
    kick();

    if (typeof d.distance === 'number') {
        setText(distanceEl, formatDistance(d.distance));
        distanceEl.classList.remove('hidden');
    } else {
        distanceEl.classList.add('hidden');
    }

    updateNav(d);

    const night = Math.max(0, Math.min(1, d.night || 0));
    if (night !== lastNight) {
        lastNight = night;
        tintDay.style.opacity = 1 - night;
        tintNight.style.opacity = night;
    }
}

let lastNight = null;

// Only touch the DOM when the text actually changes
function setText(el, text) {
    if (el.textContent !== text) el.textContent = text;
}

// ------------------------------------------------- street bar + turn card

const streetEl = $('street');
const turnEl = $('turn');
const turnTitle = turnEl.querySelector('.turn-title');
const turnDist = turnEl.querySelector('.turn-dist');
const turnSvg = turnEl.querySelector('svg');

// [line, filled arrowhead] in a 24x24 box. Right-hand versions; left ones are mirrored.
const ICON = {
    straight: ['M12 21V10', 'M6.5 11 12 3.5l5.5 7.5z'],
    turn: ['M7.5 21v-7a5 5 0 0 1 5-5H15', 'M14.5 3.5 21.5 9l-7 5.5z'],
    sharp: ['M8 21V8l8 8', 'M20.5 20.5 11.5 19l7.5-7.5z'],
    uturn: ['M7.5 21.5V7.5a4.5 4.5 0 0 1 9 0V14', 'M11.5 13.5h10L16.5 21z'],
    flag: ['M6.5 21V4', 'M6.5 4h11l-2.5 4 2.5 4h-11z'],
};

// Instruction kinds sent by client.lua (GTA's satnav codes). mirror = flip the (right-hand) icon.
const TURNS = {
    left: { title: 'Turn Left', icon: 'turn', mirror: true },
    right: { title: 'Turn Right', icon: 'turn' },
    sharpleft: { title: 'Sharp Left', icon: 'sharp', mirror: true },
    sharpright: { title: 'Sharp Right', icon: 'sharp' },
    straight: { title: 'Continue Straight', icon: 'straight' },
    follow: { title: 'Follow the Route', icon: 'straight' },
    recalc: { title: 'Recalculating', icon: 'uturn' },
    arrived: { title: 'Arrived', icon: 'flag' },
};

function formatShort(m) {
    if (units === 'km') return m < 1000 ? `${Math.round(m / 10) * 10} m` : `${(m / 1000).toFixed(1)} km`;
    const ft = m * 3.28084;
    return ft < 1000 ? `${Math.round(ft)} ft` : `${(m / 1609.344).toFixed(1)} mi`;
}

let turnKey = '';

function updateNav(d) {
    if (d.street) {
        if (streetEl.textContent !== d.street) streetEl.textContent = d.street;
        streetEl.classList.remove('hidden');
    } else {
        streetEl.classList.add('hidden');
    }

    const t = d.turn;
    const info = t && TURNS[t.kind];
    if (!info) {
        turnEl.classList.add('hidden');
        return;
    }
    setText(turnTitle, info.title);
    // only turns carry a distance (GTA's is to the next junction, which only fits a turn)
    setText(turnDist, typeof t.dist === 'number' ? formatShort(t.dist) : '');

    const key = `${info.icon}:${!!info.mirror}`;
    if (key !== turnKey) {
        turnKey = key;
        const [line, head] = ICON[info.icon];
        const path = `<path d="${line}"/><path class="head" d="${head}"/>`;
        turnSvg.innerHTML = info.mirror ? `<g transform="translate(24 0) scale(-1 1)">${path}</g>` : path;
    }
    turnEl.classList.remove('hidden');
}

// ----------------------------------------------------------------- editor

function showValues(reveal) {
    const r = (v) => Math.round(v * 10000) / 10000;
    valuesEl.value =
        `Config.Layout = { x = ${r(layout.x)}, y = ${r(layout.y)}, w = ${r(layout.w)}, h = ${r(layout.h)}, ` +
        `px = ${r(layout.px)}, py = ${r(layout.py)}, scale = ${layout.scale || 1}, lift = ${r(layout.lift || 0)} }`;
    if (reveal) valuesEl.classList.remove('hidden');
}

function setEditing(state) {
    editing = state;
    root.classList.toggle('editing', state);
    editor.classList.toggle('hidden', !state);
    boundsEl.classList.toggle('hidden', !state);
    valuesEl.classList.add('hidden');
    if (state) {
        layoutBeforeEdit = { ...layout };
        root.classList.remove('fade');
        applyLayout();
    }
}

function closeEditor(save) {
    if (!save && layoutBeforeEdit) { layout = layoutBeforeEdit; applyLayout(); }
    setEditing(false);
    post('close', save ? { layout } : {});
}

// Ask the game to re-cut the map mask to the current frame (throttled).
let previewTimer = null, previewQueued = false;
function preview() {
    if (previewTimer) { previewQueued = true; return; }
    post('preview', { layout });
    previewTimer = setTimeout(() => {
        previewTimer = null;
        if (previewQueued) { previewQueued = false; preview(); }
    }, 120);
}

// Keep the frame inside the area the map can be drawn in.
function clampFrame() {
    if (!bounds) return;
    const minW = 80 / window.innerWidth, minH = 44 / window.innerHeight;
    layout.w = Math.max(minW, Math.min(layout.w, bounds.w));
    layout.h = Math.max(minH, Math.min(layout.h, bounds.h));
    layout.x = Math.max(bounds.x, Math.min(layout.x, bounds.x + bounds.w - layout.w));
    layout.y = Math.max(bounds.y, Math.min(layout.y, bounds.y + bounds.h - layout.h));
}

let drag = null;

root.addEventListener('mousedown', (e) => {
    if (!editing) return;
    const handle = e.target.closest('.handle');
    const onArrow = e.target.closest('#arrow');
    drag = {
        mode: handle ? handle.dataset.h : onArrow ? 'arrow' : 'move',
        sx: e.clientX, sy: e.clientY, start: { ...layout },
    };
    e.preventDefault();
});

window.addEventListener('mousemove', (e) => {
    if (!drag) return;
    const W = window.innerWidth, H = window.innerHeight;

    if (drag.mode === 'arrow') {
        layout.px = e.clientX / W;
        layout.py = e.clientY / H;
        applyLayout();
        return;
    }

    const dx = (e.clientX - drag.sx) / W, dy = (e.clientY - drag.sy) / H;
    let { x, y, w, h } = drag.start;
    const m = drag.mode;
    if (m === 'move') {
        x += dx; y += dy;
    } else {
        if (m.includes('e')) w += dx;
        if (m.includes('s')) h += dy;
        if (m.includes('w')) { x += dx; w -= dx; }
        if (m.includes('n')) { y += dy; h -= dy; }
    }
    Object.assign(layout, { x, y, w, h });
    clampFrame();
    applyLayout();
    preview();
});

window.addEventListener('mouseup', () => {
    if (drag && drag.mode !== 'arrow') preview();
    drag = null;
});

window.addEventListener('keydown', (e) => {
    if (!editing) return;
    if (e.key === 'Escape') return closeEditor(false);
    if (e.key === 'Enter') return closeEditor(true);

    const dirs = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] };
    const d = dirs[e.key];
    if (!d) return;
    e.preventDefault();

    const amt = e.shiftKey ? 10 : 1;
    const W = window.innerWidth, H = window.innerHeight;
    if (e.ctrlKey) {
        layout.w += (d[0] * amt) / W;
        layout.h += (d[1] * amt) / H;
    } else {
        layout.x += (d[0] * amt) / W;
        layout.y += (d[1] * amt) / H;
    }
    clampFrame();
    applyLayout();
    preview();
});

$('btn-save').addEventListener('click', () => closeEditor(true));
$('btn-cancel').addEventListener('click', () => closeEditor(false));
$('btn-reset').addEventListener('click', async () => {
    const res = await post('reset');
    if (res && res.layout) { layout = res.layout; applyLayout(); }
});
$('btn-copy').addEventListener('click', () => {
    showValues(true);
    valuesEl.focus();
    valuesEl.select();
    try { document.execCommand('copy'); } catch (_) { /* textarea stays visible for manual copy */ }
});

// ------------------------------------------------------------- messages

window.addEventListener('message', (e) => {
    const d = e.data;
    if (!d || !d.type) return;

    if (d.type === 'layout') {
        if (!editing) layout = { ...d.layout };
        bounds = d.bounds || bounds;
        units = d.units || 'mi';
        if (typeof d.navScale === 'number' && d.navScale > 0) root.style.setProperty('--nk', d.navScale);
        if (typeof d.tilt === 'number' && d.tilt > 0) tilt = d.tilt;
        if (typeof d.stretch === 'number' && d.stretch > 0) stretch = d.stretch;
        if (d.tint) {
            tintDay.style.background = d.tint.day;
            tintNight.style.background = d.tint.night;
        }
        root.classList.toggle('native-arrow', d.customArrow === false);
        applyLayout();
    } else if (d.type === 'update') {
        onUpdate(d);
    } else if (d.type === 'edit') {
        if (d.state) setEditing(true);
        else if (editing) closeEditor(false);
    }
});

applyLayout();
post('ready');
