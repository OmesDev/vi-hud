// Weapon icons from inventory packs are usually square PNGs with the weapon drawn in the middle,
// so long guns (rifles, shotguns...) end up a thin strip with lots of empty space above and below
// and look tiny next to a pistol once they're fitted into a tile. This crops the transparent
// border off, so every icon fills its space the same way.
//
//   IconTrim.get(url)   trimmed data: url if it's ready, else null
//   IconTrim.load(url)  Promise -> trimmed data: url, or the original url when it can't be read
//                        (another resource that doesn't allow reading its pixels, no border...)
window.IconTrim = (() => {
    const done = {};    // url -> trimmed url (or the url itself)
    const pending = {}; // url -> Promise
    const ALPHA = 12;   // pixels fainter than this count as empty (soft shadows / antialiasing)
    const PAD = 2;      // px kept around the weapon

    function trim(img) {
        const w = img.naturalWidth;
        const h = img.naturalHeight;
        if (!w || !h) return null;
        const c = document.createElement('canvas');
        c.width = w;
        c.height = h;
        const ctx = c.getContext('2d', { willReadFrequently: true });
        ctx.drawImage(img, 0, 0);
        const px = ctx.getImageData(0, 0, w, h).data; // throws when the image is cross-origin without CORS

        let top = h, left = w, right = -1, bottom = -1;
        for (let y = 0; y < h; y++) {
            const row = y * w * 4;
            for (let x = 0; x < w; x++) {
                if (px[row + x * 4 + 3] > ALPHA) {
                    if (x < left) left = x;
                    if (x > right) right = x;
                    if (y < top) top = y;
                    bottom = y;
                }
            }
        }
        if (right < 0) return null; // fully transparent

        left = Math.max(0, left - PAD);
        top = Math.max(0, top - PAD);
        right = Math.min(w - 1, right + PAD);
        bottom = Math.min(h - 1, bottom + PAD);
        const cw = right - left + 1;
        const ch = bottom - top + 1;
        if (cw >= w - 1 && ch >= h - 1) return null; // nothing worth cutting

        const out = document.createElement('canvas');
        out.width = cw;
        out.height = ch;
        out.getContext('2d').drawImage(c, left, top, cw, ch, 0, 0, cw, ch);
        return out.toDataURL('image/png');
    }

    function load(url) {
        if (done[url]) return Promise.resolve(done[url]);
        if (pending[url]) return pending[url];
        pending[url] = new Promise((resolve) => {
            const img = new Image();
            img.crossOrigin = 'anonymous';
            const finish = (src) => {
                done[url] = src;
                delete pending[url];
                resolve(src);
            };
            img.onload = () => {
                let src = null;
                try { src = trim(img); } catch (e) { src = null; }
                finish(src || url);
            };
            img.onerror = () => finish(url);
            img.src = url;
        });
        return pending[url];
    }

    return { get: (url) => done[url] || null, load };
})();
