# RemembrAI Design System & UX Architecture Notes

## 1. Executive Summary & Design Philosophy
RemembrAI has undergone a complete UI/UX transformation from a basic Material utility into an executive-grade Personal Business Memory and Execution Assistant, matching the aesthetic, typography, and tactile precision of industry standards like **Linear**, **Things 3**, **Notion Calendar**, and **Arc Mobile**.

### Core Tenets
1. **Calm, High-Contrast Minimalism**: The interface steps back so executive commitments and relationships command full focus. Content is framed by clean monochromatic surfaces, hairline borders (`0.5pt`), and deliberate indigo accenting (`#3B4CCA` light / `#4F62E2` dark).
2. **Predictable 8pt Spatial Scale**: Every margin, padding, gap, radius, and elevation strictly aligns with an 8pt mathematical grid (`4, 8, 12, 16, 20, 24, 32, 48`).
3. **Bilingual Typography & Legibility**: Line-heights are anchored at `1.55` across all body tiers, guaranteeing proper rendering of Bengali vowels and diacritics alongside English without clipping or awkward line wrapping.
4. **Deliberate Tactile Physics**: Touch interactions incorporate micro-spring transitions (`PressableScale` 0.97 scale factor with 120ms ease-out) and tactile haptic feedback (`lightImpact`, `mediumImpact`, `success`, `warning`).
5. **Strict Workflow & Safety Preservation**: The Master Rule remains inviolable: **Never silently turn AI inferences into permanent facts**. Every AI-extracted commitment, contact, and date remains visibly unconfirmed until reviewed and explicitly approved by the user.

---

## 2. Design Tokens

### 2.1 Color Palette (`lib/theme/design_tokens.dart`)

| Token | Light Mode | Dark Mode | Usage |
|---|---|---|---|
| **Background** | `#FAFAF9` (Stone 50) | `#0E0E0F` (True Charcoal) | Primary canvas |
| **Surface** | `#FFFFFF` (Pure White) | `#17171A` (Elevation 1) | Cards, sheets, dialogs |
| **Subtle** | `#F4F4F5` (Zinc 100) | `#202024` (Elevation 2) | Pill backgrounds, input fills |
| **Border** | `#E4E4E7` (Hairline Zinc) | `#27272A` (Subtle boundary) | Structural dividers (`0.5pt`) |
| **Foreground** | `#18181B` (Zinc 900) | `#F4F4F5` (Zinc 100) | Primary headers & labels |
| **Muted** | `#71717A` (Zinc 500) | `#A1A1AA` (Zinc 400) | Subtitles, metadata, timestamps |
| **Primary** | `#3B4CCA` (Deep Indigo) | `#4F62E2` (Electric Indigo) | Primary buttons, active tabs, FAB |
| **Success** | `#16A34A` (Emerald 600) | `#22C55E` (Emerald 500) | Completed promises, healthy cadences |
| **Warning** | `#D97706` (Amber 600) | `#F59E0B` (Amber 500) | Due soon, medium confidence |
| **Error** | `#DC2626` (Red 600) | `#EF4444` (Red 500) | Overdue obligations, destructive actions |

### 2.2 Typography Scale (`AppTypography`)
- **Display**: 28pt / SemiBold (1.2) - Hero numbers & ratios
- **Headline**: 20pt / Bold (1.25) - Screen titles
- **Title**: 16pt / SemiBold (1.3) - Section headers & card titles
- **Body Large**: 15pt / Regular (1.55) - Primary card content
- **Body Medium**: 13pt / Regular (1.55) - Standard lists & subtitles
- **Body Small**: 11pt / Regular (1.55) - Timestamps, helper notes
- **Label**: 12pt / Medium (1.4) - Badges, buttons, chips
- **Overline**: 10pt / SemiBold (1.1, +0.8 letter-spacing) - Category headers

### 2.3 Radii & Elevation
- `AppRadius.sm`: 8pt (Chips, input fields, badges)
- `AppRadius.md`: 12pt (Dialogs, detail cards, floating pills)
- `AppRadius.lg`: 16pt (Bottom sheets, message bubbles, list rows)
- `AppRadius.xl`: 24pt (Modal containers)
- `AppRadius.full`: 9999pt (Avatars, floating navigation pill bar, FAB)
- **Soft Shadows**: 3 elevation levels with ultra-diffuse ambient alpha (`0.03` - `0.08`), eliminating heavy Material shadows.

---

## 3. Base Component Library (`lib/widgets/`)

