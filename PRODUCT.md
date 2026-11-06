# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

- **Central Institutional Executives (Head Office)**: System Administrator, Director, Internal Auditor, Accountant, HR, Asset Procurement Officer. They oversee cross-branch portfolio performance, multi-branch liquidity, user provisioning, regulatory reporting, and institutional governance from desktop workstations.
- **Regional & Area Supervisors**: Area Managers (AM) supervising multiple physical lending branches, managing branch onboarding, reviewing and approving daily End-of-Day (EOD) closures, and auditing regional vault liquidity.
- **Branch Operating Managers**: Branch Managers (BM) stationed at physical branch offices, reviewing and approving loan originations, supervising field officers, verifying daily cashbooks, and managing physical vault custody.
- **Field Credit Officers (CO)**: Field officers working in communities and markets on mobile/handheld devices, conducting solidarity group meetings, recording loan repayments and savings collections, and registering new borrowers.
- **Borrowers & Savings Clients**: Market traders, micro-business owners, artisans, and community solidarity groups enrolled in microcredit cycles and asset financing schemes.

## Product Purpose

ICARE is a mission-critical, double-entry core microfinance and asset financing operating system. It exists to provide institutional stability, mathematical financial truth, and streamlined credit deployment to underserved market traders and community micro-enterprises. Success is defined by uncompromised ledger reconciliation, zero unaccounted cash drift, seamless field collection capture, and transparent institutional portfolio health across all physical branches.

## Positioning

A dual-engine microbanking system that integrates traditional group working-capital microloans with physical Asset Credit Financing (appliances, machinery, goods on installment credit) backed by strict double-entry ledger truth (Account 1000 physical vault cash source of truth) and a strict Monday–Friday operational working week.

## Operating Context

- **Physical Cash Movements & Meeting Days**: Credit Officers physically collect cash repayments and savings deposits during designated weekday group meetings. Cash is reconciled against digital schedules and deposited into bank accounts.
- **Operational Working Week (`BR-DATE-001`, `BR-DATE-004`)**: Operations run strictly Monday through Friday. Saturdays, Sundays, and Nigerian national public holidays are non-operational freezes where cash transactions, repayment schedules, and EOD reconciliations are prohibited.
- **Institutional Head Office Domain Separation**: Head Office is the central administrative and governance headquarters (Admin, Director, Auditor, Accountant, HR), never an operational retail lending branch. Operational lending takes place strictly across physical branches (e.g. Ogijo, Ikorodu, Kola, Ibadan, Omitoro).
- **Physical Vault Cash & Ledger Source of Truth (`Account 1000`)**: Physical vault cash positions derive 100% from `financial_ledger_entries` (Account 1000), never from operational projections. All transactions post atomically via database transactions.

## Capabilities and Constraints

- **Dual Loan Engine**:
  - *Cash Loans (Product Finance)*: Working capital disbursements with daily, weekly, or monthly repayment cycles.
  - *Asset Loans (Asset Program / Asset Credit Sales)*: Physical equipment or assets financed on credit with upfront fees (Markup, Passbook, Contingency) and installment collections.
- **Savings Ecosystem**: Individual savings, communal Group savings, Internal savings, and Locked Assets / Suspense accounts (LAPS).
- **Reconciliation & Clearinghouse**: Daily CO Cashbooks, Master Cashbook projections, Area Manager EOD confirmations, Overdue Debt Recovery recording (`loan_overdue_recovery_records`), and Early Payoff / Excess settlement tracking (`loan_payoff_excess_records`).
- **Strict Zero-Emoji Governance (Rule 10)**: Emojis are strictly forbidden anywhere across the system UI (tab headers, buttons, cards, dialogs, form controls, alert banners). Clean vector SVG/Material icons and typography are mandatory.
- **Frontend Identity & Terminology Abstraction (Rule 12)**: Technical database column names, internal rule identifiers (`BR-*`, `FP-*`), and Chart of Accounts codes (`Account 1000`) must never appear in user-facing UI copy. All copy must use clear corporate banking terminology (e.g. *Primary Vault Reserve*, *Active Credit Book*, *Institutional Overview*).
- **Flutter-First Primary Architecture**: Flutter (`frontend_flutter/`) is the sole authoritative production client. Responsive hybrid architecture: high-density multi-pane cockpits on desktop/tablet for Admin/AM/BM, and streamlined touch-first responsive views for field Credit Officers.

## Brand Commitments

- **Name**: ICARE (Core Banking Platform).
- **Visual Stance**: Institutional, authoritative, trustworthy, and restrained.
- **Color Identity**: Deep Forest Emerald (`#022C22` / `#064E3B`), Crisp Pure White (`#FFFFFF`) card surfaces, Neutral Slate Canvas (`#F8FAFC`), Clean Slate Hairline Dividers (`#E2E8F0`), and restrained status accents.
- **Typography & Tone**: Clean corporate banking typography, high readability, sober financial voice, and data density without visual clutter.

## Evidence on Hand

- **Production Codebase**: Full Flutter web/mobile application (`frontend_flutter/`) and FastAPI backend (`api/`, `services/`, `database/`).
- **Live Environments**: Production backend running on Render (`https://icare-app.onrender.com`), production frontend on Vercel (`https://icare-app-liart.vercel.app`), and Supabase PostgreSQL cluster (`zkphpwixqpebsctfklpd`).
- **Authoritative Invariants**: Formal codified governance rules in `.agents/rules/` (`ACCOUNTING_RULES.md`, `CASHBOOK_RULES.md`, `CLIENT_STATUS_RULES.md`, `DASHBOARD_AND_REPORTING_RULES.md`, `BUSINESS_DATE_RULES.md`).

## Product Principles

1. **Ledger Immutability & Mathematical Truth**: Every financial figure shown to users must reconcile to the underlying double-entry ledger. Never fake, guess, or extrapolate financial metrics.
2. **Context-Adaptive Hierarchy**: Adapt visual density and layout by role context—executives get institutional cross-branch macro-intelligence; branch managers get local branch operational command; field officers get rapid, distraction-free meeting workflows.
3. **Fail-Closed Operational Discipline**: If a branch assignment, meeting date, or ledger state is unresolvable or falls on a weekend freeze, fail closed with explicit guidance rather than silent fallbacks or corrupt projections.
4. **Professional Restraint Over Spectacle**: Prioritize legibility, scanability, and confidence over decorative noise, animations, or novelty. High-contrast typography and precise corporate badges anchor the user experience.
