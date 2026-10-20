# sub-page

Single-file subscription viewer for a **3x-UI / Marzban** panel.

The whole UI is one self-contained `index.html` (inline CSS + JS, no build step, no
bundled credentials). It reads three JSON endpoints from a panel and renders traffic,
expiry, live configs and QR codes:

```
GET /sub/<token>/info    → user, quota, expiry, proxy credentials
GET /sub/<token>/apps    → ready-made import links per app
GET /sub/<token>/links   → raw vless / vmess / trojan / ss links
```

## Usage

Open the page and paste either form:

```
https://<your-panel>:<port>/sub/<token>          full URL — parsed automatically
#<token>                                        bare token — uses the preset panel
```

The full URL form carries the panel, so the same page works for any panel whose
`/sub/<token>` API is reachable. `?panel=<base>&token=<token>` also works.

## Notes

- `localStorage` remembers the last panel + token per browser; nothing is sent anywhere else.
- Cached page data expires on its own (see `LS_PAGE_PREFIX` in the source).
- Deployed as a static site: no server, no database, no build.

## Deploy

```
git clone <this repo> && cd sub-page
python3 -m http.server 8080    # or just open index.html
```
