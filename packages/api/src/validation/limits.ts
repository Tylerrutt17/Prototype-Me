// Field length limits. Mirrored on the iOS client in FieldLimits.swift —
// keep these two files in sync when changing a value.
export const LIMITS = {
  directive: {
    title: 120,
    body: 1_000,
  },
  note: {
    title: 120,
    body: 10_000,
  },
  folder: {
    name: 60,
  },
  journal: {
    diary: 10_000,
    tag: 40,
    tagCount: 20,
  },
  ai: {
    /// Generic user prompt to any AI feature (wizard, signup goals, panel query)
    prompt: 1_000,
    /// Per-message limit for Speak tab (typed or voice-transcribed).
    /// Generous upper bound — ~3 minutes of continuous speech.
    speakMessage: 3_000,
  },
} as const;
