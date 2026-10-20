# 🟠 Amber Subscription — VPN Centers Sub Page

A white-label subscription page theme for **3x-ui / Marzban** panels — **Amber** design (warm orange on navy, matched to the **VPN Centers** logo).

RTL-first (فارسی), zero branding of the seller, fully self-contained: one `index.html`, inline CSS/JS, no build step, no external services.

## ✨ Features
- 🟠 **Amber palette** — orange `#f27a1a` on warm navy, matched to the VPN Centers mark
- 🖼️ **Your logo** — login card (72px) + beside the username (44px) + favicon
- ⚡ **Instant open** — reads `/sub/<token>/info`, `/apps` and `/links` from the panel with a single fetch
- 🔗 **Token-only link** — `…/amber/#<token>` works; a shim resolves it against the preset panel
- 📱 **Responsive** — mobile-first card layout, safe-area insets
- 🔒 **No credentials in the page** — the token lives in the URL you share, never in the source

## ⚡ نصب سریع / Quick Install

روی سرور وب (nginx / caddy / apache) با کاربر root:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/frank0live/amber-subscription/main/install.sh)
```

نصب‌کننده خودکار:
1. تشخیص سرور وب (nginx / caddy / apache / بدون وب‌سرور)
2. تشخیص آدرس پنل از پایگاه‌دادهٔ x-ui یا پورتِ در حال اجرا
3. دانلود `index.html` + `assets/logo.png` به `/var/www/amber-sub`
4. ساخت `location /amber/` و **تست `nginx -t` قبل از reload** (در صورت خطا rollback)
5. چاپ لینک آماده برای اشتراک

### نصب دستی (بدون اسکریپت)
1. `index.html` و `assets/logo.png` را در هر پوشهٔ وب کپی کن.
2. با پیشوند دلخواه سرو کن (مثلاً `/amber/`).
3. لینک مشتری:

```
https://YOUR-DOMAIN/amber/?panel=https://YOUR-PANEL:PORT&token=<TOKEN>
https://YOUR-DOMAIN/amber/#<TOKEN>
```

### بدون سرور؟ از GitHub Pages استفاده کن
همین صفحه روی Pages منتشر است:

```text
https://frank0live.github.io/amber-subscription/
https://frank0live.github.io/amber-subscription/#<TOKEN>
```

## 📁 Files
- **`index.html`** — production page (single file, everything inline).
- **`amber/index.html`** — same file under the `/amber/` prefix (path-aliased hosting).
- **`assets/logo.png`** — VPN Centers mark (512×512).
- **`install.sh`** — one-line installer (see above).

## Notes
- `localStorage` remembers the last panel + token per browser; nothing is sent anywhere else.
- Deployment is a static copy: no database, no build, no PHP.

---

## فارسی
صفحهٔ اشتراک **وایت‌لیبل** با تم کهربایی و لوگوی VPN Centers.

- **`index.html`** را در وب‌سرور بگذار؛ لینک `/#<TOKEN>` را به مشتری بده.
- بدون نام فروشنده، بدون دکمهٔ پشتیبانی/تمدید، بدون سرویس بیرونی.
- یک فایل، بدون build، لوگو در صفحهٔ ورود و هدر پروفایل + favicon.

**نصب خودکار:** `bash <(curl -fsSL https://raw.githubusercontent.com/frank0live/amber-subscription/main/install.sh)`

**بدون سرور:** `https://frank0live.github.io/amber-subscription/#<TOKEN>`
