import streamlit as st
try:
    st.metric("Test", "₦1,000", "5 Clients", delta_color="inverse")
    print("Success")
except Exception as e:
    print(f"Error: {e}")
