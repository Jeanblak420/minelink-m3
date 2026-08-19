/* MineLink Chat — synthesized message sounds + per-viewer sound prefs.
 * No audio assets: short WebAudio blips. Mirrors CPS notification sounds.
 * Exposes window.ChatSound. */
(function () {
  let ctx = null;
  const ac = () => (ctx = ctx || new (window.AudioContext || window.webkitAudioContext)());

  // name -> array of [freq, startOffset(s), dur(s), type]
  const RECIPES = {
    none: [],
    chime: [[880, 0, 0.12, 'sine'], [1320, 0.09, 0.16, 'sine']],
    pop: [[420, 0, 0.06, 'triangle'], [720, 0.04, 0.08, 'sine']],
    ping: [[1600, 0, 0.16, 'sine']],
    knock: [[180, 0, 0.09, 'square'], [140, 0.12, 0.1, 'square']],
    bloop: [[300, 0, 0.1, 'sine'], [200, 0.08, 0.12, 'sine']],
    marimba: [[523, 0, 0.14, 'triangle'], [784, 0.1, 0.18, 'triangle']],
    glass: [[1046, 0, 0.1, 'sine'], [1568, 0.06, 0.14, 'sine'], [2093, 0.12, 0.1, 'sine']],
  };
  const NAMES = Object.keys(RECIPES);
  const LABELS = { none: 'Silent', chime: 'Chime', pop: 'Pop', ping: 'Ping', knock: 'Knock', bloop: 'Bloop', marimba: 'Marimba', glass: 'Glass' };

  function play(name) {
    const recipe = RECIPES[name] || RECIPES.chime;
    if (!recipe.length) return;
    let a;
    try { a = ac(); if (a.state === 'suspended') a.resume(); } catch (_) { return; }
    const t0 = a.currentTime;
    recipe.forEach(([f, off, dur, type]) => {
      const osc = a.createOscillator(); const g = a.createGain();
      osc.type = type || 'sine'; osc.frequency.value = f;
      g.gain.setValueAtTime(0.0001, t0 + off);
      g.gain.exponentialRampToValueAtTime(0.22, t0 + off + 0.012);
      g.gain.exponentialRampToValueAtTime(0.0001, t0 + off + dur);
      osc.connect(g); g.connect(a.destination);
      osc.start(t0 + off); osc.stop(t0 + off + dur + 0.02);
    });
  }

  const DKEY = (v) => `minelink_chat_snd_default_${v || 'anon'}`;
  const PKEY = (v) => `minelink_chat_snd_peruser_${v || 'anon'}`;
  const getDefault = (v) => { try { return localStorage.getItem(DKEY(v)) || 'chime'; } catch (_) { return 'chime'; } };
  const setDefault = (v, s) => { try { localStorage.setItem(DKEY(v), s); } catch (_) {} };
  const getPerUser = (v) => { try { return JSON.parse(localStorage.getItem(PKEY(v)) || '{}'); } catch (_) { return {}; } };
  const setPerUser = (v, uid, s) => { const m = getPerUser(v); if (!s) delete m[uid]; else m[uid] = s; try { localStorage.setItem(PKEY(v), JSON.stringify(m)); } catch (_) {} return m; };
  const soundFor = (v, uid) => getPerUser(v)[uid] || getDefault(v);

  window.ChatSound = { NAMES, LABELS, play, getDefault, setDefault, getPerUser, setPerUser, soundFor };
})();
