/* MineLink Chat — messenger palettes + per-viewer theme store.
 * Ported from the CPS Smart Central chat theme provider, re-based on a MineLink
 * cyan/navy/slate DEFAULT (index 0) and re-labelled. Each palette is fully
 * self-contained so the overlay actually re-skins (its inner surfaces read the
 * palette, NOT the global CSS vars). Persisted per viewer in localStorage.
 * Exposed on window.ChatThemes. */
(function () {
  const P = (o) => o; // identity, for readability

  const PALETTES = [
    // 0 — MineLink (brand default: navy chrome, cyan accent, slate canvas)
    P({ id: 'minelink', name: 'MineLink', mode: 'light',
      header: '#0B192E', headerText: '#E6F6FB', tabIndicator: '#22C2DE', tabSelectedBg: '#0F2338',
      body: '#F4F8FB', bodyText: '#0F1B2D', bodySubtle: '#5A6B80', rowOdd: '#FFFFFF', divider: '#E2ECF3',
      accent: '#00B5D8', accentText: '#04222B',
      incomingBubble: '#FFFFFF', incomingText: '#0F1B2D', outgoingBubble: '#00B5D8', outgoingText: '#04222B',
      senderName: '#0E7C93', bubbleSeparator: '#E2ECF3', unreadBadge: '#00B5D8', unreadBadgeText: '#04222B' }),
    // 1 — Deep Navy (dark brand)
    P({ id: 'deep-navy', name: 'Deep Navy', mode: 'dark',
      header: '#08121F', headerText: '#DCEBFF', tabIndicator: '#22C2DE', tabSelectedBg: '#0E1D30',
      body: '#0B1725', bodyText: '#E8EFF8', bodySubtle: '#8DA2BC', rowOdd: '#122032', divider: '#1E3149',
      accent: '#2CC7E4', accentText: '#04222B',
      incomingBubble: '#152740', incomingText: '#EAF2FB', outgoingBubble: '#0E86A8', outgoingText: '#FFFFFF',
      senderName: '#6FD8EC', bubbleSeparator: '#2A4straal', unreadBadge: '#2CC7E4', unreadBadgeText: '#04222B' }),
    // 2 — Midnight Blue
    P({ id: 'midnight', name: 'Midnight Blue', mode: 'dark',
      header: '#0B1220', headerText: '#E2ECFF', tabIndicator: '#4F8CFF', tabSelectedBg: '#111A2E',
      body: '#070C18', bodyText: '#E8EEFB', bodySubtle: '#A3B3CC', rowOdd: '#152138', divider: '#22314f',
      accent: '#4F8CFF', accentText: '#06122B',
      incomingBubble: '#182748', incomingText: '#EAF1FF', outgoingBubble: '#2B6BFF', outgoingText: '#FFFFFF',
      senderName: '#8FB6FF', bubbleSeparator: '#33456b', unreadBadge: '#4F8CFF', unreadBadgeText: '#06122B' }),
    // 3 — Forest Green
    P({ id: 'forest', name: 'Forest Green', mode: 'dark',
      header: '#0E1A12', headerText: '#E5F5E9', tabIndicator: '#4CAF50', tabSelectedBg: '#142519',
      body: '#0A130D', bodyText: '#EAF5EE', bodySubtle: '#A9C2B0', rowOdd: '#162A1F', divider: '#22412c',
      accent: '#66BB6A', accentText: '#0A1A0E',
      incomingBubble: '#1A2E22', incomingText: '#EFFAF1', outgoingBubble: '#2E7D32', outgoingText: '#FFFFFF',
      senderName: '#9CDFA1', bubbleSeparator: '#2f5a3a', unreadBadge: '#66BB6A', unreadBadgeText: '#0A1A0E' }),
    // 4 — Royal Purple
    P({ id: 'royal', name: 'Royal Purple', mode: 'dark',
      header: '#160A22', headerText: '#F0E6FF', tabIndicator: '#B388FF', tabSelectedBg: '#1E0F30',
      body: '#0E0716', bodyText: '#EEE6FA', bodySubtle: '#B7A6CF', rowOdd: '#241335', divider: '#3a2359',
      accent: '#B388FF', accentText: '#160A22',
      incomingBubble: '#291846', incomingText: '#F3EBFF', outgoingBubble: '#6A1B9A', outgoingText: '#FFFFFF',
      senderName: '#D5BBFF', bubbleSeparator: '#4a2f6b', unreadBadge: '#B388FF', unreadBadgeText: '#160A22' }),
    // 5 — Crimson
    P({ id: 'crimson', name: 'Crimson', mode: 'dark',
      header: '#1C0A0E', headerText: '#FFE5E9', tabIndicator: '#FF5C7A', tabSelectedBg: '#260F14',
      body: '#110608', bodyText: '#FAE8EC', bodySubtle: '#D0A3AC', rowOdd: '#2B1017', divider: '#5a2130',
      accent: '#FF5C7A', accentText: '#1C0A0E',
      incomingBubble: '#3A1620', incomingText: '#FFEBEF', outgoingBubble: '#C2185B', outgoingText: '#FFFFFF',
      senderName: '#FF9DB2', bubbleSeparator: '#6b2f3f', unreadBadge: '#FF5C7A', unreadBadgeText: '#1C0A0E' }),
    // 6 — Steel Gray
    P({ id: 'steel', name: 'Steel Gray', mode: 'dark',
      header: '#1A1D21', headerText: '#E6E9EE', tabIndicator: '#90A4AE', tabSelectedBg: '#22262B',
      body: '#12151A', bodyText: '#E8ECEF', bodySubtle: '#B0B8BF', rowOdd: '#22262B', divider: '#39424a',
      accent: '#B0BEC5', accentText: '#12151A',
      incomingBubble: '#252A31', incomingText: '#EEF1F4', outgoingBubble: '#455A64', outgoingText: '#FFFFFF',
      senderName: '#CFD8DC', bubbleSeparator: '#3f4a52', unreadBadge: '#B0BEC5', unreadBadgeText: '#12151A' }),
    // 7 — Ocean Teal
    P({ id: 'ocean', name: 'Ocean Teal', mode: 'dark',
      header: '#062126', headerText: '#E0F7FA', tabIndicator: '#26C6DA', tabSelectedBg: '#0A2C32',
      body: '#03171B', bodyText: '#E6F6F8', bodySubtle: '#9FC1C6', rowOdd: '#0F3138', divider: '#124049',
      accent: '#26C6DA', accentText: '#03171B',
      incomingBubble: '#103E45', incomingText: '#E6F7FA', outgoingBubble: '#00838F', outgoingText: '#FFFFFF',
      senderName: '#7CEAF5', bubbleSeparator: '#1c5560', unreadBadge: '#26C6DA', unreadBadgeText: '#03171B' }),
    // 8 — Sunset
    P({ id: 'sunset', name: 'Sunset', mode: 'dark',
      header: '#221016', headerText: '#FFE6EB', tabIndicator: '#FF7043', tabSelectedBg: '#2B141C',
      body: '#170A10', bodyText: '#FAEAEE', bodySubtle: '#C9A6AE', rowOdd: '#2C1622', divider: '#552f38',
      accent: '#FF7043', accentText: '#170A10',
      incomingBubble: '#35192A', incomingText: '#FFEDED', outgoingBubble: '#D84315', outgoingText: '#FFFFFF',
      senderName: '#FFB199', bubbleSeparator: '#6b3f48', unreadBadge: '#FF7043', unreadBadgeText: '#170A10' }),
    // 9 — Charcoal (mono dark)
    P({ id: 'charcoal', name: 'Charcoal', mode: 'dark',
      header: '#161616', headerText: '#E6E6E6', tabIndicator: '#E0E0E0', tabSelectedBg: '#1E1E1E',
      body: '#0D0D0D', bodyText: '#EDEDED', bodySubtle: '#B3B3B3', rowOdd: '#1F1F1F', divider: '#333333',
      accent: '#E0E0E0', accentText: '#0D0D0D',
      incomingBubble: '#242424', incomingText: '#F2F2F2', outgoingBubble: '#424242', outgoingText: '#FFFFFF',
      senderName: '#EFEFEF', bubbleSeparator: '#3f3f3f', unreadBadge: '#E0E0E0', unreadBadgeText: '#0D0D0D' }),
    // 10 — Snow (light)
    P({ id: 'snow', name: 'Snow', mode: 'light',
      header: '#F1F4F8', headerText: '#1A1F2A', tabIndicator: '#1976D2', tabSelectedBg: '#FFFFFF',
      body: '#FAFBFD', bodyText: '#1A1F2A', bodySubtle: '#5A6473', rowOdd: '#F1F4F8', divider: '#dbe4ee',
      accent: '#1976D2', accentText: '#FFFFFF',
      incomingBubble: '#E8EEF6', incomingText: '#101521', outgoingBubble: '#1976D2', outgoingText: '#FFFFFF',
      senderName: '#0D47A1', bubbleSeparator: '#cdd9e8', unreadBadge: '#1976D2', unreadBadgeText: '#FFFFFF' }),
    // 11 — Cream (light)
    P({ id: 'cream', name: 'Cream', mode: 'light',
      header: '#FDF5E6', headerText: '#2A1E0A', tabIndicator: '#B8860B', tabSelectedBg: '#FFFAEB',
      body: '#FFF9EE', bodyText: '#2A1E0A', bodySubtle: '#7A6240', rowOdd: '#FAF0D9', divider: '#ecdcb6',
      accent: '#B8860B', accentText: '#FFFFFF',
      incomingBubble: '#F6E9CB', incomingText: '#1E1605', outgoingBubble: '#B8860B', outgoingText: '#FFFFFF',
      senderName: '#8B5A00', bubbleSeparator: '#e2cf9e', unreadBadge: '#B8860B', unreadBadgeText: '#FFFFFF' }),
    // 12 — Sage (light)
    P({ id: 'sage', name: 'Sage', mode: 'light',
      header: '#EEF4EC', headerText: '#12241A', tabIndicator: '#2E7D32', tabSelectedBg: '#F7FBF6',
      body: '#F6FAF5', bodyText: '#12241A', bodySubtle: '#4F6A55', rowOdd: '#EFF5ED', divider: '#d6e5d3',
      accent: '#2E7D32', accentText: '#FFFFFF',
      incomingBubble: '#E2EEDF', incomingText: '#0E1F14', outgoingBubble: '#2E7D32', outgoingText: '#FFFFFF',
      senderName: '#1B5E20', bubbleSeparator: '#c9ddc5', unreadBadge: '#2E7D32', unreadBadgeText: '#FFFFFF' }),
    // 13 — Rose (light)
    P({ id: 'rose', name: 'Rose', mode: 'light',
      header: '#FCE9EE', headerText: '#2A0A14', tabIndicator: '#C2185B', tabSelectedBg: '#FFF4F7',
      body: '#FFF6F8', bodyText: '#2A0A14', bodySubtle: '#7A4858', rowOdd: '#FCEEF2', divider: '#f0d5df',
      accent: '#C2185B', accentText: '#FFFFFF',
      incomingBubble: '#F7DCE4', incomingText: '#1F0810', outgoingBubble: '#C2185B', outgoingText: '#FFFFFF',
      senderName: '#880E4F', bubbleSeparator: '#e8c3d0', unreadBadge: '#C2185B', unreadBadgeText: '#FFFFFF' }),
    // 14 — Dracula
    P({ id: 'dracula', name: 'Dracula', mode: 'dark',
      header: '#282A36', headerText: '#F8F8F2', tabIndicator: '#FF79C6', tabSelectedBg: '#343746',
      body: '#1E1F29', bodyText: '#F8F8F2', bodySubtle: '#BFBFD9', rowOdd: '#313445', divider: '#44475a',
      accent: '#FF79C6', accentText: '#1E1F29',
      incomingBubble: '#3C3F52', incomingText: '#F8F8F2', outgoingBubble: '#BD93F9', outgoingText: '#1E1F29',
      senderName: '#8BE9FD', bubbleSeparator: '#565a70', unreadBadge: '#FF79C6', unreadBadgeText: '#1E1F29' }),
    // 15 — Nord
    P({ id: 'nord', name: 'Nord', mode: 'dark',
      header: '#2E3440', headerText: '#ECEFF4', tabIndicator: '#88C0D0', tabSelectedBg: '#3B4252',
      body: '#242933', bodyText: '#ECEFF4', bodySubtle: '#B7C0CC', rowOdd: '#353C4A', divider: '#3f4757',
      accent: '#88C0D0', accentText: '#242933',
      incomingBubble: '#3B4252', incomingText: '#ECEFF4', outgoingBubble: '#5E81AC', outgoingText: '#FFFFFF',
      senderName: '#A3D5E1', bubbleSeparator: '#4a5468', unreadBadge: '#88C0D0', unreadBadgeText: '#242933' }),
    // 16 — Cobalt
    P({ id: 'cobalt', name: 'Cobalt', mode: 'dark',
      header: '#002240', headerText: '#FFFFFF', tabIndicator: '#FFC600', tabSelectedBg: '#003355',
      body: '#001833', bodyText: '#FFFFFF', bodySubtle: '#B3D4FF', rowOdd: '#00305A', divider: '#0a3d69',
      accent: '#FFC600', accentText: '#001833',
      incomingBubble: '#003B6F', incomingText: '#FFFFFF', outgoingBubble: '#1F7AC2', outgoingText: '#FFFFFF',
      senderName: '#FFC600', bubbleSeparator: '#0f4d85', unreadBadge: '#FFC600', unreadBadgeText: '#001833' }),
    // 17 — High Contrast
    P({ id: 'high-contrast', name: 'High Contrast', mode: 'dark',
      header: '#000000', headerText: '#FFFFFF', tabIndicator: '#FFEB3B', tabSelectedBg: '#111111',
      body: '#000000', bodyText: '#FFFFFF', bodySubtle: '#E0E0E0', rowOdd: '#111111', divider: '#444400',
      accent: '#FFEB3B', accentText: '#000000',
      incomingBubble: '#1A1A1A', incomingText: '#FFFFFF', outgoingBubble: '#FFEB3B', outgoingText: '#000000',
      senderName: '#FFEB3B', bubbleSeparator: '#5a5a20', unreadBadge: '#FFEB3B', unreadBadgeText: '#000000' }),
  ];

  // fix one typo introduced above (keep palette valid)
  PALETTES[1].bubbleSeparator = '#2A4A66';

  const KEY = (viewer) => `minelink_chat_theme_${viewer || 'anon'}`;

  function get(viewer) {
    let id = null;
    try { id = localStorage.getItem(KEY(viewer)); } catch (_) {}
    return PALETTES.find((p) => p.id === id) || PALETTES[0];
  }
  function set(viewer, id) {
    try { localStorage.setItem(KEY(viewer), id); } catch (_) {}
    return PALETTES.find((p) => p.id === id) || PALETTES[0];
  }

  window.ChatThemes = { PALETTES, get, set, DEFAULT: PALETTES[0] };
})();
