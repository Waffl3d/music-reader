# ---- Base image ----
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# ---- System deps for Audiveris & your Flask API ----
# Use the JDK (not just JRE) because we build Audiveris from source with Gradle.
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jdk \
    tesseract-ocr \
    ghostscript \
    imagemagick \
    python3 python3-pip \
    curl ca-certificates \
    git unzip \
    libxi6 libxtst6 \
    dpkg-dev \
 && rm -rf /var/lib/apt/lists/*

# (Optional) If ImageMagick blocks PDFs by policy, enable them:
# RUN sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/' /etc/ImageMagick-6/policy.xml || true

# ---- Audiveris CLI (build from source; avoids .deb postinst issues) ----
WORKDIR /opt
# Pin a stable tag; adjust if you want a different release
RUN git clone --depth=1 --branch 5.6.2 https://github.com/Audiveris/audiveris.git
WORKDIR /opt/audiveris
# Build only the CLI distribution (no GUI, no desktop integration)
RUN ./gradlew --no-daemon :audiveris-cli:installDist

# Expose CLI path (and add a convenience symlink on PATH)
ENV AUDIVERIS_BIN=/opt/audiveris/audiveris-cli/build/install/audiveris-cli/bin/audiveris
RUN chmod +x "$AUDIVERIS_BIN" && ln -s "$AUDIVERIS_BIN" /usr/local/bin/audiveris

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
