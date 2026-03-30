# Intro / Onboarding Screens

> 10 pages total. See OnboardingStoryViewController.swift for implementation.

---

## 1. Hook

**Headline:** You already know what you want.

**Subtext:** Better habits. Sharper focus. A life that actually feels dialed in. You can picture it -- you just can't seem to stay there.

**Visual:** Smooth glowing line — the "dialed in" vision. Gently pulses, edges subtly destabilize (you can see it but can't hold it). (OnboardingVisionView)

---

## 2. The Gap

**Headline:** The hard part isn't starting

**Subtext:** It's sticking with it. You build a habit, it works, then life gets in the way and it fades. Every time.

**Visual:** Three progress bars that fill up (building a habit) then fade back down, one after another — showing the "every time" cycle. (OnboardingBuildFadeView)

---

## 3. The Insight

**Headline:** What makes your best days?

**Subtext:** You've had stretches where everything clicked. The difference wasn't luck -- it was patterns you never tracked.

**Visual:** Forgetting curve graph (StoryScienceGraphView, .forgettingCurve)

---

## 4. The Solution

**Headline:** Now you can track them

**Subtext:** Build habits. Spot patterns. Figure out what actually works for you -- and keep it.

**Visual:** Wavy line that starts jagged and smooths out, with Directive/Mode/Balloon icons popping in (OnboardingWavyLineView)

---

## 5. Journal

**Headline:** Journal

**Subtext:** Rate your day. Write what happened. Tag what mattered. Over time, you'll see exactly what your best and worst days have in common.

**Visual:** Mock journal entry cards with rating circles, dates, previews, and tags staggering in (OnboardingJournalDemoView)

---

## 6. Directives

**Headline:** Directives

**Subtext:** The building blocks. Your goals, habits, and commitments -- written down so they don't live rent-free in your head.

**Visual:** Mock directive cards with staggered spring animations (OnboardingDirectiveCardsView)

---

## 7. Modes

**Headline:** Modes

**Subtext:** Different states for different situations. Activate a mode and your Focus tab filters to just what's relevant. Over time, they become second nature.

**Visual:** Three mode cards with shimmer selection animation (OnboardingModeCardsView)

---

## 8. Balloons

**Headline:** Balloons

**Subtext:** Attach a balloon to anything you want to periodically keep top of mind. You'll get a push notification when it runs out -- pump it back up to keep it fresh.

**Visual:** Balloons rise, middle deflates (red), pumps back up (green). "Built on Cognitive Science" badge. (OnboardingBalloonDemoView)

---

## 9. Differentiator

**Headline:** This is not a rulebook

**Subtext:** Skip days. Change your mind. The system adapts to how you actually live -- not how you think you should.

**Visual:** Leaf icon with gentle floating animation (OnboardingRelaxedView)

---

## 10. CTA

**Headline:** Let's build your system

**Subtext:** We'll help you set up a starter plan. You can change everything later -- this is just the beginning.

**Visual:** App logo with "Prototype Me", celebration particles, "Get Started" button with pulse (OnboardingHeroView)

---

## Post-Intro Setup Flow

After the story pages, the setup flow kicks in (unchanged):

1. **FocusConsoleViewController** -- "Let's build your personal system" hero + "Set Up My Plan" CTA
2. **AISignupChatViewController** -- AI asks what you're working on, generates a seed plan
3. **SeedPlanReviewViewController** -- Review/confirm generated plan
4. **WelcomeViewController** -- "Welcome to Prototype Me" celebration, auto-dismisses

---

## Future Ideas

- Additional feature slides (AI check-ins, Rebound, Memory system) -- add if/when those features are ready
