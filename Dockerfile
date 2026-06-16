FROM ubuntu:22.04

# Configuration variables
ENV PORT=7681
ENV DEBIAN_FRONTEND=noninteractive
ENV CODE_SERVER_PORT=8089
ENV NOVNC_PORT=8085
ENV DISPLAY=:1

# Install core dependencies and desktop environment components
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    curl \
    git \
    python3 \
    python3-pip \
    tini \
    xvfb \
    x11vnc \
    xfce4 \
    xfce4-goodies \
    && rm -rf /var/lib/apt/lists/*

# Install ttyd (with architecture detection for x86_64 or arm64 nodes)
RUN set -eux; \
    arch="$(uname -m)"; \
    case "$arch" in \
      x86_64|amd64) ttyd_asset="ttyd.x86_64" ;; \
      aarch64|arm64) ttyd_asset="ttyd.aarch64" ;; \
      *) echo "Unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    wget -qO /usr/local/bin/ttyd "https://github.com/tsl0922/ttyd/releases/latest/download/${ttyd_asset}" \
    && chmod +x /usr/local/bin/ttyd

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install noVNC and websockify proxy
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/novnc \
    && git clone --depth 1 https://github.com/novnc/websockify /opt/novnc/utils/websockify \
    && ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# Create entrypoint script to manage background initialization and foreground execution loop
RUN echo '#!/bin/bash\n\
\n\
# Start Xvfb virtual framebuffer\n\
Xvfb $DISPLAY -screen 0 1280x1024x24 &\n\
\n\
# Start XFCE4 Desktop\n\
startxfce4 &\n\
\n\
# Start x11vnc server\n\
x11vnc -forever -shared -rfbport 5901 -display $DISPLAY -nopw &\n\
\n\
# Start noVNC proxy\n\
/opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen $NOVNC_PORT &\n\
\n\
# Start code-server\n\
# If an external PASSWORD variable exists, it uses it. Otherwise, it runs without auth.\n\
if [ -n "$PASSWORD" ]; then\n\
    code-server --bind-addr 0.0.0.0:$CODE_SERVER_PORT --auth password &\n\
else\n\
    code-server --bind-addr 0.0.0.0:$CODE_SERVER_PORT --auth none &\n\
fi\n\
\n\
# Execute ttyd as primary foreground process to maintain container lifecycle\n\
if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then\n\
    exec /usr/local/bin/ttyd --writable -i 0.0.0.0 -p "$PORT" -c "$USERNAME:$PASSWORD" /bin/bash\n\
else\n\
    exec /usr/local/bin/ttyd --writable -i 0.0.0.0 -p "$PORT" /bin/bash\n\
fi' > /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

EXPOSE ${PORT} ${CODE_SERVER_PORT} ${NOVNC_PORT}

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]
