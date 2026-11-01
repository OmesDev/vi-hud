// Money display icon discs, top-right (the amounts next to them are drawn in-game by money.lua).
// money.lua sends the centre y (screen-height fraction) of each visible row.
(() => {
    const root = document.getElementById('money');
    const discs = {
        bank: root.querySelector('.mh-bank'),
        cash: root.querySelector('.mh-cash'),
    };

    window.addEventListener('message', (e) => {
        const d = e.data;
        if (!d || d.type !== 'money') return;
        if (!d.show) {
            root.classList.add('mh-hidden');
            return;
        }
        if (typeof d.margin === 'number') root.style.setProperty('--m', d.margin);
        if (typeof d.k === 'number') root.style.setProperty('--k', d.k);

        const seen = {};
        for (const r of Array.isArray(d.rows) ? d.rows : []) {
            const el = discs[r.n];
            if (!el || typeof r.y !== 'number') continue;
            seen[r.n] = true;
            el.style.top = `${r.y * 100}vh`;
            el.classList.remove('mh-off');
        }
        for (const n of Object.keys(discs)) if (!seen[n]) discs[n].classList.add('mh-off');

        root.classList.remove('mh-hidden');
    });
})();
