import streamlit as st
from services.auth_service import AuthService
from config.settings import APP_VERSION

def get_base64_image(image_path):
    import os, base64
    if not os.path.exists(image_path):
        return ""
    with open(image_path, "rb") as img_file:
        return base64.b64encode(img_file.read()).decode()

LOGO_B64 = get_base64_image("assets/icare_logo.jpg")

def render_login_page():
    # Inject gradient background + particles over Streamlit's default
    st.markdown("""
        <div class="login-page-bg"></div>
        <div class="login-particles">
            <span></span><span></span><span></span>
            <span></span><span></span><span></span>
        </div>
    """, unsafe_allow_html=True)
    st.markdown("""<style>
        .stApp { background: transparent !important; }
        [data-testid="stSidebar"] { display: none !important; }
        header[data-testid="stHeader"] { display: none !important; }
        .stMainBlockContainer { max-width: 1100px !important; margin: 0 auto !important; padding-top: 2vh !important; }
    </style>""", unsafe_allow_html=True)
    
    # Split layout: info panel (left) + login form (right)
    info_col, spacer_col, form_col = st.columns([1.15, 0.1, 0.85])
    
    with info_col:
        st.markdown("""
            <div class='login-info-panel'>
                <div class='info-badge'>🌱 Est. 2006 — South-West Nigeria</div>
                <p class='info-headline'>Empowering Communities,<br><span>Growing Together</span></p>
                <p class='info-slogan'>"Building a better community through inspiration, motivation and empowerment"</p>
                <p class='info-desc'>
                    ICARE (Initiative for Community Advancement, Relief and Empowerment), 
                    founded by Mrs. Alayo L.S., is a Non-Governmental Organization dedicated to the 
                    intellectual and socio-economic growth of its members. Operating across South-Western 
                    Nigeria, ICARE runs micro-credit programmes for traders and artisans, asset acquisition 
                    schemes, agric-enterprise ventures, and skill acquisition programmes for the youths.
                </p>
                <div class='info-divider'></div>
                <div class='info-block'>
                    <p class='info-block-label'>Our Vision</p>
                    <p class='info-block-text'>To be among the foremost catalysts in initiating and implementing 
                    sustainable programmes focused on empowering people for growth and self-reliance.</p>
                </div>
                <div class='info-block'>
                    <p class='info-block-label'>Core Values</p>
                    <div class='info-values'>
                        <span>Integrity</span>
                        <span>Commitment</span>
                        <span>Competence</span>
                        <span>Teamwork</span>
                    </div>
                </div>
                <p class='info-address'>
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5S10.62 6.5 12 6.5s2.5 1.12 2.5 2.5S13.38 11.5 12 11.5z"/></svg>
                    H.Q: 7 Ibifiele Street, Aiyegbami, Sagamu, Ogun State, Nigeria
                </p>
            </div>
        """, unsafe_allow_html=True)
    
    with form_col:
        with st.form("login"):
            st.markdown(f"""
                <div class='login-logo-wrap'>
                    <img src="data:image/jpeg;base64,{LOGO_B64}">
                </div>
                <p class='login-brand-name'>ICARE</p>
                <p class='login-org-name'>Initiative for Community Advancement,<br>Relief and Empowerment</p>
                <div class='login-accent-line'></div>
                <p class='login-title'>Welcome Back</p>
                <p class='login-subtitle'>ICARE — Growing Together</p>
            """, unsafe_allow_html=True)
            
            username = st.text_input("Username", placeholder="Enter your username")
            pw = st.text_input("Password", type="password", placeholder="Enter your password")
            
            submitted = st.form_submit_button("SIGN IN", use_container_width=True)
            
            if submitted:
                if AuthService.login(username, pw):
                    st.query_params['auth'] = username
                    st.rerun()
                else:
                    st.error("Invalid credentials. Please try again.")
        
        st.markdown(f"""
            <div class='login-footer-bar'>
                <p>Core Banking System v{APP_VERSION}</p>
                <span class='secured-badge'>
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-1 16l-4-4 1.41-1.41L11 14.17l6.59-6.59L19 9l-8 8z"/></svg>
                    256-bit Secured Connection
                </span>
            </div>
        """, unsafe_allow_html=True)
