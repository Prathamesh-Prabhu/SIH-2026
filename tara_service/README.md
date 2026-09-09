# Tara — voice wellness companion

A warm, calm voice companion for ManoFit personnel, built on Google's
**Gemini Live API** (native audio-to-audio). The Node server holds the only
Gemini session and the API key — the browser / WebView only ever talks to
this server over a local WebSocket.

```
Flutter WebView  ──ws──►  tara_service (Node)  ──►  Gemini Live API
   (mic + audio)             (holds GEMINI_API_KEY)
```

The ManoFit app opens this UI inside a native `WebView` (`/tara` route,
`lib/screens/tara/tara_screen.dart`).

## Run

```bash
cd SIH-2026/tara_service
cp .env.example .env         # then paste your GEMINI_API_KEY
npm install
npm start                    # → http://localhost:3000
```

`server.js` also reads `SIH-2026/.env` (one level up) as a fallback, so the
Gemini vars can live in either file. This folder's `.env` wins.

## Reaching it from the phone

`getUserMedia` only works in a **secure context** — HTTPS or `localhost`. So
for a USB-attached handset, forward the port and keep the URL on `localhost`:

```bash
adb reverse tcp:3000 tcp:3000
```

and in `SIH-2026/.env` keep `TARA_URL=http://localhost:3000` (the default).
A LAN IP like `http://192.168.x.x:3000` will load but the mic stays blocked.

For the Flutter **web** build, run the app and the service on the same host and
set `TARA_URL` to wherever the service is served.

## Env

| var | where | meaning |
|-----|-------|---------|
| `GEMINI_API_KEY` | `tara_service/.env` | Google AI Studio key. **Never** put this in `SIH-2026/.env` — that file is bundled into the APK. |
| `TARA_PORT` | either | listen port (default 3000) |
| `GEMINI_LIVE_MODEL` | either | Live model id (swap if the default 404s) |
| `GEMINI_LIVE_VOICE` | either | prebuilt voice name |
| `GEMINI_LIVE_LANGUAGE` | either | best-effort accent hint (`en-IN`) |
| `TARA_URL` | `SIH-2026/.env` | URL the Flutter app opens (client side) |

## Endpoints

- `GET /` — the voice UI (`public/`)
- `GET /health` — `{ status, service, model, voice }`
- `WS /ws` — one Gemini Live session per connection

Persona and Gemini config live in `server.js` (`TARA_SYSTEM_INSTRUCTION`).
Ported from the `Tara-voice agent/gemini-voice` prototype; crisis guidance
points at **Tele-MANAS 14416**.
