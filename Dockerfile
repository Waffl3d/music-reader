# debian slim so we can apt-get what Audiveris needs
FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

# System deps: Java 17, tesseract, ghostscript, ImageMagick, Python, pip, curl, unzip
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jre-headless tesseract-ocr ghostscript imagemagick \
    python3 python3-pip curl unzip ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# (Optional) enable PDF in ImageMagick if the default policy blocks it
# RUN sed -i 's/rights=\"none\" pattern=\"PDF\"/rights=\"read|write\" pattern=\"PDF\"/' /etc/ImageMagick-6/policy.xml || true

# Install Audiveris CLI (pick a release that works with Java 17)
ARG AUDIVERIS_URL="https://github.com/Audiveris/audiveris/releases/download/5.4.1/audiveris-5.4.1-linux.zip"
RUN mkdir -p /opt/audiveris && \
    curl -L "$AUDIVERIS_URL" -o /tmp/audiveris.zip && \
    unzip /tmp/audiveris.zip -d /opt && \
    mv /opt/audiveris-* /opt/audiveris && \
    chmod +x /opt/audiveris/bin/audiveris && \
    rm -f /tmp/audiveris.zip
ENV AUDIVERIS_BIN=/opt/audiveris/bin/audiveris

# App code
WORKDIR /app
COPY backend /app/backend

# Python deps (or use requirements.txt if you have one)
RUN pip3 install --no-cache-dir flask flask-cors gunicorn

# Run the API with Gunicorn; Render injects PORT
ENV PORT=8000
CMD ["bash", "-lc", "exec gunicorn -w 2 -b 0.0.0.0:${PORT} server:app --chdir backend"]
