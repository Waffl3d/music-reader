# --- Audiveris install (Ubuntu .deb) ---
ARG AUDIVERIS_VER=5.6.2
ARG AUDIVERIS_DEB=Audiveris-${AUDIVERIS_VER}-ubuntu22.04-x86_64.deb
ARG AUDIVERIS_URL=https://github.com/Audiveris/audiveris/releases/download/${AUDIVERIS_VER}/${AUDIVERIS_DEB}

# Download must be a real .deb (≈60–70 MB). Fail if not.
RUN set -eux; \
  curl -fSL -H "Accept: application/octet-stream" "$AUDIVERIS_URL" -o /tmp/audiveris.deb; \
  # sanity check: show metadata; will fail if file is not a deb
  dpkg-deb -I /tmp/audiveris.deb >/dev/null; \
  apt-get update; \
  apt-get install -y --no-install-recommends /tmp/audiveris.deb; \
  rm -f /tmp/audiveris.deb; \
  rm -rf /var/lib/apt/lists/*
ENV AUDIVERIS_BIN=/usr/bin/audiveris
