# ========= fetch Audiveris binaries (no postinst) =========
FROM debian:bookworm-slim AS fetcher
ARG AUDIVERIS_VER=5.6.2
ARG AUDIVERIS_DEB=Audiveris-${AUDIVERIS_VER}-ubuntu22.04-x86_64.deb
ARG AUDIVERIS_URL=https://github.com/Audiveris/audiveris/releases/download/${AUDIVERIS_VER}/${AUDIVERIS_DEB}

RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends curl ca-certificates dpkg-dev; \
  rm -rf /var/lib/apt/lists/*

# Download and extract payload from the .deb (skip postinst)
RUN set -eux; \
  curl -fSL -H "Accept: application/octet-stream" "$AUDIVERIS_URL" -o /tmp/audiveris.deb; \
  mkdir -p /tmp/expand; \
  dpkg-deb -x /tmp/audiveris.deb /tmp/expand; \
  mv /tmp/expand/opt/audiveris /opt/audiveris; \
  rm -rf /tmp/expand /tmp/audiveris.deb

# ========= runtime image =========
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Core runtime deps
RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    openjdk-17-jre-headless \
    tesseract-ocr \
    ghostscript \
    imagemagick \
    fontconfig fonts-dejavu \
    libxi6 libxtst6 \
    python3 python3-pip \
    curl ca-certificates; \
  rm -rf /var/lib/apt/lists/*

# Allow PDFs/PS in ImageMagick (some distros disable by policy)
RUN set -eux; \
  for f in /etc/ImageMagick-6/policy.xml /etc/ImageMagick/policy.xml; do \
    [ -f "$f" ] || continue; \
    sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/' "$f" || true; \
    sed -i 's/rights="none" pattern="PS"/rights="read|write" pattern="PS"/' "$f" || true; \
    sed -i 's/rights="none" pattern="EPS"/rights="read|write" pattern="EPS"/' "$f" || true; \
  done

# Bring in Audiveris files from fetcher and expose a stable CLI path
COPY --from=fetcher /opt/audiveris /opt/audiveris
RUN ln -s /opt/audiveris/bin/audiveris /usr/local/bin/audiveris

ENV AUDIVERIS_BIN=/usr/local/bin/audiveris \
    JAVA_TOOL_OPTIONS="-Djava.awt.headless=true"

# ---- App code ----
WORKDIR /app
COPY backend /app/backend
RUN pip3 install --no-cache-dir flask flask-cors gunicorn

# ---- Run API ----
ENV PORT=8000
CMD ["bash","-lc","exec gunicorn -w 2 -b 0.0.0.0:${PORT} server:app --chdir backend"]