| Component | File | Description |
|---|---|---|
| **AppButton** | `app_button.dart` | 5 variants (Primary, Secondary, Ghost, Tonal, Destructive), 3 sizes (SM 32h, MD 42h, LG 48h), built-in loading indicator and haptics. |
| **AppCard** | `app_card.dart` | Card container with hairline border, subtle background, optional tap callback, and customizable padding. |
| **AppListRow** | `app_list_row.dart` | Standardized 64pt/72pt interactive row with leading icon/avatar, title, subtitle, optional badge, trailing action, and micro-press scale. |
| **AppBadge** | `app_badge.dart` | Compact status pill (Neutral, Success, Warning, Error, Info) with rounded corners and muted background tints. |
| **AppTextField** | `app_text_field.dart` | Floating rounded input field with prefix/suffix icon support, helper text, and validation styling. |
| **AppAvatar** | `app_avatar.dart` | Consistent circle avatar computing 2-letter initials with dynamic seed coloring and sizes (SM 28, MD 38, LG 48, XL 64). |
| **AppSectionHeader** | `app_section_header.dart` | Section title with item count bubble and optional right-aligned action link. |
| **AppEmptyState** | `app_empty_state.dart` | Minimalist zero-state placeholder with line-art icon, headline, message, and call-to-action button. |
| **AppSkeleton** | `app_skeleton.dart` | Shimmer-compatible placeholder box for graceful loading states. |
| **AppBottomSheet** | `app_bottom_sheet.dart` | Executive draggable modal bottom sheet with drag handle, title bar, and bottom inset handling. |

---

## 4. Navigation Architecture

### 4.1 Suspended Floating Pill Bar (`lib/screens/shell_screen.dart`)
- Instead of a traditional edge-to-edge system navigation bar, RemembrAI floats a suspended pill navigation bar (`32pt` radius, floating ambient shadow) above the content canvas.
- 4 Primary Tabs:
  1. **Home**: Executive agenda, audio daily briefing hero card, overdue alerts, and today deliverables.
  2. **Promises**: Filterable commitment list (All, Pending, Completed, Cancelled) and direction pills (Promised by Me, Expecting, Follow-ups, Tasks).
  3. **People**: Contact directory with touchpoint cadence status pills, duplicate detection, and companies directory.
  4. **Memory Hub**: Dedicated Notion/Linear-style full-page executive dashboard with 8 operational modules.
- **Center Elevated FAB**: Deep indigo (`#3B4CCA`) trigger that opens an executive `AppBottomSheet` offering 1-tap capture actions:
  - Voice Capture (real-time voice AI decoder)
  - Quick Note (text capture sheet)
  - Log Meeting (meeting intelligence form)

### 4.2 Executive Memory Hub (`lib/screens/memory_hub_screen.dart`)
Consolidates all secondary intelligence tools into a clean, searchable 2-column grid and grouped list:
- Meeting Intelligence
- Action & Follow-Up Drafts
- Companies Directory
- Reminders & Tasks
- Relationship Health Radar
- Activity Audit Timeline
- Dependability Analytics ("Say-Do" Ratio)
- Universal Global Search

---

## 5. Workflow Preservation & Verification Matrix

| Workflow | Pre-Redesign State | Post-Redesign State | Verification Status |
|---|---|---|---|
| **AI Confirmation Gate** | Items unconfirmed until saved | Explicit checkboxes, confidence pills, editable fields, single save button | Verified & Preserved |
| **Multi-Party Disambiguation** | Prompts for Person A, B, D | Visual participant cards, known contact autocomplete, voice feedback | Verified & Preserved |
| **Voice Capture Watchdog** | Mic button stayed active | Active timer watchdog auto-syncs UI when speech recognizer pauses | Verified & Preserved |
| **Communication Drafts** | RFC 6068 email & wa.me launch | Preserved with permission gate, custom channel pills, and copy fallbacks | Verified & Preserved |
| **Touchpoint Cadence Radar** | Tracked cadence days | Cadence health pills, overdue days calculation, instant draft generation | Verified & Preserved |
| **Groq/Gemini Multi-Model** | Cloud cascade with offline rules | Resilient multi-model cascade preserved in all AI services | Verified & Preserved |
| **Hardware Companion Simulator** | Companion event bus | Preserved with OLED mockup, haptics, and event log | Verified & Preserved |
| **Local Data Privacy** | SQLite JSON export / restore / wipe | Preserved with confirmation gates and clipboard integration | Verified & Preserved |

---

## 6. How to Run & Test
1. Connect Android device (`SM A366B`) or launch emulator.
2. Run app in debug mode:
   ```powershell
   flutter run
   ```
3. Test dark mode by toggling system theme in device settings; verify stone/charcoal color transitions.
4. Test Bengali voice notes using the 'বাংলা' chip in the Voice Capture screen.
