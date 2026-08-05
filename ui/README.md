# ui/ — the starling.build landing page

A static, dependency-free site. Both pages are self-contained — inline CSS, inline
SVG icons, no fonts and no framework fetched from anywhere; `img/` holds screenshots
taken from a real session with `build/shell-drive.py` and downsized for the web.
The single external request is the Cloudflare Web Analytics beacon (see below).

Preview locally:

```bash
python3 -m http.server -d ui 8000    # then open http://localhost:8000
```

The hero is the demo video (`video/starling-demo.mp4`), not a screenshot. It is
a single unedited take captured with the desktop's own recorder and driven by a
`build/shell-drive.py` script, then downsized for the web:

```bash
ffmpeg -i "~/Videos/Screen Recording ....mp4" -vf scale=1280:800:flags=lanczos \
       -c:v libx264 -profile:v high -preset slow -crf 31 -pix_fmt yuv420p \
       -movflags +faststart -an ui/video/starling-demo.mp4
ffmpeg -ss 144 -i "~/Videos/Screen Recording ....mp4" -frames:v 1 \
       -vf scale=1280:800:flags=lanczos -q:v 3 ui/img/demo-poster.jpg
```

`+faststart` puts the moov atom first so the file plays while it downloads, and
the element carries `preload="none"` — the 19 MB is fetched only when someone
presses play, so the hero still paints at the cost of the 94 KB poster. CRF 31
was chosen by comparing 29 and 31 on the most text-dense frame; they were
indistinguishable and 31 is a third smaller. Keep `img/desktop.jpg` — it is the
fallback inside the `<video>` element for anything that cannot play MP4.

Re-cut the screenshots after a UI change:

```bash
sudo build/shell-drive.py "shot /tmp/shot.png"
magick /tmp/shot.png -resize 2400x -quality 82 -strip ui/img/desktop.jpg
```

## Publishing to starling.build

**Not yet live.** Two things block serving this folder directly, both external to
the code:

1. **GitHub Pages cannot publish a private repo on a free plan.**
   `starling-build` is on the free plan and `starling-desktop` is private, so
   Pages is unavailable here until the repo is public or the org upgrades.
2. **Pages only serves from `/` or `/docs`** on branch-based publishing — never
   from an arbitrary folder like `/ui`.

The recommended shape, which keeps the product source private:

- Create a **separate public repo** for the site — `starling-build/www` (or
  `starling-build/starling-build.github.io`).
- Publish this folder's *contents* at that repo's **root**, so the `/ui` path
  restriction never applies. `deploy.sh` does exactly that.
- In that repo: Settings → Pages → source `main` / root, then set the custom
  domain to `starling.build`. The `CNAME` file here is copied along and pins it.
- DNS for `starling.build`: four `A` records at the apex pointing to
  `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
  (and optionally `www` as a `CNAME` to `starling-build.github.io`). Enable
  "Enforce HTTPS" once the certificate is issued.

This folder stays the source of truth; the site repo is a publish target.

## Analytics

Both pages carry the Cloudflare Web Analytics beacon just before `</body>`.
Cookieless, so no consent banner is required, and ~1 KB against 30 KB of page.
The `data-cf-beacon` token is **not a secret** — it ships in public HTML and only
names the site; committing it is intended.

Cloudflare records a hit only when the page's hostname matches the one registered
in the dashboard (`starling.build`), so `python3 -m http.server` previews on
localhost never show up in the numbers.

The dashboard also offers to inject this beacon at the edge instead ("Real User
Measurements"). That only fires for traffic proxied through Cloudflare — with the
DNS above, the apex `A` records point straight at GitHub Pages, so nothing would
be injected. Keep the snippet in the HTML unless the records are later
orange-clouded, and don't run both.
