# ICARE Financial UX & Ergonomics Playbook

Authoritative design patterns for core banking workflows, mobile field operations, and financial integrity.

---

## 1. The Dual-Mode Text Invariants

### 1.1 Invariant A: Financial Amounts Anti-Wrapping (Atomic Numbers)
Currency values and accounting totals must **never wrap across lines** character-by-character. A line break within a financial number destroys ledger legibility and creates severe risk of misreading.

```text
// ❌ FORBIDDEN WRAPPING (Destroys audit comprehension):
₦
150,
000

// ✅ REQUIRED ATOMIC DISPLAY:
₦150,000
```

**Flutter Rule**:
Always enclose monetary amounts in `Text(..., maxLines: 1, overflow: TextOverflow.ellipsis)` or set `softWrap: false`. Always include `FontFeature.tabularFigures()` so amounts align vertically.

### 1.2 Invariant B: Descriptive Text Auto-Wrapping (Mobile Anti-Clipping)
Sentences, notifications, onboarding banners, status explanations, and instructions inside horizontal `Row` widgets **MUST ALWAYS be wrapped in `Expanded` or `Flexible` with `softWrap: true`**.

```dart
// ❌ DEFECTIVE (Clips horizontally on small screens < 450dp):
Row(
  children: [
    Icon(Icons.info),
    SizedBox(width: 8),
    Text('Long descriptive message that gets cut off at the edge'),
  ],
)

// ✅ REQUIRED ARCHITECTURAL PATTERN:
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Icon(Icons.info),
    SizedBox(width: 8),
    Expanded(
      child: Text(
        'Long descriptive message that wraps gracefully onto multiple lines.',
        softWrap: true,
      ),
    ),
  ],
)
```

---

## 2. Currency Formatting Standards
- **Currency Symbol**: Standard Nigerian Naira (`₦`) prefix.
- **Thousand Separators**: Required for all numbers $\ge 1,000$ (e.g. `₦5,000`, `₦150,000`, `₦2,500,000`).
- **Decimals**: Display whole Naira (`₦150,000`) for standard loan disbursements, repayments, and savings balances unless non-zero kobo amounts exist.
- **Signs & Colors**:
  - Positive Inflow / Collection: Emerald green (`Color(0xFF047857)`), prefix `+₦` when showing net change.
  - Outflow / Disbursement: Slate dark (`Color(0xFF0F172A)`) or subtle danger red (`Color(0xFFB91C1C)`), prefix `-₦`.
  - Zero / Settled Balance: Neutral muted (`Color(0xFF64748B)`), `₦0`.

---

## 3. Sunlight Readability & Field Ergonomics (CO Mobile)
Credit Officers operate outdoors in high-glare environments.
1. **High Contrast Surface Ratios**: Body text on surface backgrounds must maintain $\ge 4.5:1$ contrast ratio. Never use faint gray `#D1D5DB` for text. Use `#0F172A` (primary) and `#475569` (secondary).
2. **Generous Touch Targets**: All interactive buttons, checkboxes, chips, and table row selectors must have minimum touch boundaries of $44 \times 44\text{ dp}$.
3. **Thumb-Zone Navigation**: Primary field action buttons (e.g., "Collect Repayment", "Confirm Vault Handover") must be anchored in the lower thumb zone (bottom $35\%$ of the screen) on mobile viewports.
4. **Tactile Haptic Feedback**: Every primary button press triggers `HapticFeedback.mediumImpact()` to give the officer physical certainty of action in noisy market environments.

---

## 4. Double Confirmation Pattern for Irreversible Financial Actions
For destructive or irreversible core banking actions (e.g., EOD Manager Sign-Off, Loan Write-Off, Error Reversal, Reject Loan):
1. **Summary of Impact**: The confirmation modal must clearly summarize:
   - Client / Account Name
   - Exact Naira Amount
   - Reversing Journal / Ledger Impact
2. **Explicit Two-Step Trigger**:
   - The primary destructive button must require a confirmation modal with distinct action verbs (e.g., "Confirm Vault Sign-Off", "Cancel").
   - The confirmation button must show an inline spinner and block double-taps while the RPC executes.

---

## 5. Progressive Disclosure Tooltips (Zero Verbosity Rule)
Avoid dense explanatory paragraphs and instructional tutorials directly on the dashboard canvas.
1. **Tooltips for Math Formulas**: If a metric has a business rule formula (e.g., Net Growth = Active Credit settled vs Full Payments), place an info icon (`Icons.info_outline`) next to the title with a clean `Tooltip` widget.
2. **Concise Subheaders**: Subtitles must remain under 60 characters and state purely the actionable scope (e.g., "4 branches pending sign-off").
3. **One-Sentence Empty States**: An empty state must consist of exactly 1 clear explanation sentence and 1 action button.
