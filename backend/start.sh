#!/usr/bin/env bash
set -e
export AUDIVERIS_BIN="/opt/audiveris/bin/audiveris"
export PYTHONUNBUFFERED=1
python3 backend/server.py