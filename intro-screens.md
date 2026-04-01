# Intro / Onboarding Screens

> 10 pages total (failed solutions page commented out). See OnboardingStoryViewController.swift for implementation.

---

## 1. Hook

**Headline:** You've done this before

**Subtext:** The better habits. The goals. The fresh starts. It works for a while — *then it doesn't.*

**Visual:** Smooth glowing line — the "dialed in" vision. Gently pulses, edges subtly destabilize. (OnboardingVisionView)

---

## 2. The Gap

**Headline:** Why? The hard part isn't starting

**Subtext:** It's **sticking with it**. You try building better habits, it works, then life gets in the way and it fades. *Every time.*

**Visual:** Three progress bars that fill up then fade back down, one after another. (OnboardingBuildFadeView)

---

## 3. The Insight

**Headline:** What makes your best & worst days?

**Subtext:** It's not random. Your worst days have patterns — the things you skipped, the habits you dropped. **Fix those, and your best days happen on their own.**

**Visual:** Best/worst day comparison view. (OnboardingBestWorstDaysView)

---

## 4. Escalation

**Headline:** What's actually dragging you down?

**Subtext:** Low energy, bad habits, irritability. Some are **always there**. Some only show up in **certain situations**. If you've never mapped them out, *how would you know what to fix?*

**Visual:** Problem pills appearing in a list. (OnboardingShortcomingsView)

---

## ~~5. Failed Solutions~~ *(commented out)*

~~**Headline:** You've tried routines. They don't adapt.~~

~~**Subtext:** Habits apps, rules, willpower. They work until life changes — *then they break*. Because they were built for a version of you that **doesn't exist anymore**.~~

---

## 5. The Real Solution

**Headline:** Try things. See what sticks.

**Subtext:** Find the habits and practices that keep the lows from happening. Track what works, drop what doesn't. *No one can figure this out for you.*

**Visual:** Wavy line that starts jagged and smooths out. (OnboardingWavyLineView)

---

## 6. Transition

**Headline:** So how does it work?

**Subtext:** *(none)*

**Visual:** *(none — text only)*

---

## 7. Directives

**Headline:** These are Directives

**Subtext:** The small things that keep you from hitting a low. Habits, rules, reminders — they're not always exciting, **but they're what make the difference**.

**Visual:** "DIRECTIVES" title badge scales in, holds, fades out. Then directive cards appear one by one with staggered animations. (OnboardingDirectiveTrialView)

---

## 8. Figure Out What Works Best

**Headline:** Figure out what works best

**Subtext:** Some things will help, some won't. Swap what doesn't work, double down on what does. Over time, you learn exactly what keeps you **at your best**.

**Visual:** Framework card + two Mode cards (Computer Work, Exhausted / Rebound) with directives inside. Each directive gets magnified, strikethrough with thought bubble commentary, then replaced with something better. Word-by-word underline sweep on thoughts. (OnboardingSystemEvolvesView)

---

## 9. Track What's Working

**Headline:** Track what's working

**Subtext:** Rate your day. Write what happened. The app finds **patterns** — what dragged you down, what kept you steady. So you can see what's *actually* making the difference.

**Visual:** Animated calendar grid with mini-editor overlay. Demos: tap day → rate → type diary → save → dot fills on calendar. Loops. (OnboardingJournalDemoView)

---

## 10. CTA

**Headline:** Let's build your system

**Subtext:** Skip days. Change your mind. *The system adapts to how you actually live.* We'll help you set up a starter plan — you can change *everything* later.

**Visual:** App logo with "Prototype Me", celebration particles, "Get Started" button with pulse. (OnboardingHeroView)

---

## Post-Intro Setup Flow

After the story pages, the setup flow kicks in:

1. **FocusConsoleViewController** — "Let's build your personal system" hero + "Set Up My Plan" CTA
2. **AISignupChatViewController** — AI asks what you're working on, generates a seed plan
3. **SeedPlanReviewViewController** — Review/confirm generated plan
4. **WelcomeViewController** — "Welcome to Prototype Me" celebration, auto-dismisses

---

## Other Story Screens (accessible from feature tabs)

### Directives Story (DirectiveStoryViewController)
Accessed via "What are Directives?" info pill on DirectiveListViewController. 7 pages:
1. "Your best days aren't random" — erratic→smooth wave line
2. "You don't think your way there. You test your way there." — Try→Observe→Adjust cycle
3. "That's what directives are" — example directive types appearing
4. "Some will stick. Some won't." — cards appear, some fade/strikethrough, winners glow green
5. "The system keeps you honest" — Balloons, Schedules, History tool icons
6. "Over time, a pattern emerges" — scattered dots converge into grid
7. "That's your Framework" — golden star with "Discovered, not guessed" badge

### Balloons Story (BalloonStoryViewController)
Accessed via "What are Balloons?" info pill on BalloonsViewController. 9 pages covering forgetting curve, spaced repetition, balloon lifecycle, deflation, pumping.

### Journal Story (JournalStoryViewController)
Accessed via "How does the Diary work?" info pill on DiaryViewController. 3 pages:
1. "Rate your day" — calendar + editor demo
2. "The app finds your patterns" — AI insights with weekly/monthly summaries
3. "Small entries, big picture" — rising trend line with milestone dots
