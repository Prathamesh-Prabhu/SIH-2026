const callBtn = document.getElementById('callBtn');
const callWrap = document.getElementById('callWrap');
const statusEl = document.getElementById('status');

let ws = null;
let captureCtx = null;
let playCtx = null;
let mediaStream = null;
let sourceNode = null;
let processorNode = null;
let nextPlayTime = 0;
let activeSources = [];
let isActive = false;
let taraSpeaking = false;

const BARGE_IN_RMS_THRESHOLD = 0.02;

// Gemini Live has no speaking-rate config, so we slow playback mechanically.
// Below 1.0 also lowers pitch slightly (not true time-stretching) — tune to taste.
const PLAYBACK_RATE = 0.88;

function setStatus(text) {
  statusEl.textContent = text;
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
    try { s.stop(); } catch (e) {}
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

    if (taraSpeaking) {
      if (rms(input) < BARGE_IN_RMS_THRESHOLD) {
        // Below speech threshold while Tara is talking — likely silence, ambient
        // noise, or her own voice bleeding into the mic. Don't forward it.
        return;
      }
      // Loud enough to be a real interruption: cut her off locally right away.
      taraSpeaking = false;
      clearPlayback();
      setStatus('Listening…');
    }

    const pcm16 = floatTo16BitPCM(input);
    ws.send(JSON.stringify({ type: 'audio', data: bufferToBase64(pcm16.buffer) }));
  };

  sourceNode.connect(processorNode);
  processorNode.connect(captureCtx.destination);
}

async function startCall() {
  isActive = true;
  taraSpeaking = false;
  callWrap.classList.add('active');
  setStatus('Connecting…');

  playCtx = new AudioContext({ sampleRate: 24000 });

  const protocol = location.protocol === 'https:' ? 'wss' : 'ws';
  ws = new WebSocket(`${protocol}://${location.host}/ws`);

  ws.onmessage = async (event) => {
    const msg = JSON.parse(event.data);
    if (msg.type === 'ready') {
      setStatus('Listening…');
      try {
        await beginCapture();
      } catch (err) {
        setStatus('Microphone access denied');
        endCall();
      }
    } else if (msg.type === 'audio') {
      const buf = base64ToBuffer(msg.data);
      playChunk(new Int16Array(buf));
      taraSpeaking = true;
      setStatus('Tara is speaking…');
    } else if (msg.type === 'interrupted') {
      clearPlayback();
      taraSpeaking = false;
      setStatus('Listening…');
    } else if (msg.type === 'turnComplete') {
      taraSpeaking = false;
      setStatus('Listening…');
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

  ws.onerror = () => setStatus('Connection error — is the Tara service running?');
  ws.onclose = () => {
    if (isActive) endCall();
  };
}

function endCall() {
  isActive = false;
  callWrap.classList.remove('active');
  setStatus('Tap to talk to Tara');

  clearPlayback();

  if (processorNode) { processorNode.disconnect(); processorNode.onaudioprocess = null; processorNode = null; }
  if (sourceNode) { sourceNode.disconnect(); sourceNode = null; }
  if (mediaStream) { mediaStream.getTracks().forEach((t) => t.stop()); mediaStream = null; }
  if (captureCtx) { captureCtx.close(); captureCtx = null; }
  if (playCtx) { playCtx.close(); playCtx = null; }
  if (ws) { ws.close(); ws = null; }
}

callBtn.addEventListener('click', () => {
  if (isActive) {
    endCall();
  } else {
    startCall();
  }
});
