# Octune main screen
Landscape-first, portrait fallback (stack vertically). One screen. Dark, calm, one accent
(blue), red used only for active capture.

1. Capture button (top-left): red dot. One tap starts listening (asks mic permission on
   first use); tap again stops. While listening: icon becomes a stop square, and red glow
   strips appear along the left and right screen edges with a slow pulse.
2. Note-scale strip (top center): graph of accepted frequency range drawn on a note scale
   (one tick per semitone, taller tick plus label at each C). Shows live strength per
   semitone and a marker at the detected pitch. Out-of-range areas are dimmed.
3. Note ring (top right): 12 segments (C at top, clockwise). Segment brightness follows
   recent pitch-class energy with decay. The stable note's segment is highlighted in blue.
4. Current note (center): octave number small, blue, upper-left; note letter large;
   accidental small, upper-right. Shows "—" dimmed when no stable note.
5. Recent notes (below the current note): last 2 stable notes, newest first, smaller and dim.
6. Metronome pendulum (bottom-left): icon swings in time with the real metronome; clicks
   occur at the ends of each swing. Tap opens the metronome sheet.
7. Signal panel (bottom-right): spectrum curve, label with the highest peak frequency,
   dotted threshold line and dotted noise-floor line, vertical amplitude bar at its right.
8. Settings gear (bottom-right corner).

States: idle, requesting permission, listening without signal, listening with note,
weak signal, permission denied, permission permanently denied, interrupted, error.
Rules: never show a guessed note; never rely on color alone; support text scaling and
screen readers; respect reduce-motion.
