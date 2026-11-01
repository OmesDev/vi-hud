// Weapon icon, top-right (the ammo above it is drawn in-game by weapons.lua). State comes from weapons.lua.
(() => {
    const root = document.getElementById('weaponhud');
    const iconEl = root.querySelector('.wh-icon');

    let shown = null;      // weapon name whose icon is up
    const resolved = {};   // weapon name -> working icon url, '' = none

    function setIcon(name, label, iconUrl) {
        if (shown === name) return;
        shown = name;
        const alt = () => {
            const el = document.createElement('div');
            el.className = 'wh-alt';
            el.textContent = label;
            iconEl.replaceChildren(el);
        };
        if (resolved[name] === '') return alt();

        const list = resolved[name] ? [resolved[name]] : [`weapons/${name}.png`];
        if (!resolved[name]) {
            const urls = typeof iconUrl === 'string' ? [iconUrl]
                : Array.isArray(iconUrl) ? iconUrl : iconUrl && typeof iconUrl === 'object' ? Object.values(iconUrl) : [];
            for (const u of urls) if (typeof u === 'string' && u) list.push(u.replace(/%s/g, name.toLowerCase()).replace(/%S/g, name));
        }
        let i = 0;
        const img = new Image();
        img.alt = '';
        img.onload = () => { resolved[name] = list[i]; };
        img.onerror = () => {
            if (shown !== name) return;
            i += 1;
            if (i < list.length) img.src = list[i];
            else { resolved[name] = ''; alt(); }
        };
        img.src = list[0];
        iconEl.replaceChildren(img);
    }

    window.addEventListener('message', (e) => {
        const d = e.data;
        if (!d || d.type !== 'weaponhud') return;
        if (!d.show) {
            root.classList.add('wh-hidden');
            return;
        }
        if (typeof d.margin === 'number') root.style.setProperty('--m', d.margin);
        if (typeof d.ammoH === 'number') root.style.setProperty('--ah', d.ammoH);
        if (typeof d.iconSize === 'number') root.style.setProperty('--k', d.iconSize);
        if (typeof d.offset === 'number') root.style.setProperty('--mo', d.offset);

        setIcon(d.name, d.label || '', d.iconUrl);
        root.classList.remove('wh-hidden');
    });
})();
