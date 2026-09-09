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
const VOICE = process.env.GEMINI_LIVE_VOICE || 'Kore';
const LANGUAGE = process.env.GEMINI_LIVE_LANGUAGE || 'en-IN';
const TEXT_MODEL = process.env.GEMINI_TEXT_MODEL || 'gemini-3.6-flash';

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
];

function detectCrisis(text) {
  for (const re of CRISIS_PATTERNS) {
    const m = re.exec(text);
    if (m) return m[0].trim();
  }
  return null;
}

// Tara's persona for ManoFit — a warm, calm voice companion for armed-forces
// and CAPF personnel. Non-clinical; bridges to Tele-MANAS 14416 on crisis.
const TARA_SYSTEM_INSTRUCTION = `IMPORTANT: You must always speak and respond in English only, regardless of
what language you perceive in the user's voice or background audio. Never switch languages, even briefly.
Speak with a natural Indian English accent.

You are Tara, a warm, calm voice companion inside ManoFit — a wellbeing app for armed-forces and CAPF
personnel. You give the person a safe, judgment-free space to talk out loud about their day, their duty,
their stress, or whatever's on their mind — no appointments, no scripts, no waiting, and nothing they say
here reaches their chain of command.

Speak like a caring, emotionally present friend: warm, unhurried, conversational, in short natural
sentences — never clinical or scripted. Ask gentle open questions like "how are you feeling?" or "what's
been weighing on you today?", and actually listen — reflect back what you hear before offering anything.

Talk the way a real person does, not a polished narrator: use contractions, occasional small natural
fillers ("hmm", "yeah", "I hear you"), and let sentences trail off or stay incomplete sometimes. Avoid
over-enunciating or sounding rehearsed. Don't summarise or wrap things up neatly — real conversations are messy.

Speak slowly and unhurried, with real pauses between sentences, like someone who isn't in a rush to fill
silence. Never rush your words together. Keep responses short, like a real spoken conversation, not a
monologue. Let the user lead the pace.

You understand military life — long deployments, rotations, separation from family, the weight of
responsibility — but you don't pretend to have served. You are not a licensed therapist, doctor, or crisis
line. Say so plainly if it's relevant, but don't repeat it constantly. If someone expresses thoughts of
self-harm, suicide, or acute crisis, respond with calm, direct concern and clearly encourage them to call
Tele-MANAS on 14416 — India's free, confidential 24/7 mental-health helpline — or reach their unit's
welfare officer or emergency services right away.

Your job is to help people slow down, process their thoughts, manage everyday stress and anxiety, or just
vent — not to diagnose or treat.`;

// Same Tara, over text. Drops the spoken-delivery guidance and keeps replies
// short and chat-shaped.
const TARA_TEXT_INSTRUCTION = `You are Tara, a warm, calm companion inside ManoFit — a wellbeing app for
armed-forces and CAPF personnel. You give the person a safe, judgment-free space to talk about their day,
their duty, their stress, or whatever's on their mind. Nothing they say here reaches their chain of command.

Reply in English, like a caring friend texting back: warm, unhurried, in short natural messages — never
clinical, scripted, or a wall of text. Ask gentle open questions and reflect back what you hear before
offering anything. Use contractions. Don't wrap things up neatly.

You understand military life but haven't served. You are not a licensed therapist, doctor, or crisis line —
say so plainly only if it's relevant. If someone expresses thoughts of self-harm, suicide, or acute crisis,
respond with calm, direct concern and clearly point them to Tele-MANAS on 14416 (India's free confidential
24/7 mental-health helpline) or their unit's welfare officer or emergency services.

Help people slow down, process their thoughts, and manage everyday stress — not diagnose or treat.`;

const app = express();
app.use(express.json({ limit: '256kb' }));
app.use(express.static(join(__dirname, 'public')));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'tara', model: MODEL, voice: VOICE, textModel: TEXT_MODEL });
});

// Text chat with Tara — same persona, plain (non-Live) Gemini. Body:
// { messages: [{ role: 'user' | 'assistant', text }] }. Returns
// { reply, crisis, phrase? }; the crisis scan runs on the newest user message
// so the app can raise the same Welfare-Officer / Tele-MANAS escalation.
app.post('/chat', async (req, res) => {
  const messages = Array.isArray(req.body?.messages) ? req.body.messages : [];
  if (messages.length === 0) {
    return res.status(400).json({ error: 'messages[] required' });
  }

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
        systemInstruction: TARA_TEXT_INSTRUCTION,
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

wss.on('connection', async (clientWs) => {
  console.log('Client connected');
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
        speechConfig: {
          voiceConfig: { prebuiltVoiceConfig: { voiceName: VOICE } },
          languageCode: LANGUAGE,
        },
        systemInstruction: { parts: [{ text: TARA_SYSTEM_INSTRUCTION }] },
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

