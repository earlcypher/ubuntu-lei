FROM ubuntu:latest

# Configuration variables
ENV TTYD_PORT=7681
ENV DEBIAN_FRONTEND=noninteractive
ENV CODE_SERVER_PORT=3000

# Install core dependencies and CLI utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    sudo \
    wget \
    curl \
    git \
    python3 \
    python3-pip \
    python3-setuptools \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Install ttyd (with architecture detection for x86_64 or arm64 nodes)
RUN set -eux; \
    arch="$(uname -m)"; \
    case "$arch" in \
      x86_64) ttyd_asset="ttyd.x86_64" ;; \
      aarch64) ttyd_asset="ttyd.aarch64" ;; \
      *) echo "Unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    wget -qO /usr/local/bin/ttyd "https://github.com/tsl0922/ttyd/releases/latest/download/${ttyd_asset}" \
    && chmod +x /usr/local/bin/ttyd

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Create entrypoint script using a clean here-document pattern
RUN cat << 'EOF' > /usr/local/bin/entrypoint.sh
#!/bin/bash

# Start code-server
if [ -n "$PASSWORD" ]; then
    PORT=$CODE_SERVER_PORT code-server --auth password --bind-addr 0.0.0.0:$CODE_SERVER_PORT &
else
    PORT=$CODE_SERVER_PORT code-server --auth none --bind-addr 0.0.0.0:$CODE_SERVER_PORT &
fi

# Execute ttyd as primary foreground process to maintain container lifecycle
if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
    exec /usr/local/bin/ttyd --writable -i 0.0.0.0 -p "$TTYD_PORT" -c "$USERNAME:$PASSWORD" /bin/bash
else
    exec /usr/local/bin/ttyd --writable -i 0.0.0.0 -p "$TTYD_PORT" /bin/bash
fi
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE ${TTYD_PORT} ${CODE_SERVER_PORT}

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]
