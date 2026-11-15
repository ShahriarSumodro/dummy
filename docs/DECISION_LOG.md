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
**Decision:** Use a bottom navigation bar with 4 tabs: Home, People, Commitments, Reminders.  
**Rationale:**
- Keeps the interface simple and focused on the core product.
- Each tab maps to a primary user workflow.
- Bottom nav is the standard Android pattern for top-level destinations.
- 4 tabs is within Material Design guidelines (3-5 recommended).
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
**Decision:** Extract unstructured notes via `AiService` (Gemini API with offline fallback), always requiring an explicit user review screen before committing to SQLite.  
**Rationale:**
- Directly satisfies the core philosophy: *Never silently turn an uncertain AI guess into a confirmed fact*.
- Users maintain 100% control over their personal business memory records.
- Architecture is decoupled via `AiService` interface, making model or vendor changes zero-cost.
- `MockAiService` allows offline testing with zero API keys or external costs.
**Status:** Implemented
