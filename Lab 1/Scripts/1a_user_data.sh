#!/bin/bash
dnf update -y
dnf install -y python3-pip
pip3 install flask pymysql boto3 requests

mkdir -p /opt/rdsapp
cat >/opt/rdsapp/app.py <<'PY'
import json
import os
import boto3
import pymysql
import traceback
from datetime import datetime
import random
from flask import Flask, request, make_response, jsonify
from flask import Response
import hashlib

REGION = os.environ.get("AWS_REGION", "us-east-1")
SECRET_ID = os.environ.get("SECRET_ID", "lab1a/rds/mysql")
DB_NAME = "labdb"

secrets = boto3.client("secretsmanager", region_name=REGION)

def get_db_creds():
    resp = secrets.get_secret_value(SecretId=SECRET_ID)
    s = json.loads(resp["SecretString"])
    # When you use "Credentials for RDS database", AWS usually stores:
    # username, password, host, port, dbname (sometimes)
    return s

def get_conn():
    c = get_db_creds()
    host = c["host"]
    user = c["username"]
    password = c["password"]
    port = int(c.get("port", 3306))
    db = DB_NAME  # we'll create this if it doesn't exist
    return pymysql.connect(host=host, user=user, password=password, port=port, database=db, autocommit=True)

app = Flask(__name__)

@app.route("/")
def home():
    return """
    <h2>EC2 → RDS Notes App</h2>
    <p>POST /add?note=hello</p>
    <p>GET /list</p>
    """


# ---- Static Entrypoint ----

@app.route("/static/index.html")
def static_index():
    # A simple HTML entrypoint that we can invalidate as “break glass”.
    # Change DEPLOY_VERSION to simulate a new deployment.
    deploy = os.environ.get("DEPLOY_VERSION", "v1")
    body = f"""<!doctype html>
<html>
  <head>
    <meta charset=\"utf-8\" />
    <title>Satellite Static Entrypoint</title>
  </head>
  <body>
    <h1>Satellite static index</h1>
    <p>deploy_version: {deploy}</p>
  </body>
</html>"""

    resp = Response(body, mimetype="text/html")
    # Make it cacheable at CloudFront so Age / x-cache behavior is visible.
    resp.headers["Cache-Control"] = "public, s-maxage=300, max-age=0"
    # Helpful for proving content changes without dumping the body.
    resp.headers["ETag"] = hashlib.md5(body.encode("utf-8")).hexdigest()
    return resp


# ----- New API Routes -----

@app.route("/api/public-feed")
def public_feed():
    # Changes every request at origin, but CloudFront can hold it for 30s when honoring Cache-Control.
    now = datetime.utcnow().isoformat() + "Z"
    msg = random.choice(["alpha", "bravo", "charlie", "delta"])
    resp = make_response(jsonify({
        "server_time_utc": now,
        "message_of_the_minute": msg
    }))
    resp.headers["Cache-Control"] = "public, s-maxage=30, max-age=0"
    return resp


@app.route("/api/list")
def api_list():
    # Never cache: prevents user mixups and stale reads.
    resp = make_response(jsonify({
        "generated_utc": datetime.utcnow().isoformat() + "Z",
        "items": [1, 2, 3]
    }))
    resp.headers["Cache-Control"] = "private, no-store"
    return resp

@app.route("/init")
def init_db():
    try:
        c = get_db_creds()
        host = c["host"]
        user = c["username"]
        password = c["password"]
        port = int(c.get("port", 3306))

        # connect without specifying a DB first
        conn = pymysql.connect(host=host, user=user, password=password, port=port, autocommit=True)
        cur = conn.cursor()
        cur.execute(f"CREATE DATABASE IF NOT EXISTS {DB_NAME};")
        cur.execute(f"USE {DB_NAME};")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS notes (
                id INT AUTO_INCREMENT PRIMARY KEY,
                note VARCHAR(255) NOT NULL
            );
        """)
        cur.close()
        conn.close()
        return "Initialized labdb + notes table."
    except Exception as e:
        traceback.print_exc()
        return f"init failed: {str(e)}" , 500

@app.route("/add", methods=["POST", "GET"])
def add_note():
    try:
        note = request.args.get("note", "").strip()
        if not note:
            return "Missing note param. Try: /add?note=hello", 400
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("INSERT INTO notes(note) VALUES(%s);", (note,))
        cur.close()
        conn.close()
        return f"Inserted note: {note}"
    except Exception as e:
        traceback.print_exc()
        return f"init failed: {str(e)}" , 500

@app.route("/list")
def list_notes():
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("SELECT id, note FROM notes ORDER BY id DESC;")
        rows = cur.fetchall()
        cur.close()
        conn.close()
        out = "<h3>Notes</h3><ul>"
        for r in rows:
            out += f"<li>{r[0]}: {r[1]}</li>"
        out += "</ul>"
        return out
    except Exception as e:
        traceback.print_exc()
        return f"init failed: {str(e)}" , 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PY

cat >/etc/systemd/system/rdsapp.service <<'SERVICE'
[Unit]
Description=EC2 to RDS Notes App
After=network.target

[Service]
WorkingDirectory=/opt/rdsapp
Environment=SECRET_ID=lab1a/rds/mysql
Environment=DEPLOY_VERSION=v1
ExecStart=/usr/bin/python3 /opt/rdsapp/app.py
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable rdsapp
systemctl start rdsapp