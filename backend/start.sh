#!/usr/bin/env bash
set -e

# Install deps if missing (Debian/Ubuntu hosts like Render/Railway images)
if ! command -v java >/dev/null 2>&1; then
  apt-get update
  apt-get install -y openjdk-17-jre tesseract-ocr ghostscript imagemagick curl unzip
fi

# Install Audiveris once
if [ ! -d "/opt/audiveris" ]; then
  curl -L https://github.com/Audiveris/audiveris/releases/latest/download/audiveris.zip -o /tmp/audiveris.zip
  unzip /tmp/audiveris.zip -d /opt
fi

export AUDIVERIS_BIN="/opt/audiveris/bin/audiveris"
python3 backend/server.py