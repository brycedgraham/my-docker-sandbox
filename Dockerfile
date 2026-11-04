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

# Ubuntu 24.04 ships with a default 'ubuntu' user at UID 1000.
# Safely remove it so we can create an unprivileged 'developer' user (UID 1000)
# with NO sudo/root permissions, ensuring the AI agent cannot perform privileged operations.
RUN if id -u ubuntu >/dev/null 2>&1; then \
        userdel -r ubuntu 2>/dev/null || true; \
    fi && \
    if getent group ubuntu >/dev/null 2>&1; then \
        groupdel ubuntu 2>/dev/null || true; \
    fi && \
    useradd -m -s /bin/bash -u 1000 -U developer

# Create workspace directory and user configuration directory
RUN mkdir -p /workspace /home/developer/.omp/agent /home/developer/.local/bin && \
    chown -R developer:developer /workspace /home/developer

# Configure custom bashrc with helper alias and welcome script
RUN echo 'export PATH="/usr/share/dotnet:/usr/local/bin:~/.local/bin:$PATH"' >> /home/developer/.bashrc && \
    echo 'if [ -f /workspace/AGENTS.md ]; then : ; elif [ -f ~/.omp/agent/AGENTS.md ]; then export OMP_AGENTS_FILE=~/.omp/agent/AGENTS.md; fi' >> /home/developer/.bashrc && \
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      'if [ -t 1 ]; then' \
      '  echo -e "\033[1;36m"' \
      '  echo "  ╔════════════════════════════════════════════════════════════╗"' \
      '  echo "  ║       OMP CODING AGENT DOCKER SANDBOX (Active)             ║"' \
      '  ╚════════════════════════════════════════════════════════════╝"' \
      '  echo -e "\033[0m"' \
      '  echo -e "  Working Directory:  \033[0;32m$(pwd)\033[0m"' \
      '  echo -e "  .NET SDK Version:   \033[0;32m$(dotnet --version 2>/dev/null || echo \"not found\")\033[0m"' \
      '  echo -e "  Ripgrep (rg):       \033[0;32m$(rg --version 2>/dev/null | head -n 1 || echo \"installed\")\033[0m"' \
      '  echo -e "  fd-find (fd):       \033[0;32m$(fd --version 2>/dev/null | head -n 1 || echo \"installed\")\033[0m"' \
      '  echo -e "  OMP Binary:         \033[0;32m$(command -v omp || echo \"/usr/local/bin/omp\")\033[0m"' \
      '  echo -e "  Agent Config:       \033[0;34m~/.omp/agent/{models.yml, AGENTS.md}\033[0m"' \
      '  echo -e "  Local Model Server: \033[0;34m${UNSLOTH_ENDPOINT:-http://host.docker.internal:8000/v1}\033[0m"' \
      '  echo ""' \
      '  echo -e "  \033[1;33mQuick Start:\033[0m"' \
      '  echo -e "    1. Run \033[1;32momp\033[0m to initiate the autonomous coding agent."' \
      '  echo -e "    2. Use \033[1mrg <query>\033[0m or \033[1mfd <query>\033[0m for fast file searches."' \
      '  echo -e "    3. Build & test with \033[1mdotnet build\033[0m or \033[1mdotnet test\033[0m."' \
      '  echo ""' \
      'fi' > /usr/local/bin/welcome.sh && \
    chmod +x /usr/local/bin/welcome.sh && \
    echo '/usr/local/bin/welcome.sh' >> /home/developer/.bashrc

# Set working directory to workspace
WORKDIR /workspace

# Default to developer user
USER developer

# Set bash as the entrypoint
CMD ["/bin/bash"]
