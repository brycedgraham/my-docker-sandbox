# syntax=docker/dockerfile:1
# ==============================================================================
# Reusable Docker Sandbox Image for OMP Coding Agent Harness (omp.sh)
# Includes .NET 10 SDK, ripgrep (rg), fd-find (fd), Node.js, and OMP CLI
# ==============================================================================

FROM ubuntu:24.04

LABEL maintainer="OMP Docker Sandbox"
LABEL description="Hardened sandbox environment for OMP coding agent with .NET 10, ripgrep, and fd-find"

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Configure .NET environment variables
ENV DOTNET_ROOT=/usr/share/dotnet
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
ENV DOTNET_NOLOGO=1
ENV PATH="/usr/share/dotnet:/usr/local/bin:/home/developer/.local/bin:${PATH}"

# Install core development tools, ripgrep, fd-find, and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    gnupg \
    git \
    ripgrep \
    fd-find \
    jq \
    tar \
    unzip \
    build-essential \
    procps \
    sudo \
    zlib1g \
    libicu-dev \
    locales \
    openssh-client \
    less \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Symlink fdfind to fd for standard CLI compatibility
RUN if [ -f /usr/bin/fdfind ] && [ ! -f /usr/local/bin/fd ]; then \
      ln -s /usr/bin/fdfind /usr/local/bin/fd; \
    fi

# Install Node.js (v22 LTS) for OMP LSP servers, TypeScript engines, and agent sub-processes
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install .NET 10 SDK via Microsoft's official dotnet-install.sh installer
RUN mkdir -p /usr/share/dotnet && \
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh && \
    chmod +x /tmp/dotnet-install.sh && \
    (/tmp/dotnet-install.sh --channel 10.0 --install-dir /usr/share/dotnet || \
     /tmp/dotnet-install.sh --channel STS --install-dir /usr/share/dotnet || \
     /tmp/dotnet-install.sh --channel LTS --install-dir /usr/share/dotnet) && \
    ln -s /usr/share/dotnet/dotnet /usr/local/bin/dotnet && \
    rm -f /tmp/dotnet-install.sh

# Install OMP (Oh-My-Pi) coding agent harness system-wide
# Uses the official installer script, with global npm fallback if needed
RUN (curl -fsSL https://omp.sh/install | bash || true) && \
    if [ ! -f /usr/local/bin/omp ] && [ -f /root/.local/bin/omp ]; then \
      cp /root/.local/bin/omp /usr/local/bin/omp; \
    fi && \
    if [ ! -f /usr/local/bin/omp ]; then \
      npm install -g @oh-my-pi/pi-coding-agent && \
      if [ -f /usr/bin/omp ]; then ln -s /usr/bin/omp /usr/local/bin/omp; fi; \
    fi && \
    chmod +x /usr/local/bin/omp 2>/dev/null || true

# Create non-root developer user with UID 1000 and passwordless sudo
RUN useradd -m -s /bin/bash -u 1000 -G sudo developer && \
    echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create workspace directory and user configuration directory
RUN mkdir -p /workspace /home/developer/.omp/agent /home/developer/.local/bin && \
    chown -R developer:developer /workspace /home/developer

# Configure custom bashrc with helper alias and welcome message
RUN echo 'export PATH="/usr/share/dotnet:/usr/local/bin:~/.local/bin:$PATH"' >> /home/developer/.bashrc && \
    echo 'if [ -f /workspace/AGENTS.md ]; then : ; elif [ -f ~/.omp/agent/AGENTS.md ]; then export OMP_AGENTS_FILE=~/.omp/agent/AGENTS.md; fi' >> /home/developer/.bashrc

# Set working directory to workspace
WORKDIR /workspace

# Default to developer user
USER developer

# Set bash as the entrypoint
CMD ["/bin/bash"]
