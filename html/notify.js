// Notifications feed (state comes from notify.lua). One stack per screen position; repeats of a
// visible notification merge into it with a count badge; a notification with an id (ox_lib) updates
// the visible one with that id instead of stacking a new one.
(() => {
    const root = document.getElementById('notify');
    const faLink = document.getElementById('fa-css');
    const stacks = {};
    const items = [];

    // ------------------------------------------------------------- sounds
    // Synthesised here (no files, no GTA sounds): soft sine "glass" notes with a quiet upper partial,
    // a 6ms attack and a short exponential tail, through a gentle low-pass and one faint echo.
    // One small motif per type: info = single ping, success = rising fifth, warning = two even
    // taps, error = falling fourth (lower and duller, never a buzzer).
    const MOTIFS = {
        //        [start s, frequency Hz, length s]
        info:    [[0, 1046.5, 0.24]],                          // C6
        success: [[0, 880.0, 0.16], [0.075, 1318.5, 0.3]],     // A5 -> E6
        warning: [[0, 784.0, 0.13], [0.115, 784.0, 0.22]],     // G5, G5
        error:   [[0, 622.3, 0.16], [0.095, 466.2, 0.3]],      // Eb5 -> Bb4
    };

    // Builds one motif on any AudioContext (also used offline to check levels)
    function motif(ctx, dest, type, volume, t0) {
        const notes = MOTIFS[type] || MOTIFS.info;
        const peak = 0.11 * Math.max(0, Math.min(1, volume));
        const dull = type === 'error'; // softer top end for errors
        for (const [at, freq, len] of notes) {
            const t = t0 + at;
            // fundamental + octave (+ a whisper of the 3rd harmonic on the bright ones)
            const partials = dull ? [[1, 1], [2, 0.12]] : [[1, 1], [2, 0.2], [3, 0.05]];
            for (const [mult, g] of partials) {
                const osc = ctx.createOscillator();
                osc.type = 'sine';
                // starts a hair sharp and settles: reads as a tap rather than a beep
                osc.frequency.setValueAtTime(freq * mult * 1.012, t);
                osc.frequency.exponentialRampToValueAtTime(freq * mult, t + 0.03);
                const env = ctx.createGain();
                env.gain.setValueAtTime(0.0001, t);
                env.gain.exponentialRampToValueAtTime(peak * g, t + 0.006);
                env.gain.exponentialRampToValueAtTime(0.0001, t + len / mult); // upper partials die faster
                osc.connect(env);
                env.connect(dest);
                osc.start(t);
                osc.stop(t + len + 0.05);
            }
        }
    }

    // Master chain: low-pass (takes the edge off) + one quiet echo for a bit of air
    function chain(ctx) {
        const input = ctx.createGain();
        const lp = ctx.createBiquadFilter();
        lp.type = 'lowpass';
        lp.frequency.value = 4800;
        lp.Q.value = 0.5;
        const delay = ctx.createDelay(0.5);
        delay.delayTime.value = 0.09;
        const feedback = ctx.createGain();
        feedback.gain.value = 0.2;
        const wet = ctx.createGain();
        wet.gain.value = 0.18;
        input.connect(lp);
        input.connect(delay);
        delay.connect(feedback);
        feedback.connect(delay);
        delay.connect(wet);
        wet.connect(lp);
        lp.connect(ctx.destination);
        return input;
    }

    const sound = (() => {
        let ctx = null;
        let input = null;
        let last = 0;
        return (type, volume) => {
            try {
                if (!ctx) {
                    ctx = new (window.AudioContext || window.webkitAudioContext)();
                    input = chain(ctx);
                }
                if (ctx.state === 'suspended') ctx.resume();
                const now = ctx.currentTime;
                if (now - last < 0.09) return; // a burst of notifications plays once, not as a stutter
                last = now;
                motif(ctx, input, type, volume, now + 0.01);
            } catch (err) { /* no audio device: stay silent */ }
        };
    })();
    window.viNotifySound = { motif, chain, MOTIFS }; // for offline previews

    const ICONS = {
        success: '<svg viewBox="0 0 24 24"><path d="M5 12.6l4.4 4.4L19 7.4"/></svg>',
        error: '<svg viewBox="0 0 24 24"><path d="M7 7l10 10M17 7L7 17"/></svg>',
        warning: '<svg viewBox="0 0 24 24"><path d="M12 5.2v8.4"/><circle class="dot" cx="12" cy="18.4" r="1.7"/></svg>',
        info: '<svg viewBox="0 0 24 24"><circle class="dot" cx="12" cy="5.8" r="1.7"/><path d="M12 10.6v8.2"/></svg>',
    };

    // GTA text colour codes, in the HUD's palette
    const COLOURS = {
        r: '#f06296', q: '#f06296', g: '#78d876', b: '#5fa8f5', y: '#f2c94c', o: '#f29b4c',
        p: '#be88f1', c: '#9a9aa6', m: '#6d6d78', u: '#16161f', l: '#16161f', w: '#ffffff', f: '#ffffff',
    };

    // ~INPUT_*~ tokens -> default key
    const KEYS = {
        INPUT_CONTEXT: 'E', INPUT_PICKUP: 'E', INPUT_TALK: 'E', INPUT_VEH_HORN: 'E',
        INPUT_CONTEXT_SECONDARY: 'Q', INPUT_COVER: 'Q', INPUT_DETONATE: 'G', INPUT_ENTER: 'F',
        INPUT_VEH_EXIT: 'F', INPUT_JUMP: 'Space', INPUT_SPRINT: 'Shift', INPUT_DUCK: 'Ctrl',
        INPUT_RELOAD: 'R', INPUT_VEH_HEADLIGHT: 'H', INPUT_MULTIPLAYER_INFO: 'Z',
        INPUT_INTERACTION_MENU: 'M', INPUT_SELECT_WEAPON: 'Tab', INPUT_CHARACTER_WHEEL: 'Alt',
        INPUT_ATTACK: 'LMB', INPUT_AIM: 'RMB', INPUT_PHONE: '↑',
        INPUT_FRONTEND_ACCEPT: 'Enter', INPUT_FRONTEND_RDOWN: 'Enter',
        INPUT_FRONTEND_CANCEL: 'Backspace', INPUT_FRONTEND_RRIGHT: 'Backspace', INPUT_CELLPHONE_CANCEL: 'Backspace',
    };

    const ANIMS = {
        spin: 'fa-spin', spinPulse: 'fa-spin-pulse', spinReverse: 'fa-spin-reverse', pulse: 'fa-spin-pulse',
        beat: 'fa-beat', fade: 'fa-fade', beatFade: 'fa-beat-fade', bounce: 'fa-bounce', shake: 'fa-shake',
    };
    const FA_STYLES = { fas: 'fa-solid', far: 'fa-regular', fab: 'fa-brands', fal: 'fa-light', fat: 'fa-thin', fad: 'fa-duotone' };

    const esc = (s) => s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

    // Plain text -> safe HTML: everything is escaped first, then GTA codes / light markdown are applied
    function format(text) {
        let s = String(text).replace(/<br\s*\/?>/gi, '\n').replace(/<[^>]*>/g, '');
        s = esc(s)
            .replace(/\*\*(.+?)\*\*/g, '<b>$1</b>')
            .replace(/(^|[\s(])\*([^*\s][^*]*?)\*(?=$|[\s.,!?)])/g, '$1<i>$2</i>')
            .replace(/`([^`]+)`/g, '<code>$1</code>');

        let open = false;
        let bold = false;
        s = s.replace(/~([A-Za-z0-9_]+)~/g, (_, t) => {
            if (t === 'n' || t === 'br') return '\n';
            if (t === 'h') { bold = !bold; return bold ? '<b>' : '</b>'; }
            if (t.startsWith('INPUT_')) {
                const label = KEYS[t] || t.slice(6).replace(/_/g, ' ').toLowerCase();
                return `<kbd>${esc(label)}</kbd>`;
            }
            const k = t.toLowerCase();
            const close = open ? '</span>' : '';
            if (k === 's') { open = false; return close; }
            if (COLOURS[k]) { open = true; return `${close}<span style="color:${COLOURS[k]}">`; }
            return '';
        });
        if (open) s += '</span>';
        if (bold) s += '</b>';
        return s.replace(/\n/g, '<br>');
    }

    function iconHtml(n) {
        if (n.icon && faLink && faLink.sheet) {
            const parts = String(n.icon).toLowerCase().replace(/[^a-z0-9\- ]/g, '').trim().split(/\s+/).filter(Boolean);
            const cls = [];
            let styled = false;
            for (const p of parts) {
                if (FA_STYLES[p]) { cls.push(FA_STYLES[p]); styled = true; }
                else if (/^fa-(solid|regular|brands|light|thin|duotone)$/.test(p)) { cls.push(p); styled = true; }
                else cls.push(p.startsWith('fa-') ? p : `fa-${p}`);
            }
            if (cls.length) {
                if (!styled) cls.unshift('fa-solid');
                if (ANIMS[n.iconAnimation]) cls.push(ANIMS[n.iconAnimation]);
                return `<i class="${cls.join(' ')}"></i>`;
            }
        }
        return ICONS[n.type] || ICONS.info;
    }

    function stackFor(pos) {
        if (!stacks[pos]) {
            const el = document.createElement('div');
            el.className = 'nt-stack';
            el.dataset.pos = pos;
            root.appendChild(el);
            stacks[pos] = el;
        }
        return stacks[pos];
    }

    function render(item, n) {
        const el = item.el;
        el.dataset.type = n.type;
        if (n.iconColor) el.style.setProperty('--c', n.iconColor);
        else el.style.removeProperty('--c');
        el.classList.toggle('nt-solo', !n.title);
        el.querySelector('.nt-icon').innerHTML = iconHtml(n);
        el.querySelector('.nt-title').innerHTML = n.title ? format(n.title) : '';
        el.querySelector('.nt-desc').innerHTML = n.description ? format(n.description) : '';
        const badge = el.querySelector('.nt-count');
        badge.textContent = item.count > 1 ? `×${item.count}` : '';
        badge.style.display = item.count > 1 ? '' : 'none';
        el.classList.toggle('nt-multi', item.count > 1);
        item.showBar = n.showDuration !== false;
    }

    function arm(item, ms) {
        clearTimeout(item.timer);
        item.timer = setTimeout(() => remove(item), ms);
        const bar = item.el.querySelector('.nt-bar');
        bar.style.display = item.showBar ? '' : 'none';
        const fill = document.createElement('i'); // fresh element restarts the countdown animation
        fill.style.setProperty('--d', `${ms}ms`);
        bar.replaceChildren(fill);
    }

    function bump(item) {
        const el = item.el;
        el.classList.remove('nt-bump');
        void el.offsetWidth;
        el.classList.add('nt-bump');
    }

    // Slide the shell's height between two values (the cards around it follow)
    function slideHeight(el, from, to, done) {
        el.classList.add('nt-clip');
        el.style.height = `${from}px`;
        void el.offsetHeight;
        el.style.height = `${to}px`;
        let finished = false;
        const end = () => {
            if (finished) return;
            finished = true;
            el.removeEventListener('transitionend', onEnd);
            done();
        };
        const onEnd = (e) => { if (e.target === el && e.propertyName === 'height') end(); };
        el.addEventListener('transitionend', onEnd);
        setTimeout(end, 450); // in case transitionend never fires
    }

    function remove(item) {
        if (item.leaving) return;
        item.leaving = true;
        clearTimeout(item.timer);
        const el = item.el;
        el.classList.add('nt-out');
        setTimeout(() => {
            slideHeight(el, el.offsetHeight, 0, () => {
                el.remove();
                const i = items.indexOf(item);
                if (i !== -1) items.splice(i, 1);
            });
        }, 200);
    }

    function add(n, max) {
        const key = [n.type, n.title || '', n.description || '', n.position].join('|');
        let item = n.id ? items.find((i) => !i.leaving && i.id === n.id) : null;
        if (!item) {
            item = items.find((i) => !i.leaving && i.key === key);
            if (item) item.count += 1;
        }
        if (item) {
            item.key = key;
            render(item, n);
            bump(item);
            arm(item, n.duration);
            return;
        }

        const el = document.createElement('div');
        el.className = 'nt';
        el.innerHTML = '<div class="nt-card"><div class="nt-icon"></div><div class="nt-body">'
            + '<div class="nt-head"><div class="nt-title"></div><div class="nt-count"></div></div>'
            + '<div class="nt-desc"></div></div><div class="nt-bar"></div></div>';
        item = { el, key, id: n.id || null, count: 1, pos: n.position, leaving: false, timer: 0, showBar: true };
        render(item, n);

        // top stacks: newest on top; bottom / centre stacks: newest at the bottom
        const st = stackFor(n.position);
        if (n.position.startsWith('top')) st.prepend(el);
        else st.append(el);
        items.push(item);

        const h = el.offsetHeight;
        slideHeight(el, 0, h, () => {
            if (item.leaving) return;
            el.style.height = '';
            el.classList.remove('nt-clip');
        });
        requestAnimationFrame(() => requestAnimationFrame(() => el.classList.add('nt-in')));
        arm(item, n.duration);

        const live = items.filter((i) => !i.leaving && i.pos === n.position);
        while (live.length > max) remove(live.shift());
    }

    window.addEventListener('message', (e) => {
        const d = e.data;
        if (!d) return;
        if (d.type === 'notify-hidden') {
            root.classList.toggle('nt-hidden', !!d.hidden);
            return;
        }
        if (d.type === 'notify-offset') {
            if (typeof d.top === 'number') root.style.setProperty('--tro', d.top);
            return;
        }
        if (d.type !== 'notify' || !d.n) return;
        if (typeof d.margin === 'number') root.style.setProperty('--m', d.margin);
        if (typeof d.scale === 'number') root.style.setProperty('--k', d.scale);
        const n = d.n;
        if (typeof n.position !== 'string') n.position = 'center-left';
        if (typeof n.duration !== 'number') n.duration = 5000;
        add(n, typeof d.max === 'number' ? d.max : 5);
        if (d.sound) sound(n.type, typeof d.volume === 'number' ? d.volume : 0.6);
    });
})();
