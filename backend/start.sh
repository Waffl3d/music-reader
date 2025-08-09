#!/usr/bin/env bash
set -e

# Install system deps if missing
if ! command -v java >/dev/null 2>&1; then
  apt-get update
  apt-get install -y --no-install-recommends \
    openjdk-17-jre tesseract-ocr ghostscript imagemagick curl unzip python3-pip
fi

# Install Audiveris if missing
if [ ! -d "/opt/audiveris" ]; then
  curl -L https://github.com/Audiveris/audiveris/releases/latest/download/audiveris.zip -o /tmp/audiveris.zip
  mkdir -p /opt
  unzip -q /tmp/audiveris.zip -d /opt
fi

# Install Python deps
pip install --upgrade pip
pip install -r backend/requirements.txt

# Start Flask server
export AUDIVERIS_BIN="/opt/audiveris/bin/audiveris"
export PYTHONUNBUFFERED=1
python3 backend/server.py
