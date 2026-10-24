# Octune

A lightweight Flutter app that listens to live audio and shows **which note is playing right now**.

Octune is a practice companion, not a DAW. It stays small: listen, name the pitch, show how loud it is, keep time with a metronome. Later it can save practice as compact **note events** (pitch + time), not as heavy audio files.

## What it does (intent)

You play or sing. The app:

1. Captures microphone input
2. Detects the current pitch among the **12 chromatic notes** (C, C♯, D, D♯, E, F, F♯, G, G♯, A, A♯, B), plus octave when possible
3. Shows **amplitude** (how loud the signal is)
4. Offers a **metronome** (the click / tick-tick timekeeper) so you can practice in a set tempo

That is the whole product loop for v1.

## Why this shape

Recording raw audio is large and opaque. Recording **which notes happened when** is tiny and useful for learning: replay a phrase as notes, compare takes, share a practice trace. That format is **out of MVP**. The live detector is built first so later recording is just “log what we already see.”

## MVP (build this, nothing else)

This list is the finish line for the first usable app. Foundation (layers, deps, blank shell) is in place; features below are not built yet.

### In scope

| Goal | Done when |
| --- | --- |
| Live listen | Mic permission + start/stop listening on one screen |
| Note display | Current pitch shown as one of the 12 chromatic names (with accidental, e.g. F♯ / Gb policy decided and consistent) |
| Octave | Show octave (e.g. A4) when confidence is high enough; show “—” or “weak” when not |
| Amplitude | Live level (meter or number). Quiet vs playing is obvious |
| Metronome | BPM control, start/stop, audible click. Optional visual pulse. Default ~60–120 BPM range |
| Minimal UI | One screen. Dark, calm, large current note. No accounts, no cloud, no lesson library |
| Offline | Works with no network |

### Explicitly out of MVP

- Recording / export of any kind (audio or note events)
- Chords, polyphony, key detection, tuning graphs with cents history
- MIDI in/out, virtual instrument, backing tracks
- Score / tablature / song library
- Accounts, sync, social, IAP
- Multi-instrument calibration UI (one default pitch-detection path is enough)

### MVP success criteria

A person can open the app, tap listen, play a few notes on a real instrument or voice, and **see the correct note name update in near real time**, with a visible loudness meter and a usable metronome. Wrong-note rate on clear, single pitches should feel trustworthy in a quiet room. Noise / silence should **not** spam random notes.

## Later (after MVP): note-event recording

Not audio. A compact sequence of events, for example:

- timestamp (ms from start, or from metronome bar/beat)
- note (pitch class + octave)
- optional: amplitude, duration, on/off

Goals for that phase (when we get there):

- Tiny files compared to WAV/MP3
- Replay as a note stream (visual and/or click)
- Enough structure to add export formats later (MIDI is a candidate, not a requirement on day one)

## Design principles

- **One job:** name the note you are making
- **Lightweight:** few screens, few settings, fast start
- **Honest:** if the signal is junk, say so; do not guess loudly
- **Future-proof the data, not the UI:** live detection should produce the same note events we will later persist

## Architecture

Layers import inward only. Cross-layer dependencies go through abstract interfaces in `domain`. Platform plugins live only in `audio`. Widgets contain no business logic.

```
ui → application → domain ← engine
                 ↗
              audio
```

| Layer | Path | Imports | Role |
| --- | --- | --- | --- |
| domain | `lib/domain` | Dart SDK only | Pure models and ports |
| engine | `lib/engine` | `domain` only | DSP (pitch, amplitude); pure Dart |
| audio | `lib/audio` | `domain` only | Mic / playback / plugins |
| application | `lib/application` | `domain` | Riverpod controllers |
| ui | `lib/ui` | `application`, `domain` | Widgets |

Tests live under `test/` mirroring `lib/`. Every class in `domain` and `engine` has unit tests.

## Platform

Flutter (this repo). Target for MVP: whatever is easiest to run locally while building (desktop and/or Android). iOS can follow the same feature set.

## Status

Foundation only: layer folders, Riverpod, a blank dark shell. Features from the MVP table are not implemented yet.
