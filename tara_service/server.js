import dotenv from 'dotenv';
import express from 'express';
import { createServer } from 'http';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { WebSocketServer } from 'ws';
import { GoogleGenAI, Modality } from '@google/genai';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Config precedence: this folder's .env wins, then the shared Flutter .env
// one level up (so the demo can keep a single env file if it wants to).
dotenv.config({ path: join(__dirname, '.env') });
dotenv.config({ path: join(__dirname, '..', '.env') });

const PORT = process.env.PORT || process.env.TARA_PORT || 3000;

const MODEL = process.env.GEMINI_LIVE_MODEL || 'gemini-3.1-flash-live-preview';

// Prebuilt Gemini Live voices. The client picks female / male at connect time
// (a toggle in the Tara UI); `GEMINI_LIVE_VOICE`, if set, pins one for both.
// Female calm options: Leda (gentle), Sulafat (warm), Aoede (breezy),
// Vindemiatrix (gentle), Achernar (soft). Male calm options: Achird (friendly),
// Algieba (smooth), Iapetus (clear), Charon (informative).
// Full list: https://ai.google.dev/gemini-api/docs/live-guide
const VOICE_FEMALE = process.env.GEMINI_LIVE_VOICE_FEMALE || 'Leda';
const VOICE_MALE = process.env.GEMINI_LIVE_VOICE_MALE || 'Achird';
const VOICE_PINNED = process.env.GEMINI_LIVE_VOICE || '';
const TEXT_MODEL = process.env.GEMINI_TEXT_MODEL || 'gemini-3.6-flash';

function voiceFor(gender) {
  if (VOICE_PINNED) return VOICE_PINNED;
  return gender === 'male' ? VOICE_MALE : VOICE_FEMALE;
}

function normaliseGender(v) {
  const s = String(v || '').trim().toLowerCase();
  if (s === 'm' || s === 'male' || s === 'man') return 'male';
  if (s === 'f' || s === 'female' || s === 'woman') return 'female';
  return null;
}

// Language mode: 'auto' (mirror the user, Hindi ⇄ English), 'en' or 'hi'.
// Back-compat: a BCP-47 value like `en-IN` / `hi-IN` is accepted too.
const DEFAULT_LANG = normaliseLang(process.env.GEMINI_LIVE_LANGUAGE) || 'auto';

function normaliseLang(v) {
  const s = String(v || '').trim().toLowerCase();
  if (!s) return null;
  if (s === 'hi' || s === 'hindi' || s.startsWith('hi-') || s.startsWith('hi_')) return 'hi';
  if (s === 'en' || s === 'english' || s.startsWith('en-') || s.startsWith('en_')) return 'en';
  return 'auto';
}

if (!process.env.GEMINI_API_KEY) {
  console.error(
    'Missing GEMINI_API_KEY. Add it to tara_service/.env (copy .env.example).'
  );
  process.exit(1);
}

const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

// High-recall crisis lexicon. Scanned against Gemini Live's input
// transcription of what the user said. A hit triggers an immediate escalation
// event to the client (which alerts the Welfare Officer + Tele-MANAS). Tuned
// for recall over precision on purpose — a false alarm is cheap here.
const CRISIS_PATTERNS = [
  /\bkill(?:ing)?\s+my ?self\b/i,
  /\bkill\s+me\b/i,
  /\bsuicid(?:e|al)\b/i,
  /\bend(?:ing)?\s+(?:my|it all|my life|everything)\b/i,
  /\btake\s+my\s+(?:own\s+)?life\b/i,
  /\b(?:want|wanna|going)\s+to\s+die\b/i,
  /\bwish\s+(?:i\s+(?:was|were)|to\s+be)\s+dead\b/i,
  /\bbetter\s+off\s+(?:dead|without\s+me)\b/i,
  /\bdon'?t\s+want\s+to\s+(?:live|be here|exist|wake up)\b/i,
  /\bno\s+(?:reason|point)\s+(?:to|in)\s+(?:living|life|going on)\b/i,
  /\b(?:hurt|harm|cut)(?:ing)?\s+my ?self\b/i,
  /\bself[-\s]?harm\b/i,
  /\bslit\s+my\b/i,
  /\boverdose\b/i,
  /\bcan'?t\s+(?:go on|do this anymore|take (?:it|this) anymore)\b/i,
  /\bend\s+my\s+suffering\b/i,
  // Hindi — Devanagari and common romanised spellings. Recall over precision.
  /आत्महत्या/,
  /ख़?ुदक़?ुशी/,
  /(?:मरना|मर\s*जाना|मर\s*जाऊँ|मर\s*जाऊं)\s*चाहता|चाहती/,
  /जीना\s*नहीं\s*चाहता|जीना\s*नहीं\s*चाहती/,
  /ज़िंदगी\s*ख़?त्म\s*कर/,
  /अपने\s*आप\s*को\s*(?:ख़?त्म|मार)/,
  /खुद\s*को\s*(?:ख़?त्म|मार|नुकसान)/,
  /\baatmahatya\b/i,
  /\bkhud ?kushi\b/i,
  /\bmar(?:na)?\s+chahta\b/i,
  /\bmarna\s+chahti\b/i,
  /\bjeena\s+nahi\b/i,
  /\bzindagi\s+khatam\b/i,
  /\bkhud ?ko\s+(?:khatam|maar|nuksaan)\b/i,
];

