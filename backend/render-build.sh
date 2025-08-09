#!/usr/bin/env bash
set -euo pipefail

# Make apt non-interactive to avoid tzdata/imagemagick prompts
export DEBIAN_FRONTEND=noninteractive

echo "==> apt-get update"
# Retry once if mirrors hiccup
apt-get update || (sleep 3 && apt-get update)

echo "==> apt-get install base packages"
apt-get install -y --no-install-recommends \
  ca-certificates curl unzip \
  openjdk-17-jre tesseract-ocr ghostscript imagemagick \
  python3-pip

echo "==> Verify java"
java -version

echo "==> Install Audiveris under /opt"
if [ ! -d "/opt/audiveris" ]; then
  # -fS so curl fails on HTTP errors; retry to avoid transient GitHub CDN failures
  for i in 1 2 3; do
    curl -fSL https://github.com/Audiveris/audiveris/releases/latest/download/audiveris.zip -o /tmp/audiveris.zip && break
    echo "curl failed (try $i), retrying in 5s..."; sleep 5
  done
  mkdir -p /opt
  unzip -q /tmp/audiveris.zip -d /opt
fi

echo "==> pip install"
python3 -m pip install --upgrade pip
python3 -m pip install -r backend/requirements.txt

echo "==> Build step finished"
