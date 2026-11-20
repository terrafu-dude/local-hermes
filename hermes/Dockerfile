# Seeded Hermes image — config baked in so `docker compose up` needs no manual setup.
# The docker-compose named volume auto-seeds from /opt/data on first boot,
# so a fresh clone runs fully local with zero interactive steps.
FROM nousresearch/hermes-agent:latest

# Run the agent as the host user (UID 1000) so it can read/write the
# bind-mounted ./host-workspace and its own data volume.
ENV PUID=1000 PGID=1000

# The only config this local stack needs: point at local Ollama, no keys.
COPY config.yaml /opt/data/config.yaml
COPY .env /opt/data/.env

# Web-dashboard plugin: a "Services" tab linking ComfyUI / Ollama WebUI / Piper.
COPY plugins/services /opt/data/plugins/services

# ── Fully-local video-production toolchain (for making the tutorial locally) ──
# ffmpeg ships in the base image. Add the ASCII-video render deps (numpy/scipy;
# pillow is already present) and a local neural-free TTS for narration
# (espeak-ng). Everything runs offline on this box.
RUN /opt/hermes/.venv/bin/python -m ensurepip && \
    /opt/hermes/.venv/bin/python -m pip install --no-cache-dir --quiet numpy scipy && \
    # ── Fully-local voice: faster-whisper (STT) + piper (TTS) ────────────────
    # faster-whisper needs PyAV <19 (19 dropped the metadata_errors kwarg it uses
    # to decode audio); pin it or local transcription fails with
    # "open() got an unexpected keyword argument 'metadata_errors'".
    /opt/hermes/.venv/bin/python -m pip install --no-cache-dir --quiet \
        "faster-whisper" "piper-tts" "av<19" && \
    apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends espeak-ng && \
    rm -rf /var/lib/apt/lists/*

# ── Stable local gateway (dashboard + API) ────────────────────────────
# The image's /etc/cont-init.d/02-reconcile-profiles honors gateway_state
# "running" by auto-starting a SECOND s6-supervised `gateway ... --replace`
# that SIGTERMs the foreground gateway every few seconds (issue #42675).
# Removing it lets `command: gateway run` (NO_SUPERVISE) be the ONE gateway,
# so the dashboard/API are served continuously instead of crash-looping.
RUN rm -f /etc/cont-init.d/02-reconcile-profiles
