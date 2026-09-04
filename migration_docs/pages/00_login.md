# PAGE IDENTITY

* **Exact page title**: `ICARE — Core Banking`
* **Sidebar label**: N/A (Unauthenticated Entry Point)
* **Role(s)**: Public / Unauthenticated
* **Navigation location**: Root Route (`not logged_in`)
* **Streamlit source**: `auth/login.py` L1–102, `app.py` L598–950
* **Relevant line ranges**: `auth/login.py` (L1–102), `app.py` (L598–950)

# PAGE PURPOSE

Renders the public authentication portal for ICARE Core Banking, presenting institutional impact history on the left and a glassmorphic login card on the right to authenticate staff against Supabase.

# PAGE LAYOUT

1. **Background**: Multi-stop gradient `#0A1628` $\rightarrow$ `#0F2744` $\rightarrow$ `#163B5C` $\rightarrow$ `#1B4F72` with animated glow orbs and floating particle dots.
2. **Split Columns**: Left Info Panel (Flex 1.15) + Spacer (Flex 0.1) + Right Form Card (Flex 0.85).

# SECTION INVENTORY

1. **Section 1: About ICARE & Institutional Impact (Left)**
   * Position: Left Column
   * Purpose: Displays NGO history, mission, vision, core values, and headquarters address.
   * Visible to: All
2. **Section 2: Staff Sign In Form (Right)**
   * Position: Right Column
   * Purpose: Captures username & password for JWT authentication.
   * Visible to: All

# UI COMPONENT INVENTORY

1. **Badge**: `🌱 Est. 2006 — South-West Nigeria` (Green text `#8CC63F`, dark green pill).
2. **Headline**: `Empowering Communities,\nGrowing Together` (Gradient text `#8CC63F` to `#2E86C1`).
3. **Slogan**: `"Building a better community through inspiration, motivation and empowerment"` (Italic `#8CC63F`).
4. **Description**: Paragraph describing ICARE NGO operations in micro-credit, asset acquisition, and youth skill programmes.
5. **Vision Block**: Label `OUR VISION`, Text describing catalyst mandate for self-reliance.
6. **Core Values Block**: Label `CORE VALUES`, 4 rounded pill badges: `Integrity`, `Commitment`, `Competence`, `Teamwork`.
7. **Address Footer**: Location icon + `H.Q: 7 Ibifiele Street, Aiyegbami, Sagamu, Ogun State, Nigeria`.
8. **Circular Logo**: Centered circular container (72px) with `#0F2744` background and emerald glow border.
9. **Brand Header**: `ICARE` (letter-spacing 6px) + `Initiative for Community Advancement,\nRelief and Empowerment`.
10. **Accent Pill**: 44px by 3px gradient line.
11. **Form Header**: `Welcome Back` + `ICARE — Growing Together`.
12. **Username Field**: Input with label `Username`, white rounded input with placeholder `Enter your username`.
13. **Password Field**: Input with label `Password`, white rounded input with placeholder `Enter your password` and eye toggle.
14. **Submit Button**: Full-width button `SIGN IN` in lime green gradient (`#8CC63F` to `#6BA825`).
15. **Footer**: `Core Banking System v2.4.0` &bull; `🔒 256-bit Secured Connection`.

# LABEL INVENTORY

* Page Title: `ICARE — Core Banking`
* Badge: `🌱 Est. 2006 — South-West Nigeria`
* Headline: `Empowering Communities, Growing Together`
* Slogan: `"Building a better community through inspiration, motivation and empowerment"`
* Vision Label: `OUR VISION`
* Core Values Label: `CORE VALUES`
* Value Pills: `Integrity`, `Commitment`, `Competence`, `Teamwork`
* Form Title: `Welcome Back`
* Form Subtitle: `ICARE — Growing Together`
* Field 1: `Username` (Placeholder: `Enter your username`)
* Field 2: `Password` (Placeholder: `Enter your password`)
* Button: `SIGN IN`
* Error: `Invalid credentials. Please try again.`
* Footer: `Core Banking System v2.4.0`, `256-bit Secured Connection`

# FORM INVENTORY

* **Form Name**: `login`
* **Field Order**:
  1. `Username` (`text_input`, required, placeholder: `Enter your username`)
  2. `Password` (`text_input` type `password`, required, placeholder: `Enter your password`)
  3. Submit: `SIGN IN` (`form_submit_button`)

# TABLE INVENTORY

* None (Authentication screen).

# BUTTON INVENTORY

* **Button**: `SIGN IN`
  * Position: Inside login form
  * Action: Authenticates user credentials via `AuthService.login(username, pw)`
  * Success: Sets `st.session_state['logged_in'] = True`, sets `st.query_params['auth'] = username`, reruns to render role scaffold.
  * Failure: Renders `st.error("Invalid credentials. Please try again.")`.

# FILTER INVENTORY

* None.

# NAVIGATION BEHAVIOUR

* Entry: Direct URL access.
* Exit: Successful login transitions user to the authenticated app shell (`st.sidebar` + default role dashboard).

# RBAC BEHAVIOUR

* Accessible to unauthenticated users. Role resolution occurs post-login.

# DATA CONTRACT

* **Endpoint**: `POST /api/v1/auth/login`
* **Request**: `{ "username": "...", "password": "..." }`
* **Response**: `{ "access_token": "...", "token_type": "bearer", "user": { "id": "...", "username": "...", "full_name": "...", "role": "Credit Officer", "branch_id": "...", "branch_name": "..." } }`

# WORKFLOW

1. User opens application.
2. User views institutional history and inputs credentials.
3. User clicks `SIGN IN`.
4. Backend verifies password hash against `app_users.password_hash`.
5. Role and branch permissions resolved $\rightarrow$ App loads permitted operations.

# STATES

* Initial: Empty username/password inputs.
* Loading: Spinner on `SIGN IN` button.
* Error: Red alert box with `Invalid credentials. Please try again.`
* Success: Session authenticated $\rightarrow$ User redirected to Dashboard.

# VISUAL CHARACTERISTICS

* Background: Deep midnight blue gradient (`#0A1628` to `#1B4F72`).
* Form: Glassmorphic translucent card (`rgba(255, 255, 255, 0.06)`).
* Button: Lime green `#8CC63F` gradient.
* Typography: Plus Jakarta Sans / Source Sans 3.

# KNOWN AMBIGUITIES

* None. 100% matched to `auth/login.py` and `media_1788063164324.png`.

# PARITY VERIFICATION EVIDENCE

* **Visual Parity**: 1:1 match to `media_1788063164324.png` (split layout, Est 2006 badge, headline, slogan, description, vision, core values pills, address, circular logo, ICARE header, subtitle, inputs, lime green button, 256-bit secured connection footer).
* **Functional Parity**: Empty input validation, loading indicator, failed credential error banner (`Invalid credentials. Please try again.`), session dispatch on success.
* **Data Parity**: Direct integration with `POST /api/v1/auth/login`.
* **RBAC Parity**: Unauthenticated entry point.
* **Flutter Implementation**: [`frontend_flutter/lib/features/auth/presentation/login_screen.dart`](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/frontend_flutter/lib/features/auth/presentation/login_screen.dart)
* **Status**: **PARITY VERIFIED**