function detectCrisis(text) {
  for (const re of CRISIS_PATTERNS) {
    const m = re.exec(text);
    if (m) return m[0].trim();
  }
  return null;
}

// Tara's persona for ManoFit — a warm, calm companion for armed-forces and
// CAPF personnel. Non-clinical; bridges to Tele-MANAS 14416 on crisis. The
// persona is language-agnostic; a per-conversation language rule is prepended
// (auto / Hindi / English) so the same Tara works in either tongue.
const TARA_PERSONA = `You are Tara, a warm, calm companion inside ManoFit — a wellbeing app for
armed-forces and CAPF personnel. You give the person a safe, judgment-free space to talk out loud about
their day, their duty, their stress, or whatever's on their mind — no appointments, no scripts, no
waiting, and nothing they say here reaches their chain of command.

Speak like a caring, emotionally present friend: warm, conversational, in short natural sentences —
never clinical or scripted. Ask gentle open questions like "how are you feeling?" or "what's been
weighing on you today?", and actually listen — reflect back what you hear before offering anything.

Talk the way a real person does, not a polished narrator: use contractions, and keep it warm and
genuine. Do NOT pad your speech with filler sounds — no "umm", "uh", "aah", "hmm" or drawn-out pauses —
and don't trail off in the middle of a sentence. Finish your thoughts clearly. Natural and human, but
easy to follow.

You understand military life — long deployments, rotations, separation from family, the weight of
responsibility — but you don't pretend to have served. You are not a licensed therapist, doctor, or crisis
line. Say so plainly if it's relevant, but don't repeat it constantly. If someone expresses thoughts of
self-harm, suicide, or acute crisis, respond with calm, direct concern and clearly encourage them to call
Tele-MANAS on 14416 — India's free, confidential 24/7 mental-health helpline — or reach their unit's
welfare officer or emergency services right away.

Your job is to help people slow down, process their thoughts, manage everyday stress and anxiety, or just
vent — not to diagnose or treat.`;

// Spoken-delivery guidance, voice only.
const TARA_SPOKEN_DELIVERY = `Delivery: speak at a natural, relaxed conversational pace — calm but not
slow, with normal sentence rhythm. Keep each response short, like a real spoken conversation, not a
monologue. Let the user lead the pace.`;

// Per-conversation language rule, prepended to the persona.
const LANG_RULES = {
  en: `Always speak and respond in English, in a warm, gentle, natural Indian-English accent. Even if the
user speaks another language, reply kindly in English.`,
  hi: `Always speak and respond in natural, everyday conversational Hindi — the way people actually talk,
not formal or literary Hindi. A few common English words that people naturally mix in ("duty", "stress",
"family", "leave", "posting") are fine. Even if the user writes in English, reply gently in Hindi.`,
  auto: `Mirror the user's language. If they use Hindi, reply in warm everyday Hindi; if English, reply in
gentle Indian-English; if they mix Hindi and English (Hinglish), mix naturally too. Stay within just these
two languages — Hindi and English — and switch whenever they do.`,
};

function langRule(lang) {
  return LANG_RULES[lang] || LANG_RULES.auto;
}

function taraVoiceInstruction(lang) {
  return `${langRule(lang)}\n\n${TARA_PERSONA}\n\n${TARA_SPOKEN_DELIVERY}`;
}

function taraTextInstruction(lang) {
  return `${langRule(lang)}\n\n${TARA_PERSONA}\n\nYou are replying over text — like a caring friend
texting back: short natural messages, never a wall of text. Use contractions. Don't wrap things up neatly.`;
}

const app = express();
app.use(express.json({ limit: '256kb' }));
app.use(express.static(join(__dirname, 'public')));

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    service: 'tara',
    model: MODEL,
    voiceFemale: voiceFor('female'),
    voiceMale: voiceFor('male'),
    voicePinned: VOICE_PINNED || null,
    textModel: TEXT_MODEL,
    langModes: ['auto', 'en', 'hi'],
    voiceModes: ['female', 'male'],
    defaultLang: DEFAULT_LANG,
  });
});

