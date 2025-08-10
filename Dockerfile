# ---- Base image ----
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# ---- System deps for Audiveris & your Flask API ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jre-headless \
    tesseract-ocr \
    ghostscript \
    imagemagick \
    python3 python3-pip \
    curl ca-certificates \
    # useful for validating .deb files
    dpkg-dev \
 && rm -rf /var/lib/apt/lists/*

# (Optional) If ImageMagick blocks PDFs by policy, enable them:
# RUN sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/' /etc/ImageMagick-6/policy.xml || true

# ---- Audiveris installer (.deb) ----
ARG AUDIVERIS_VER=5.6.2
ARG AUDIVERIS_DEB=Audiveris-${AUDIVERIS_VER}-ubuntu22.04-x86_64.deb
ARG AUDIVERIS_URL=https://github.com/Audiveris/audiveris/releases/download/${AUDIVERIS_VER}/${AUDIVERIS_DEB}

# Download must be a real .deb (≈60–70 MB). Fail if not.
RUN set -eux; \
  curl -fSL -H "Accept: application/octet-stream" "$AUDIVERIS_URL" -o /tmp/audiveris.deb; \
  dpkg-deb -I /tmp/audiveris.deb >/dev/null; \
  apt-get update; \
  apt-get install -y --no-install-recommends /tmp/audiveris.deb; \
  rm -f /tmp/audiveris.deb; \
  rm -rf /var/lib/apt/lists/*

# Audiveris CLI path
ENV AUDIVERIS_BIN=/usr/bin/audiveris

# ---- App code ----
WORKDIR /app
# If your Flask code lives in backend/, keep this:
COPY backend /app/backend

# Python deps (use requirements.txt if you have one)
# COPY requirements.txt /app/
# RUN pip3 install --no-cache-dir -r requirements.txt
RUN pip3 install --no-cache-dir flask flask-cors gunicorn

# ---- Run API ----
ENV PORT=8000
CMD ["bash", "-lc", "exec gunicorn -w 2 -b 0.0.0.0:${PORT} server:app --chdir backend"]
