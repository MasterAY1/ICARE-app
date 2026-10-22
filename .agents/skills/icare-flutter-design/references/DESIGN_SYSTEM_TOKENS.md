# ICARE Design System Tokens

Authoritative design token specifications for the ICARE Core Banking Flutter ecosystem.

---

## 1. Color Palette Tokens

ICARE utilizes an institutional deep-forest emerald palette paired with high-clarity slate surfaces and semantic risk tints.

### 1.1 Brand & Primary Colors
| Token Name | Hex Code | Flutter Value | Semantic Purpose |
| :--- | :--- | :--- | :--- |
| `primaryDark` | `#022C22` | `Color(0xFF022C22)` | Deep Forest Emerald (Login backdrop, dark headers) |
| `primary` | `#064E3B` | `Color(0xFF064E3B)` | Core Brand Emerald (Primary buttons, active states) |
| `primaryMedium` | `#0F766E` | `Color(0xFF0F766E)` | Teal Emerald (Accents, active borders, focus rings) |
| `primaryLight` | `#10B981` | `Color(0xFF10B981)` | Vivid Emerald (Positive indicators, trend up) |
| `primarySurface` | `#ECFDF5` | `Color(0xFFECFDF5)` | Soft Mint Tint (Badges, active card highlights) |

### 1.2 Neutral & Surface Hierarchy
| Token Name | Hex Code | Flutter Value | Semantic Purpose |
| :--- | :--- | :--- | :--- |
| `surfaceBackground`| `#F8FAFC` | `Color(0xFFF8FAFC)` | Canvas background (Slate 50) |
| `surfaceCard` | `#FFFFFF` | `Color(0xFFFFFFFF)` | Primary card & dialog surface |
| `surfaceHover` | `#F1F5F9` | `Color(0xFFF1F5F9)` | Table row / card hover state (Slate 100) |
| `surfaceMuted` | `#E2E8F0` | `Color(0xFFE2E8F0)` | Hairline container fill (Slate 200) |
| `borderHairline` | `#E2E8F0` | `Color(0xFFE2E8F0)` | Institutional 1px hairline border |
| `borderSubtle` | `#CBD5E1` | `Color(0xFFCBD5E1)` | Input field border, divider lines |
| `borderFocus` | `#0F766E` | `Color(0xFF0F766E)` | Active input focus ring border |

### 1.3 Typographic Grayscale
| Token Name | Hex Code | Flutter Value | Semantic Purpose |
| :--- | :--- | :--- | :--- |
| `textPrimary` | `#0F172A` | `Color(0xFF0F172A)` | High-contrast headers, bold financial numbers |
| `textSecondary` | `#475569` | `Color(0xFF475569)` | Body copy, secondary titles, form labels |
| `textMuted` | `#64748B` | `Color(0xFF64748B)` | Field hints, captions, audit timestamps |
| `textSubtle` | `#94A3B8` | `Color(0xFF94A3B8)` | Deemphasized units, inactive icons |
| `textInverse` | `#FFFFFF` | `Color(0xFFFFFFFF)` | Primary button labels, dark card text |

### 1.4 Semantic & Risk Colors
| Status | Background Tint | Border Tint | Text / Icon Hex | Semantic Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Success** | `Color(0xFFECFDF5)` | `Color(0xFFA7F3D0)` | `Color(0xFF047857)` | Fully paid, approved, reconciled |
| **Warning** | `Color(0xFFFFFBEB)` | `Color(0xFFFDE68A)` | `Color(0xFFB45309)` | Pending sign-off, maturing loan, grace period |
| **Danger / Risk** | `Color(0xFFFEF2F2)` | `Color(0xFFFECACA)` | `Color(0xFFB91C1C)` | Defaulter, rejected, out-of-balance vault |
| **Information** | `Color(0xFFEFF6FF)` | `Color(0xFFBFDBFE)` | `Color(0xFF1D4ED8)` | Audit notice, policy info, pending sync |
| **Neutral** | `Color(0xFFF8FAFC)` | `Color(0xFFE2E8F0)` | `Color(0xFF475569)` | Draft, registered, inactive client |

---

## 2. Typography Tokens & Scales

Typography is built on the Inter / System Sans typeface with strict vertical rhythm and tabular numbers for financial columns.