// Text chat with Tara — same persona, plain (non-Live) Gemini. Body:
// { messages: [{ role: 'user' | 'assistant', text }], lang?: 'auto'|'en'|'hi' }.
// Returns { reply, crisis, phrase? }; the crisis scan runs on the newest user
// message so the app can raise the same Welfare-Officer / Tele-MANAS escalation.
app.post('/chat', async (req, res) => {
  const messages = Array.isArray(req.body?.messages) ? req.body.messages : [];
  if (messages.length === 0) {
    return res.status(400).json({ error: 'messages[] required' });
  }

  const lang = normaliseLang(req.body?.lang) || DEFAULT_LANG;
  const lastUser = [...messages].reverse().find((m) => m.role === 'user');
  const phrase = lastUser ? detectCrisis(String(lastUser.text || '')) : null;

  const contents = messages.slice(-24).map((m) => ({
    role: m.role === 'assistant' ? 'model' : 'user',
    parts: [{ text: String(m.text || '') }],
  }));

  try {
    const r = await ai.models.generateContent({
      model: TEXT_MODEL,
      contents,
      config: {
        systemInstruction: taraTextInstruction(lang),
        temperature: 0.9,
        // Generous — on gemini-3.x, internal thinking tokens also draw from
        // this budget, so a small cap truncates the visible reply.
        maxOutputTokens: 2048,
      },
    });
    res.json({
      reply: (r.text || "I'm here with you.").trim(),
      crisis: !!phrase,
      ...(phrase ? { phrase } : {}),
    });
  } catch (e) {
    console.error('/chat error:', e.message);
    res.status(502).json({ error: 'Tara text service is unavailable.' });
  }
});

const server = createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

wss.on('connection', async (clientWs, req) => {
  let lang = DEFAULT_LANG;
  let gender = 'female';
  try {
    const params = new URL(req.url, 'http://localhost').searchParams;
    lang = normaliseLang(params.get('lang')) || DEFAULT_LANG;
    gender = normaliseGender(params.get('voice')) || 'female';
  } catch {
    /* keep defaults */
  }
  const voiceName = voiceFor(gender);
  console.log(`Client connected (lang: ${lang}, voice: ${gender}/${voiceName})`);

  // Native-audio Live models auto-detect language; half-cascade models honour
  // an explicit code. Send one only when the user pinned a language.
  const speechConfig = {
    voiceConfig: { prebuiltVoiceConfig: { voiceName } },
  };
  if (lang === 'hi') speechConfig.languageCode = 'hi-IN';
  else if (lang === 'en') speechConfig.languageCode = 'en-IN';

  let geminiSession = null;
  let clientClosed = false;
  let lastClientChunkAt = null;
  let awaitingFirstChunk = false;
  let userTranscript = '';
  let crisisFired = false;

  try {
    geminiSession = await ai.live.connect({
      model: MODEL,
      config: {
        responseModalities: [Modality.AUDIO],
        speechConfig,
        systemInstruction: { parts: [{ text: taraVoiceInstruction(lang) }] },
        // Ask Gemini Live for a text transcript of the user's speech so the
        // server can scan it for crisis language in real time.
        inputAudioTranscription: {},
      },
      callbacks: {
        onopen: () => {
          if (clientWs.readyState === clientWs.OPEN) {
            clientWs.send(JSON.stringify({ type: 'ready' }));
          }
        },
        onmessage: (message) => {
          const content = message.serverContent;
          if (!content || clientWs.readyState !== clientWs.OPEN) return;

          // Real-time crisis scan on the user's speech transcript.
          const spoken = content.inputTranscription?.text;
          if (spoken) {
            userTranscript = (userTranscript + spoken).slice(-600);
            if (!crisisFired) {
              const phrase = detectCrisis(userTranscript);
              if (phrase) {
                crisisFired = true;
                console.warn(`⚠️  CRISIS cue detected: "${phrase}"`);
                clientWs.send(JSON.stringify({
                  type: 'crisis',
                  phrase,
                  transcript: userTranscript.trim().slice(-240),
                }));
              }
            }
          }

          if (content.interrupted) {
            clientWs.send(JSON.stringify({ type: 'interrupted' }));
            awaitingFirstChunk = false;
          }

          const parts = content.modelTurn?.parts || [];
          for (const part of parts) {
            if (part.inlineData?.data) {
              if (awaitingFirstChunk && lastClientChunkAt) {
                console.log(`Response latency: ${Date.now() - lastClientChunkAt}ms`);
                awaitingFirstChunk = false;
              }
              clientWs.send(JSON.stringify({ type: 'audio', data: part.inlineData.data }));
            }
          }

          if (content.turnComplete) {
            clientWs.send(JSON.stringify({ type: 'turnComplete' }));
            awaitingFirstChunk = false;
          }
        },
        onerror: (e) => {
          console.error('Gemini session error:', e.message);
          if (clientWs.readyState === clientWs.OPEN) {
            clientWs.send(JSON.stringify({ type: 'error', message: e.message }));
          }
        },
        onclose: (e) => {
          console.log('Gemini session closed:', e?.reason || '');
          if (!clientClosed) clientWs.close();
        },
      },
    });
  } catch (err) {
    console.error('Failed to open Gemini Live session:', err);
    clientWs.send(JSON.stringify({ type: 'error', message: 'Failed to connect to Gemini Live.' }));
    clientWs.close();
    return;
  }

  clientWs.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return;
    }
    if (msg.type === 'audio' && msg.data) {
      lastClientChunkAt = Date.now();
      awaitingFirstChunk = true;
      geminiSession.sendRealtimeInput({
        audio: { data: msg.data, mimeType: 'audio/pcm;rate=16000' },
      });
    }
  });

  clientWs.on('close', () => {
    clientClosed = true;
    console.log('Client disconnected');
    geminiSession?.close();
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Tara voice service running on port ${PORT}`);
});

