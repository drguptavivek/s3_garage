import streamlit as st
import boto3
import requests
import pandas as pd
import os
from dotenv import load_dotenv
from botocore.client import Config

# Load environment variables
load_dotenv()

st.set_page_config(page_title="Garage S3 Dashboard", layout="wide", page_icon="🗄️")

# --- Configuration Sidebar ---
st.sidebar.header("🔌 Connection")

s3_endpoint = st.sidebar.text_input(
    "S3 Endpoint", 
    value=os.getenv("S3_ENDPOINT", "http://s3:3900")
)

admin_endpoint = st.sidebar.text_input(
    "Admin Endpoint", 
    value=os.getenv("ADMIN_ENDPOINT", "http://s3:3903")
)

access_key = st.sidebar.text_input(
    "Access Key ID", 
    value=os.getenv("AWS_ACCESS_KEY_ID", ""), 
    type="password"
)

secret_key = st.sidebar.text_input(
    "Secret Access Key", 
    value=os.getenv("AWS_SECRET_ACCESS_KEY", ""), 
    type="password"
)

admin_token = st.sidebar.text_input(
    "Admin Token (for Metrics)", 
    value=os.getenv("ADMIN_TOKEN", ""), 
    type="password"
)

if not access_key or not secret_key:
    st.warning("⚠️ Please provide AWS Credentials in the sidebar or .env file.")
    st.stop()

# --- Initialize Clients ---
@st.cache_resource
def get_s3_client(endpoint, access_key, secret_key):
    return boto3.client(
        's3',
        endpoint_url=endpoint,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(signature_version='s3v4'),
        region_name='garage'
    )

try:
    s3 = get_s3_client(s3_endpoint, access_key, secret_key)
except Exception as e:
    st.error(f"Failed to connect to S3: {e}")
    st.stop()

# --- Dashboard Content ---
st.title("🗄️ Garage S3 Dashboard")

# 1. Cluster Status (Admin API)
st.header("📊 Cluster Status")

col1, col2, col3 = st.columns(3)

try:
    # Fetch health
    # Note: Inside docker, s3:3903 is reachable.
    health_resp = requests.get(f"{admin_endpoint}/health", timeout=2)
    health_status = "✅ Healthy" if health_resp.status_code == 200 else f"❌ {health_resp.status_code}"
    
    col1.metric("Service Health", health_status)
    
    # Fetch metrics (if token provided)
    if admin_token:
        try:
            metrics_resp = requests.get(
                f"{admin_endpoint}/metrics", 
                headers={"Authorization": f"Bearer {admin_token}"},
                timeout=2
            )
            if metrics_resp.status_code == 200:
                # Simple parsing of prometheus text format
                data = metrics_resp.text
                
                # Find connected nodes
                # cluster_connected_nodes 1
                nodes = [line for line in data.split('\n') if line.startswith('cluster_connected_nodes')]
                if nodes:
                    node_count = nodes[0].split(' ')[1]
                    col2.metric("Nodes Online", node_count)
                else:
                    col2.metric("Nodes", "?")
                
                # Find storage used
                # garage_data_dir_used_space_bytes ...
                usage_lines = [line for line in data.split('\n') if line.startswith('garage_data_dir_used_space_bytes')]
                total_bytes = 0
                for line in usage_lines:
                    try:
                        val = float(line.split(' ')[1])
                        total_bytes += val
                    except:
                        pass
                
                gb = round(total_bytes / (1024**3), 2)
                col3.metric("Storage Used", f"{gb} GB")

        except Exception as e:
            col2.metric("Nodes", "Error")
            st.error(f"Metrics error: {e}")
    else:
        col2.metric("Nodes", "Token Required")

except Exception as e:
    col1.metric("Service Health", "❓ Unreachable")
    st.caption(f"Could not reach {admin_endpoint}")

# 2. Buckets List
st.header("📦 Buckets")

try:
    buckets_resp = s3.list_buckets()
    buckets = buckets_resp.get('Buckets', [])
    
    if not buckets:
        st.info("No buckets found.")
    else:
        bucket_data = []
        for b in buckets:
            name = b['Name']
            creation = b['CreationDate']
            bucket_data.append({"Name": name, "Created": creation})
        
        df = pd.DataFrame(bucket_data)
        st.dataframe(df, use_container_width=True)
        
        # 3. Object Browser
        st.subheader("📂 Object Browser")
        selected_bucket = st.selectbox("Select Bucket", [b['Name'] for b in buckets])
        
        if selected_bucket:
            # List objects
            objects_resp = s3.list_objects_v2(Bucket=selected_bucket)
            objects = objects_resp.get('Contents', [])
            
            if objects:
                obj_data = []
                for o in objects:
                    obj_data.append({
                        "Key": o['Key'],
                        "Size (KB)": round(o['Size'] / 1024, 2),
                        "Last Modified": o['LastModified']
                    })
                
                st.dataframe(pd.DataFrame(obj_data), use_container_width=True)
                st.caption(f"Total Objects: {len(objects)}")
            else:
                st.info("Bucket is empty.")

except Exception as e:
    st.error(f"Error listing buckets: {e}")

# Footer
st.markdown("---")
st.caption("Garage S3 Dashboard | Powered by Streamlit & Python")
