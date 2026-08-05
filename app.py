import streamlit as st
import traceback
import sys
import os

try:
    import real_app
except Exception as e:
    st.error("FATAL ERROR ON BOOT:")
    st.code(traceback.format_exc())
