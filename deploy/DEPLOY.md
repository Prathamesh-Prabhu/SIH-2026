# ManoFit — deploy to a phone on its own internet

Three moving parts:

| Part | What it is | How the phone reaches it |
|------|------------|--------------------------|
| **Flutter app** | the APK you install | — |
| **`ml_service`** | FastAPI risk model, port `8000` | any URL (HTTP is allowed) — set in-app |
| **`tara_service`** | Node relay for Tara voice (holds the Gemini key), port `3000` | **HTTPS URL required** (mic needs a secure context) — set in-app |
| **Supabase** | auth + sync | already public, from `SIH-2026/.env` |

Nothing is hard-coded: the app reads the ML and Tara URLs from on-device
settings, so you rebuild the APK **once** and only ever paste new URLs.

---

## 1. One-time setup

```powershell
# Gemini key for Tara (never goes in the APK)
cd SIH-2026\tara_service
copy .env.example .env         # then paste GEMINI_API_KEY
npm install

# tunnel tool (for the HTTPS URLs)
winget install --id Cloudflare.cloudflared -e
```

`SIH-2026\.env` already holds the Supabase keys. Leave `TARA_URL` as-is — the
in-app setting overrides it.

---

## 2. Start the backends + tunnels

```powershell
cd SIH-2026\deploy
.\start-backends.ps1
```

It launches `ml_service` (`0.0.0.0:8000`), `tara_service` (`0.0.0.0:3000`) and a
Cloudflare quick tunnel for each, then prints:

```
ML   : https://<random>.trycloudflare.com
Tara : https://<random>.trycloudflare.com
```

Leave that window open. Quick-tunnel URLs change every run — that's fine, you
paste them into the app.

**LAN-only fallback** (`.\start-backends.ps1 -Lan`): no tunnels, prints
`http://<your-lan-ip>:8000` / `:3000`. ML works; Tara **text chat** works;
Tara **voice** does not (no HTTPS → browser blocks the mic).

---

## 3. Build & install the app

```powershell
cd SIH-2026
$env:GRADLE_USER_HOME = "D:\android-dev\gradle"
C:\Users\asus\flutter\bin\flutter build apk --release
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

(Release uses the debug signing key — fine for sideloading.)

---

## 4. Zero-Paste Automatic Connection (via Supabase)

You **do NOT need to paste URLs**:

1. Run the one-time migration in your Supabase SQL Editor:
   `SIH-2026\supabase_migration_system_config.sql`
2. Run `.\start-backends.ps1`
   - It starts both services, opens tunnels, and **automatically publishes the live URLs to Supabase**.
3. Open the ManoFit app on your phone:
   - The app reads the active endpoints directly from Supabase.
   - **Tara voice and ML Analytics connect automatically with zero typing or pasting!**

*(Optional manual override: If you ever want to point to a custom host, you can still open the tune icon in HR Admin or the top-bar icon in Tara).*

---


## 5. What now works end-to-end over the phone's internet

- **Auth / onboarding / RBAC** — Supabase.
- **Personnel check-ins** (daily / weekly / monthly, `/checkins`) — saved,
  persisted, and folded into the HR **Organisation Wellbeing** roll-up.
- **Mood, mindfulness, self-help** — local + Supabase sync.
- **Tara** — voice (Gemini Live via the relay) *and* text chat, with
  Tele-MANAS 14416 crisis escalation.
- **HR ingestion** — CSV / XLSX upload → pseudonymise → merge into the local
  DB (persists across restarts).
- **Predictive Analytics** — live `ml_service` scoring of the ingested roster,
  per-token SHAP factors, "Report to Welfare Officer".

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| ML dialog says "unreachable" | tunnel window closed, or wrong URL. Re-run `start-backends.ps1`, re-paste. |
| Tara loads but mic is dead | URL is `http://` not `https://`. Use the tunnel URL, not the LAN IP. |
| Tara: "Missing GEMINI_API_KEY" in the console | `tara_service\.env` has no key. |
| `cloudflared` not found | `winget install --id Cloudflare.cloudflared -e`, reopen the shell. |
| APK build fails with `fileHashes.bin` | C: is full — `$env:GRADLE_USER_HOME="D:\android-dev\gradle"` before building. |
