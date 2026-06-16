FROM ubuntu:22.04

# Railway overrides PORT; default to 8080
ENV PORT=8080
ENV DEBIAN_FRONTEND=noninteractive

# Install core dependencies, configure debconf for headless XFCE4, and install desktop components
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget curl git gnupg software-properties-common && \
    echo "lightdm shared/default-x-display-manager select none" | debconf-set-selections && \
    apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    tini \
    fastfetch \
    xvfb \
    x11vnc \
    xfce4 \
    xfce4-terminal \
    desktop-file-utils \
    && rm -rf /var/lib/apt/lists/*

# Install code-server via official installer script
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install noVNC and websockify
RUN mkdir -p /opt/novnc \
    && curl -fsSL https://github.com/novnc/noVNC/archive/refs/tags/v1.5.0.tar.gz | tar -xzf - --strip-components=1 -C /opt/novnc \
    && mkdir -p /opt/novnc/utils/websockify \
    && curl -fsSL https://github.com/novnc/websockify/archive/refs/tags/v0.12.0.tar.gz | tar -xzf - --strip-components=1 -C /opt/novnc/utils/websockify

# Configure entry point assets directory
RUN mkdir -p /usr/local/bin

# Install latest ttyd
RUN set -eux; \
    arch="$(uname -m)"; \
    case "$arch" in \
      x86_64|amd64) ttyd_asset="ttyd.x86_64" ;; \
      aarch64|arm64) ttyd_asset="ttyd.aarch64" ;; \
      *) echo "Unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    wget -qO /usr/local/bin/ttyd "https://github.com/tsl0922/ttyd/releases/latest/download/${ttyd_asset}" \
    && chmod +x /usr/local/bin/ttyd

# Create an execution script to launch services
RUN echo '#!/bin/bash\n\
fastfetch || true\n\
\n\
# Start Xvfb virtual framebuffer\n\
Xvfb :1 -screen 0 1280x820x24 &\n\
export DISPLAY=:1\n\
\n\
# Start XFCE4 desktop session\n\
xfce4-session &\n\
\n\
# Start x11vnc server\n\
x11vnc -display :1 -nopw -forever -shared -bg -listen 127.0.0.1 -rfbport 5900 &\n\
\n\
# Start noVNC proxy to expose the XFCE4 session over web sockets on port 8585\n\
/opt/novnc/utils/websockify/run.py --web /opt/novnc 8585 127.0.0.1:5900 &\n\
\n\
# Start code-server on port 8081\n\
code-server --bind-addr 0.0.0.0:8081 --auth none &\n\
\n\
# Start ttyd terminal sharing on the assigned application port (dynamically set by Railway to 8080)\n\
exec /usr/local/bin/ttyd --writable -i 0.0.0.0 -p "${PORT}" -c "${USERNAME}:${PASSWORD}" /bin/bash\n\
' > /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/entrypoint.sh

RUN echo "fastfetch || true" >> /root/.bashrc

# Expose ports for web terminal (PORT), altered noVNC (8585), and code-server (8081)
EXPOSE 8080 8585 8081

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/usr/local/bin/entrypoint.sh"]
