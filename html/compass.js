// GTA VI style compass tape, top-centre. State comes from compass.lua.
// The tape is a strip of ticks from -180 to 540 degrees, slid sideways so the current heading
// sits under the centre caret; the heading is eased between updates so it glides.
(() => {
    const root = document.getElementById('compass');
    const tape = root.querySelector('.cp-tape');
    const strip = root.querySelector('.cp-strip');
    const wpEl = root.querySelector('.cp-wp');
    const degEl = root.querySelector('.cp-deg');
    const radio = document.getElementById('radio');

    const LABELS = { 0: 'N', 45: 'NE', 90: 'E', 135: 'SE', 180: 'S', 225: 'SW', 270: 'W', 315: 'NW' };
    const EASE_MS = 70; // smoothing time constant

    let span = 150;    // degrees visible across the tape
    let ppd = 0;       // pixels per degree
    let target = 0;    // latest heading from the game
    let heading = 0;   // eased heading on screen
    let wp = -1;       // waypoint bearing, -1 = none
    let visible = false;
    let raf = 0;
    let lastT = 0;
    let lastDeg = null;

    const norm360 = (a) => ((a % 360) + 360) % 360;
    const norm180 = (a) => norm360(a + 180) - 180;

    function build() {
        const w = tape.clientWidth;
        if (!w) return;
        ppd = w / span;
        const frag = document.createDocumentFragment();
        for (let d = -180; d <= 540; d += 5) {
            const n = norm360(d);
            const x = `${d * ppd}px`;
            const tick = document.createElement('i');
            tick.className = n % 45 === 0 ? 'cp-tick cp-key' : n % 15 === 0 ? 'cp-tick cp-major' : 'cp-tick';
            tick.style.left = x;
            frag.appendChild(tick);
            if (LABELS[n]) {
                const l = document.createElement('div');
                l.className = `cp-label${n % 90 === 0 ? ' cp-card' : ''}${n === 0 ? ' cp-n' : ''}`;
                l.textContent = LABELS[n];
                l.style.left = x;
                frag.appendChild(l);
            }
        }
        strip.replaceChildren(frag);
        draw();
    }

    function draw() {
        strip.style.transform = `translateX(${-heading * ppd}px)`;

        const deg = Math.round(heading) % 360;
        if (deg !== lastDeg) {
            lastDeg = deg;
            degEl.textContent = String(deg);
        }

        if (wp < 0) {
            wpEl.classList.add('cp-off');
        } else {
            // Pinned to the edge (and dimmed) while it's outside the tape
            const lim = span / 2 - 6;
            const rel = norm180(wp - heading);
            const edge = Math.abs(rel) > lim;
            const at = Math.max(-lim, Math.min(lim, rel));
            wpEl.style.transform = `translateX(${at * ppd}px)`;
            wpEl.classList.toggle('cp-edge', edge);
            wpEl.classList.remove('cp-off');
        }
    }

    function frame(t) {
        raf = 0;
        if (!visible) return;
        const dt = lastT ? Math.min(100, t - lastT) : 16;
        lastT = t;
        const diff = norm180(target - heading);
        heading = Math.abs(diff) < 0.02 ? target : norm360(heading + diff * (1 - Math.exp(-dt / EASE_MS)));
        draw();
        if (heading !== target) raf = requestAnimationFrame(frame);
        else lastT = 0;
    }

    function kick() {
        if (!raf) raf = requestAnimationFrame(frame);
    }

    // Step aside while the radio station strip (same spot) is up
    if (radio && window.MutationObserver) {
        const sync = () => root.classList.toggle('cp-aside', !radio.classList.contains('rs-hidden'));
        new MutationObserver(sync).observe(radio, { attributes: true, attributeFilter: ['class'] });
        sync();
    }

    window.addEventListener('message', (e) => {
        const d = e.data;
        if (!d || d.type !== 'compass') return;

        if (!d.show) {
            visible = false;
            root.classList.add('cp-hidden');
            return;
        }

        if (typeof d.margin === 'number') root.style.setProperty('--m', d.margin);
        let rebuild = !ppd;
        if (typeof d.scale === 'number' && d.scale > 0 && String(d.scale) !== root.style.getPropertyValue('--k')) {
            root.style.setProperty('--k', d.scale);
            rebuild = true;
        }
        if (typeof d.span === 'number' && d.span >= 30 && d.span !== span) {
            span = Math.min(d.span, 300);
            rebuild = true;
        }
        root.classList.toggle('cp-nodeg', d.degrees === false);

        target = norm360(Number(d.heading) || 0);
        wp = typeof d.wp === 'number' ? d.wp : -1;

        if (!visible) {
            // Coming back: snap instead of spinning round from the old heading
            visible = true;
            heading = target;
            root.classList.remove('cp-hidden');
        }
        if (rebuild) build();
        else kick();
    });

    window.addEventListener('resize', build);
    build();
})();