| Scale Token | Size | Weight | Line Height | Letter Spacing | Standard Usage |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `displayHero` | `28.0` | `FontWeight.w800` | `1.20` | `-0.8px` | Executive Hero KPI amounts |
| `headlineLarge` | `20.0` | `FontWeight.w700` | `1.25` | `-0.5px` | Page title, card hero numbers |
| `headlineMedium`| `17.0` | `FontWeight.w600` | `1.30` | `-0.3px` | Section titles, modal headers |
| `titleSmall` | `14.5` | `FontWeight.w600` | `1.35` | `-0.1px` | Table headers, card subheadings |
| `bodyMedium` | `13.5` | `FontWeight.w400` | `1.45` | `0.0px` | Standard body copy, descriptions |
| `bodyDense` | `12.5` | `FontWeight.w400` | `1.40` | `0.0px` | High-density tables, form field labels |
| `caption` | `11.0` | `FontWeight.w500` | `1.35` | `+0.2px` | Trend pills, micro-legends, badges |
| `captionMicro` | `9.5` | `FontWeight.w600` | `1.20` | `+0.4px` | Uppercase section category overlines |

### 2.1 Tabular Figures Specification
All financial amounts, quantities, countdown timers, and balance columns **MUST** enable tabular figures to align decimal points and digits vertically across rows:
```dart
static const TextStyle tabularFinancialText = TextStyle(
  fontFamily: 'Inter',
  fontFeatures: [FontFeature.tabularFigures()],
  letterSpacing: -0.2,
);
```

---

## 3. Spatial Rhythm & Layout Tokens

Spacing follows a strict 4dp / 8dp grid system.

| Spacing Token | Pixels | Application |
| :--- | :--- | :--- |
| `space2` | `2.0` | Micro divider offsets, icon badge insets |
| `space4` | `4.0` | Tag inner padding, tight horizontal item gaps |
| `space8` | `8.0` | Form field inner spacing, chip spacing, icon-to-label gaps |
| `space12` | `12.0` | Compact card internal padding, list item vertical gaps |
| `space16` | `16.0` | Standard card internal padding, standard mobile screen gutters |
| `space20` | `20.0` | Executive KPI card padding, tablet screen gutters |
| `space24` | `24.0` | Major section vertical gaps, desktop screen gutters |
| `space32` | `32.0` | Page header vertical margins, hero banner padding |

### 3.1 Border Radius Tokens
| Radius Token | Pixels | Application |
| :--- | :--- | :--- |
| `radiusXs` | `4.0` | Micro tags, inline status indicators |
| `radiusSm` | `6.0` | Form input fields, buttons, dropdown triggers |
| `radiusMd` | `8.0` | Standard cards, data table containers, search bars |
| `radiusLg` | `12.0` | Executive KPI cards, floating sheets, hover cards |
| `radiusXl` | `16.0` | Modal dialogs, bottom sheets |
| `radiusFull`| `999.0`| Status pill badges, round icon action buttons |

### 3.2 Hairline Borders & Shadows
ICARE replaces harsh drop shadows with crisp, institutional hairline borders:
- **Hairline Border (Standard)**: `Border.all(color: Color(0xFFE2E8F0), width: 1.0)`
- **Hairline Border (Active/Selected)**: `Border.all(color: Color(0xFF0F766E), width: 1.5)`
- **Hairline Border (Warning/Risk)**: `Border.all(color: Color(0xFFFDE68A), width: 1.0)`
- **Card Subtle Shadow (Elevation 1)**:
  ```dart
  BoxShadow(
    color: Color(0x080F172A),
    blurRadius: 4,
    offset: Offset(0, 1),
  )
  ```
- **Modal / Hover Shadow (Elevation 2)**:
  ```dart
  BoxShadow(
    color: Color(0x0F0F172A),
    blurRadius: 12,
    offset: Offset(0, 4),
  )
  ```

---

## 4. Motion & Animation Tokens

Motion must feel immediate, crisp, and purposeful—never decorative or sluggish.

| Motion Token | Duration | Cubic Curve | Usage |
| :--- | :--- | :--- | :--- |
| `motionImmediate`| `80ms` | `Curves.linear` | Immediate touch-down micro-scale (`0.98`) |
| `motionFast` | `150ms` | `Curves.easeOutCubic` | Button hover, icon rotation, status fade |
| `motionNormal` | `250ms` | `Curves.easeInOutCubic` | Card expansion, modal pop, submit morphing |
| `motionSlow` | `400ms` | `Curves.easeOutQuint` | Page entrance stagger, drawer slide |
| `shimmerPeriod` | `1400ms` | `Curves.easeInOut` | Skeleton loading continuous wave cycle |

### 4.1 Tactile Haptic Tokens (Mobile)
- **Light Feedback (`HapticFeedback.lightImpact()`)**: Tab changes, chip selections, segmented controller toggles.
- **Selection Click (`HapticFeedback.selectionClick()`)**: Incrementing counts, dropdown item picks.
- **Medium Feedback (`HapticFeedback.mediumImpact()`)**: Primary form submit button presses.
- **Heavy / Warning Feedback (`HapticFeedback.heavyImpact()`)**: Deleting a record, irreversible manager sign-off.
