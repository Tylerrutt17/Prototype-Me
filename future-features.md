# Future Features

Ideas and planned features — not yet built. Organized by category.

---

## Goals & Progress Tracking

### Self-Reported Goal Check-Ins
- Periodic self-assessment on goal notes (e.g., struggling / okay / good / thriving)
- Creates a trend line over time — are you improving in this area?
- AI can correlate check-in ratings with directive engagement and journal entries
- Surface goals the user hasn't checked in on in a while, or where balloons keep expiring
- Goal progress for fuzzy goals ("make more friends") can't be tracked with task completion — self-reporting fits the trial-and-error philosophy

> Secondary priority. The core app is about habit building, not goal tracking. Build only when the habit loop is solid.

---

## AI Features

### Conversational Check-Ins
- Talk to the app anytime — how you feel, what you need, what's bothering you
- AI responds with relevant directives/notes, suggestions, auto-creates missing items
- Weekly check-in where user rates improvement in areas
- Over time AI learns how you operate and tailors recommendations

### AI Memory System
- Builds context over time from interactions (with a max size)
- Influences all responses based on accumulated understanding
- Could eventually use LoRA adapters per person for tone/style tailoring

### Daily AI Routines
- Review user's profile/data once daily, generate recommendations
- Summarize journal entries and add to context
- Generate creative push notifications
- Suggest shortening/combining directives into overarching premises
- Identify trouble areas and things that need more focus

### AI-Assisted Improvement
- Mark directives as "not working" and talk to AI about why — replace or merge them
- After voice check-in, AI identifies forgotten areas that need more focus
- Can query AI to find folders/files/notes (backed by API queries)

### Onboarding Chat
- 20-questions style onboarding to learn about the person
- "For me to perform best I need to XYZ", triggers, patterns, etc.

---

## Rebound Feature
- When feeling low/off, tap Rebound to figure out exactly what to do to get back
- AI helps identify what you need based on your directives, history, and patterns
- Could have mini-game Easter egg (shooting hoops themed)

---

## Memory & Retention
- Hidden directives game — hide them, try to remember before flipping over
- Acronym generator for notes/directives to aid memorization
- Acronym lock to open the app or a note (forces recall)
- Note reminders with novelty (fun facts inside to prevent ignoring)
- Randomly switch colors/move UI to keep brain viewing things as new

---

## Modes (Expanded Vision)
- Switching modes changes the entire app look, especially Focus tab
- Attack mode, sleep mode, rebound mode etc. — everything optimizes for the scenario
- Voice command: "Change the mode to sleep"
- "At some point these become habits, but this is a good way to lock them in"

---

## Notes Enhancements
- Version history for notes (premium feature) — see what changed over time
- Tier lists within notes — select stress level 1, 2, etc.
- Emphasize option — pin frequently-accessed directives within a note to top

---

## Directive Improvements
- Some balloons should be "harder to hold down" — need more UI interaction to not get away
- Emphasis/priority system based on scroll position and open frequency

---

## Integrations
- Google Calendar hookup for AI to understand schedule
- Build roadmaps of how user overcame things (addiction recovery paths, etc.)

---

## UX & Engagement
- App icon changes randomly on open to keep things fresh
- Creative AI-generated push notifications daily
- Lots of dummy data on first install so everything makes sense
- Clash Royale-style tab
- Wavy line animation that gets smoother over time (for onboarding)

---

## Technical
- Rate limiting on API routes
