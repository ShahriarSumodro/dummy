# Dummy. — Decision Log

All architectural, product, and technical decisions are recorded here.

---

## DEC-001: Mobile Framework — Flutter

**Date:** 2024-11-13  
**Decision:** Use Flutter (Dart) as the mobile framework.  
**Alternatives considered:** Kotlin/Jetpack Compose (Android native), React Native  
**Rationale:**
- Cross-platform: one codebase for Android now, iOS later.
- Supports the "one platform, multiple interfaces" vision (mobile, wearable, desktop).
- Hot reload for fast iteration.
- Dart is approachable for non-professional developers.
- Large widget ecosystem with Material 3 support.
- Well-supported by AI coding tools.
**Trade-offs:**
- Slightly larger APK than native Kotlin.
- Some platform-specific features require platform channels.
- Less native "feel" than pure Kotlin/Compose (though Material 3 helps).
**Status:** Confirmed

---

## DEC-002: Target Platform — Android First

**Date:** 2024-11-13  
**Decision:** Build for Android first.  
**Rationale:** User's personal device is Android. First test users are likely Android users (Bangladesh market is ~85% Android).  
**Status:** Confirmed

---

## DEC-003: App Name — Dummy.

**Date:** 2024-11-13  
**Decision:** Working name is "Dummy.".  
**Rationale:** User-designated name.  
**Status:** Confirmed

---


## DEC-004: Navigation Structure — 4-Tab Bottom Navigation

**Date:** 2024-11-13  
**Decision:** Use a bottom navigation bar with four primary destinations: Home, Promises, People, and Memory.

**Rationale:**
- Home provides an overview of important information and upcoming activities.
- Promises centralizes commitments, obligations, and follow-ups.
- People manages contacts and relationship context.
- Memory provides access to stored personal information and contextual records.
- Reminders, meetings, and drafts remain accessible through relevant screens rather than occupying separate primary navigation tabs.

**Status:** Confirmed for MVP


---

## DEC-005: Build Approach — Incremental, Feature by Feature

**Date:** 2024-11-13  
**Decision:** Build one feature at a time, test it, then move to the next.  
**Rationale:** Reduces complexity, ensures each feature actually works before adding more.  
**Status:** Confirmed


---


## DEC-006: AI Extraction & Confirmation Architecture

**Date:** 2024-11-13  
**Decision:** Use AiService for extracting structured information from unstructured user input. Support cloud AI providers and local/mock fallback mechanisms where available.

**Rationale:**
- Never silently turn an uncertain AI guess into a confirmed personal fact.
- Extracted contacts, promises, reminders, and memories must follow the appropriate review and verification process.
- Unverified memories must remain distinguishable from user-confirmed information.
- Keep AI provider integrations modular to support future model and vendor changes.
- MockAiService supports testing without API keys or external service costs.

**Status:** Implemented, with verification safeguards

