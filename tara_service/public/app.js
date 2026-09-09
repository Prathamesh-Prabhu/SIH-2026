const callBtn = document.getElementById('callBtn');
const callWrap = document.getElementById('callWrap');
const statusEl = document.getElementById('status');
const langToggle = document.getElementById('langToggle');

let ws = null;
let captureCtx = null;
let playCtx = null;
let mediaStream = null;
let sourceNode = null;
let processorNode = null;
let nextPlayTime = 0;
let activeSources = [];
let isActive = false;
let starting = false;
let taraSpeaking = false;

// Bumped on every startCall / endCall. A stale WebSocket (from a call the user
// already ended) carries an older id and its messages are ignored — this is
// what stops two Tara voices from ever playing at once.
let generation = 0;

// Auto-hangup: if nobody has spoken (neither the user nor Tara) for this long,
// the call ends itself. Covers "I forgot to hang up".
const IDLE_LIMIT_MS = 90_000;
let lastActivityAt = 0;
let idleInterval = null;

// Spoken language: 'auto' (mirror the user, Hindi/English), 'en', or 'hi'.
let lang = 'auto';
try {
  const saved = localStorage.getItem('tara_lang');
  if (saved === 'auto' || saved === 'en' || saved === 'hi') lang = saved;
} catch (e) {}

const BARGE_IN_RMS_THRESHOLD = 0.02;

// Gemini Live has no speaking-rate config, so we slow playback mechanically.
// Below 1.0 also lowers pitch slightly (not true time-stretching) — tune to taste.
const PLAYBACK_RATE = 0.88;

function setStatus(text) {
  statusEl.textContent = text;
}

function markActivity() {
  lastActivityAt = Date.now();
}

function floatTo16BitPCM(float32Array) {
  const out = new Int16Array(float32Array.length);
  for (let i = 0; i < float32Array.length; i++) {
    const s = Math.max(-1, Math.min(1, float32Array[i]));
    out[i] = s < 0 ? s * 0x8000 : s * 0x7fff;
  }
  return out;
}

function int16ToFloat32(int16Array) {
  const out = new Float32Array(int16Array.length);
  for (let i = 0; i < int16Array.length; i++) {
    out[i] = int16Array[i] / (int16Array[i] < 0 ? 0x8000 : 0x7fff);
  }
  return out;
}

function bufferToBase64(buffer) {
  let binary = '';
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary);
}

function base64ToBuffer(base64) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

function playChunk(int16Array) {
  // The context can be gone (call ended) or not yet running — never schedule
  // onto a dead context, that's how overlapping tails happen.
  if (!playCtx || playCtx.state === 'closed') return;
  const float32 = int16ToFloat32(int16Array);
  const buffer = playCtx.createBuffer(1, float32.length, 24000);
  buffer.copyToChannel(float32, 0);
  const src = playCtx.createBufferSource();
  src.buffer = buffer;
  src.playbackRate.value = PLAYBACK_RATE;
  src.connect(playCtx.destination);
  const startTime = Math.max(playCtx.currentTime, nextPlayTime);
  src.start(startTime);
  nextPlayTime = startTime + buffer.duration / PLAYBACK_RATE;
  activeSources.push(src);
  src.onended = () => {
    activeSources = activeSources.filter((s) => s !== src);
  };
}

function clearPlayback() {
  activeSources.forEach((s) => {
    try { s.onended = null; s.stop(); } catch (e) {}
  });
  activeSources = [];
  nextPlayTime = playCtx ? playCtx.currentTime : 0;
}

function rms(float32Array) {
  let sum = 0;
  for (let i = 0; i < float32Array.length; i++) sum += float32Array[i] * float32Array[i];
  return Math.sqrt(sum / float32Array.length);
}

async function beginCapture() {
  mediaStream = await navigator.mediaDevices.getUserMedia({
    audio: { channelCount: 1, echoCancellation: true, noiseSuppression: true },
  });

  captureCtx = new AudioContext({ sampleRate: 16000 });
  sourceNode = captureCtx.createMediaStreamSource(mediaStream);
  processorNode = captureCtx.createScriptProcessor(4096, 1, 1);

  processorNode.onaudioprocess = (event) => {
    if (!ws || ws.readyState !== WebSocket.OPEN) return;
    const input = event.inputBuffer.getChannelData(0);
    const level = rms(input);

    // Any real speech from the user keeps the call alive.
    if (level >= BARGE_IN_RMS_THRESHOLD) markActivity();

    if (taraSpeaking) {
      if (level < BARGE_IN_RMS_THRESHOLD) {
        // Below speech threshold while Tara is talking — likely silence, ambient
        // noise, or her own voice bleeding into the mic. Don't forward it.
        return;
      }
      // Loud enough to be a real interruption: cut her off locally right away.
      taraSpeaking = false;
      clearPlayback();
      setStatus(statusFor('listening'));
    }

    const pcm16 = floatTo16BitPCM(input);
    ws.send(JSON.stringify({ type: 'audio', data: bufferToBase64(pcm16.buffer) }));
  };

  sourceNode.connect(processorNode);
  processorNode.connect(captureCtx.destination);
}

