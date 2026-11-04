#!/usr/bin/env bash
# OMP Sandbox interactive welcome & status banner
if [ -t 1 ]; then
  DOTNET_VER=$(dotnet --version 2>/dev/null || echo "not found")
  RG_VER=$(rg --version 2>/dev/null | head -n 1 | awk '{print $1, $2}' || echo "installed")
  FD_VER=$(fd --version 2>/dev/null | head -n 1 | awk '{print $1, $2}' || echo "installed")
  OMP_PATH=$(command -v omp || echo "/usr/local/bin/omp")
  ENDPOINT="${UNSLOTH_ENDPOINT:-http://host.docker.internal:8000/v1}"

  echo -e "\033[1;36m"
  echo "  ╔════════════════════════════════════════════════════════════╗"
  echo "  ║       OMP CODING AGENT DOCKER SANDBOX (Active)             ║"
  echo "  ╚════════════════════════════════════════════════════════════╝"
  echo -e "\033[0m"
  echo -e "  Working Directory:  \033[0;32m$(pwd)\033[0m"
  echo -e "  .NET SDK Version:   \033[0;32m${DOTNET_VER}\033[0m"
  echo -e "  Ripgrep:            \033[0;32m${RG_VER}\033[0m"
  echo -e "  fd-find:            \033[0;32m${FD_VER}\033[0m"
  echo -e "  OMP Binary:         \033[0;32m${OMP_PATH}\033[0m"
  echo -e "  Agent Config:       \033[0;34m~/.omp/agent/{models.yml, AGENTS.md}\033[0m"
  echo -e "  Local Model Server: \033[0;34m${ENDPOINT}\033[0m"
  echo ""
  echo -e "  \033[1;33mQuick Start:\033[0m"
  echo -e "    1. Run \033[1;32momp\033[0m to initiate the autonomous coding agent."
  echo -e "    2. Use \033[1mrg <query>\033[0m or \033[1mfd <query>\033[0m for fast file searches."
  echo -e "    3. Build & test with \033[1mdotnet build\033[0m or \033[1mdotnet test\033[0m."
  echo ""
fi
