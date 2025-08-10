# Use Ubuntu since Audiveris publishes Ubuntu .deb installers
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jre-headless tesseract-ocr ghostscript imagemagick \
    python3 python3-pip curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Download the .deb from the GitHub release page (replace URL with exact asset)
ARG AUDIVERIS_DEB_URL="https://github.com/Audiveris/audiveris/releases/download/5.6.0/Audiveris-5.6.0-ubuntu22.04-x86_64.deb"
RUN curl -L "$AUDIVERIS_DEB_URL" -o /tmp/audiveris.deb && \
    apt-get update && apt-get install -y --no-install-recommends /tmp/audiveris.deb && \
    rm -f /tmp/audiveris.deb && rm -rf /var/lib/apt/lists/*

# The .deb installs the CLI on PATH as 'audiveris' (with bundled JRE)
ENV AUDIVERIS_BIN=/usr/bin/audiveris

WORKDIR /app
COPY backend /app/backend
RUN pip3 install --no-cache-dir flask flask-cors gunicorn

ENV PORT=8000
CMD ["bash", "-lc", "exec gunicorn -w 2 -b 0.0.0.0:${PORT} server:app --chdir backend"]