const COPY = {
  tap:       { auto: 'Tap to talk to Tara',        en: 'Tap to talk to Tara',        hi: 'बात करने के लिए टैप करें' },
  connecting:{ auto: 'Connecting…',                en: 'Connecting…',                hi: 'कनेक्ट हो रहा है…' },
  listening: { auto: 'Listening…',                 en: 'Listening…',                 hi: 'सुन रही हूँ…' },
  speaking:  { auto: 'Tara is speaking…',          en: 'Tara is speaking…',          hi: 'तारा बोल रही है…' },
  micDenied: { auto: 'Microphone access denied',   en: 'Microphone access denied',   hi: 'माइक्रोफ़ोन की अनुमति नहीं मिली' },
  quiet:     { auto: 'Call ended after a quiet stretch — tap to talk again.',
               en:   'Call ended after a quiet stretch — tap to talk again.',
               hi:   'काफ़ी देर शांति रहने पर कॉल बंद हो गई — दोबारा बात करने के लिए टैप करें।' },
  paused:    { auto: 'Call ended — tap to talk again.',
               en:   'Call ended — tap to talk again.',
               hi:   'कॉल बंद हो गई — दोबारा बात करने के लिए टैप करें।' },
};

function statusFor(key) {
  const row = COPY[key] || {};
  return row[lang] || row.auto || '';
}

function startIdleWatch() {
  stopIdleWatch();
  markActivity();
  idleInterval = setInterval(() => {
    if (!isActive) return;
    if (Date.now() - lastActivityAt > IDLE_LIMIT_MS) {
      endCall();
      setStatus(statusFor('quiet'));
    }
  }, 5000);
}

function stopIdleWatch() {
  if (idleInterval) { clearInterval(idleInterval); idleInterval = null; }
}

async function startCall() {
  if (isActive || starting) return;
  starting = true;
  generation++;
  const myGen = generation;

  isActive = true;
  taraSpeaking = false;
  callWrap.classList.add('active');
  setStatus(statusFor('connecting'));

  playCtx = new AudioContext({ sampleRate: 24000 });
  nextPlayTime = 0;

  const protocol = location.protocol === 'https:' ? 'wss' : 'ws';
  ws = new WebSocket(`${protocol}://${location.host}/ws?lang=${encodeURIComponent(lang)}`);

  ws.onmessage = async (event) => {
    if (myGen !== generation) return; // stale socket from an ended call
    const msg = JSON.parse(event.data);
    if (msg.type === 'ready') {
      setStatus(statusFor('listening'));
      try {
        await beginCapture();
        startIdleWatch();
      } catch (err) {
        setStatus(statusFor('micDenied'));
        endCall();
      }
    } else if (msg.type === 'audio') {
      const buf = base64ToBuffer(msg.data);
      playChunk(new Int16Array(buf));
      taraSpeaking = true;
      markActivity();
      setStatus(statusFor('speaking'));
    } else if (msg.type === 'interrupted') {
      clearPlayback();
      taraSpeaking = false;
      setStatus(statusFor('listening'));
    } else if (msg.type === 'turnComplete') {
      taraSpeaking = false;
      setStatus(statusFor('listening'));
    } else if (msg.type === 'crisis') {
      // The server heard crisis language. Hand off to the host app, which
      // alerts the Welfare Officer and surfaces Tele-MANAS 14416.
      setStatus('It sounds really heavy right now — connecting you to help.');
      try {
        if (window.CrisisChannel) {
          window.CrisisChannel.postMessage(JSON.stringify(msg));
        }
      } catch (e) {}
    } else if (msg.type === 'error') {
      setStatus(`Error: ${msg.message}`);
    }
  };

  ws.onerror = () => {
    if (myGen === generation) setStatus('Connection error — is the Tara service running?');
  };
  ws.onclose = () => {
    if (myGen === generation && isActive) endCall();
  };

  starting = false;
}

function endCall() {
  // Invalidate any in-flight socket callbacks immediately.
  generation++;
  isActive = false;
  starting = false;
  taraSpeaking = false;
  callWrap.classList.remove('active');
  setStatus(statusFor('tap'));

  stopIdleWatch();
  clearPlayback();

  if (processorNode) { processorNode.disconnect(); processorNode.onaudioprocess = null; processorNode = null; }
  if (sourceNode) { sourceNode.disconnect(); sourceNode = null; }
  if (mediaStream) { mediaStream.getTracks().forEach((t) => t.stop()); mediaStream = null; }
  if (captureCtx) { captureCtx.close(); captureCtx = null; }
  if (playCtx) { playCtx.close(); playCtx = null; }
  if (ws) {
    ws.onmessage = null;
    ws.onerror = null;
    ws.onclose = null;
    try { ws.close(); } catch (e) {}
    ws = null;
  }
}

// ── Language toggle ────────────────────────────────────────────────────────
function paintLangToggle() {
  if (!langToggle) return;
  langToggle.querySelectorAll('button').forEach((b) => {
    b.classList.toggle('on', b.dataset.lang === lang);
  });
}

function setLang(next) {
  if (next === lang) return;
  lang = next;
  try { localStorage.setItem('tara_lang', lang); } catch (e) {}
  paintLangToggle();
  if (isActive) {
    // Reconnect so the new language reaches Gemini for this session.
    endCall();
    setTimeout(startCall, 150);
  } else {
    setStatus(statusFor('tap'));
  }
}

if (langToggle) {
  langToggle.addEventListener('click', (e) => {
    const btn = e.target.closest('button[data-lang]');
    if (btn) setLang(btn.dataset.lang);
  });
  paintLangToggle();
}

// ── Auto-end when the WebView is hidden / app backgrounded ─────────────────
document.addEventListener('visibilitychange', () => {
  if (document.hidden && isActive) {
    endCall();
    setStatus(statusFor('paused'));
  }
});
window.addEventListener('pagehide', () => { if (isActive) endCall(); });

// ── Bridge for the Flutter host to force a hangup ─────────────────────────
window.__taraEndCall = () => { if (isActive || starting) endCall(); };
window.__taraIsActive = () => isActive;

callBtn.addEventListener('click', () => {
  if (isActive) {
    endCall();
  } else {
    startCall();
  }
});

setStatus(statusFor('tap'));
