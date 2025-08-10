# =======================
#  STAGE 1: Build Audiveris CLI
# =======================
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive
# JDK + build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jdk git curl unzip ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Pull Audiveris and build only the CLI (no GUI, no desktop integration)
ARG AUDIVERIS_TAG=5.6.2
WORKDIR /opt
RUN git clone --depth=1 --branch ${AUDIVERIS_TAG} https://github.com/Audiveris/audiveris.git
WORKDIR /opt/audiveris/audiveris-cli
RUN ../gradlew --no-daemon installDist

# =======================
#  STAGE 2: Runtime (slim, headless)
# =======================
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 LANG=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    JAVA_TOOL_OPTIONS="-Djava.awt.headless=true -Xms256m -Xmx1024m"

# Runtime deps: JRE, OCR stack, PDF tools, fonts, curl for healthcheck
# Runtime deps (more robust apt with retries + tzdata noninteractive)
RUN set -eux; \
  export DEBIAN_FRONTEND=noninteractive; \
  apt-get -o Acquire::Retries=5 update; \
  apt-get install -y --no-install-recommends tzdata; \
  apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
    openjdk-17-jre-headless \
    tesseract-ocr \
    ghostscript \
    imagemagick \
    fontconfig fonts-dejavu \
    libxi6 libxtst6 \
    python3 python3-pip \
    curl ca-certificates; \
  rm -rf /var/lib/apt/lists/*


# Allow PDF/PS/EPS if ImageMagick policy blocks them (be permissive; this is a service box)
RUN set -eux; \
  for f in /etc/ImageMagick-6/policy.xml /etc/ImageMagick/policy.xml; do \
    if [ -f "$f" ]; then \
      sed -i 's/<policy domain="coder" rights="none" pattern="PDF" \/>/<policy domain="coder" rights="read|write" pattern="PDF" \/>/g' "$f" || true; \
      sed -i 's/<policy domain="coder" rights="none" pattern="PS" \/>/<policy domain="coder" rights="read|write" pattern="PS" \/>/g' "$f" || true; \
      sed -i 's/<policy domain="coder" rights="none" pattern="EPS" \/>/<policy domain="coder" rights="read|write" pattern="EPS" \/>/g' "$f" || true; \
    fi; \
  done

# Add Audiveris CLI from builder, expose it on PATH
ENV AUDIVERIS_HOME=/opt/audiveris-cli \
    AUDIVERIS_BIN=/opt/audiveris-cli/bin/audiveris
COPY --from=builder /opt/audiveris/audiveris-cli/build/install/audiveris-cli/ ${AUDIVERIS_HOME}/
RUN ln -s "${AUDIVERIS_BIN}" /usr/local/bin/audiveris && chmod +x "${AUDIVERIS_BIN}"

# --- Your Flask app ---
WORKDIR /app
COPY backend /app/backend
# (If you have requirements.txt, prefer that. This keeps it simple.)
RUN python3 -m pip install --no-cache-dir flask flask-cors gunicorn

# Healthcheck for Render
ENV PORT=8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -fsS "http://localhost:${PORT}/health" || exit 1

# Tunable Gunicorn settings (override in Render env if you like)
ENV WEB_CONCURRENCY=2 THREADS=2 TIMEOUT=420

# Run API
CMD ["bash","-lc","exec gunicorn -w ${WEB_CONCURRENCY} --threads ${THREADS} --timeout ${TIMEOUT} -b 0.0.0.0:${PORT} server:app --chdir backend"]
