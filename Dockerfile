FROM ubuntu:latest

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies, build tools, and ttyd
RUN apt-get update && apt-get install -y \
    ttyd \
    bash \
    curl \
    wget \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /root

# Expose the default port mapping placeholder
EXPOSE 7681

# Start ttyd and bind it dynamically to Railway's assigned $PORT variable
CMD ["sh", "-c", "ttyd -p ${PORT:-7681} bash"]
