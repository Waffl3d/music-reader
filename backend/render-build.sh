#!/usr/bin/env bash
set -e

# 1) System deps (Render base images are Debian/Ubuntu-like)
apt-get update
apt-get install -y --no-install-recommends \
  curl unzip ca-certificates openjdk-17-jre \
  tesseract-ocr ghostscript imagemagick

# 2) Audiveris
if [ ! -d "/opt/audiveris" ]; then
  curl -L https://github.com/Audiveris/audiveris/releases/latest/download/audiveris.zip -o /tmp/audiveris.zip
  mkdir -p /opt
  unzip -q /tmp/audiveris.zip -d /opt
fi

# 3) Python deps
pip install --upgrade pip
pip install -r backend/requirements.txt
