#!/usr/bin/env bash
# ==============================================================================
# OMP Coding Agent Sandbox Setup Script (Linux / macOS)
# Documentation: https://docs.docker.com/ai/sandboxes/ | https://omp.sh/docs
# ==============================================================================
# Creates an isolated Docker sandbox based on the current workspace directory,
# loads agent-config (AGENTS.md & models.yml), enforces network policy,
# and drops the user into an interactive bash shell ready to execute `omp`.
# ==============================================================================

set -euo pipefail

# Text formatting
BOLD=$'\e[1m'
GREEN=$'\e[0;32m'
CYAN=$'\e[0;36m'
YELLOW=$'\e[1;33m'
RED=$'\e[0;31m'
RESET=$'\e[0m'

# Resolve script directory (where Dockerfile, agent-config, and network-policy.txt reside)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# Target workspace is the current working directory where the user invoked the script
WORKSPACE_DIR="$(pwd)"
WORKSPACE_NAME="$(basename "$WORKSPACE_DIR")"
IMAGE_NAME="omp-sandbox:latest"
CONTAINER_NAME="omp-sbx-${WORKSPACE_NAME,,}"
# Replace any non-alphanumeric characters in container name
CONTAINER_NAME="${CONTAINER_NAME//[^a-zA-Z0-9_-]/-}"

CONFIG_DIR="${SCRIPT_DIR}/agent-config"
POLICY_FILE="${SCRIPT_DIR}/network-policy.txt"
DOCKERFILE_PATH="${SCRIPT_DIR}/Dockerfile"

FORCE_REBUILD=false
UNSLOTH_PORT=8000
HOST_IP="host.docker.internal"

print_usage() {
  cat << EOF
${BOLD}Usage:${RESET} $(basename "$0") [OPTIONS]

${BOLD}Description:${RESET}
  Launches an isolated Docker sandbox for the omp.sh coding agent harness.
  Mounts the current working directory into /workspace, loads models.yml
  and AGENTS.md, applies network egress rules, and launches an interactive bash shell.

${BOLD}Options:${RESET}
  -r, --rebuild        Force rebuild of the Docker sandbox image
  -n, --name <NAME>    Specify a custom container/sandbox name
  -p, --port <PORT>    Host port where local Unsloth is listening (default: 8000)
  -h, --help           Show this help message and exit

${BOLD}Current Workspace:${RESET}
  ${WORKSPACE_DIR}

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -r|--rebuild)
      FORCE_REBUILD=true
      shift
      ;;
    -n|--name)
      CONTAINER_NAME="$2"
      shift 2
      ;;
    -p|--port)
      UNSLOTH_PORT="$2"
      shift 2
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown option $1${RESET}"
      print_usage
      exit 1
      ;;
  esac
done

echo -e "${BOLD}${CYAN}================================================================${RESET}"
echo -e "${BOLD}${CYAN}      OMP Coding Agent Sandbox Launcher (Remote CLI)            ${RESET}"
echo -e "${BOLD}${CYAN}================================================================${RESET}"
echo -e "  ${BOLD}Workspace:${RESET}        ${GREEN}${WORKSPACE_DIR}${RESET}"
echo -e "  ${BOLD}Container Name:${RESET}   ${CYAN}${CONTAINER_NAME}${RESET}"
echo -e "  ${BOLD}Agent Config:${RESET}     ${CONFIG_DIR}"
echo -e "  ${BOLD}Network Policy:${RESET}   ${POLICY_FILE}"
echo -e "  ${BOLD}Unsloth Host:${RESET}     http://${HOST_IP}:${UNSLOTH_PORT}/v1"
echo -e "${BOLD}${CYAN}----------------------------------------------------------------${RESET}"

# Verify prerequisite files
if [ ! -d "${CONFIG_DIR}" ]; then
  echo -e "${RED}Error: agent-config directory not found at ${CONFIG_DIR}${RESET}"
  exit 1
fi

if [ ! -f "${CONFIG_DIR}/models.yml" ] || [ ! -f "${CONFIG_DIR}/AGENTS.md" ]; then
  echo -e "${RED}Error: models.yml or AGENTS.md missing in ${CONFIG_DIR}${RESET}"
  exit 1
fi

# Verify Docker availability
if ! command -v docker &>/dev/null; then
  echo -e "${RED}Error: Docker is not installed or not in PATH.${RESET}"
  echo -e "Please install Docker or Docker Desktop from https://docs.docker.com/engine/install/"
  exit 1
fi

# Check Docker daemon connectivity
if ! docker info &>/dev/null; then
  echo -e "${RED}Error: Cannot connect to Docker daemon. Is Docker running?${RESET}"
  exit 1
fi

# Apply network policy if Docker AI Sandboxes CLI (sbx) is installed
HAS_SBX=false
if command -v sbx &>/dev/null; then
  HAS_SBX=true
  echo -e "${GREEN}✓ Docker AI Sandboxes CLI (sbx) detected.${RESET}"
  echo -e "  Configuring network egress policy rules..."
  if [ -f "${POLICY_FILE}" ]; then
    # Initialize balanced policy preset
    sbx policy init balanced 2>/dev/null || true
    # Parse and register specific allowed destinations
    while IFS= read -r line || [ -n "$line" ]; do
      line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      # Skip comments and empty lines or section headers
      [[ "$line" =~ ^# ]] && continue
      [[ -z "$line" ]] && continue
      [[ "$line" =~ ^\[ ]] && continue
      [[ "$line" =~ = ]] && continue

      sbx policy allow network "$line" 2>/dev/null || true
    done < "${POLICY_FILE}"
    echo -e "${GREEN}✓ Sandbox network policy rules successfully registered.${RESET}"
  fi
else
  echo -e "${YELLOW}ℹ 'sbx' CLI not found; running with hardened Docker engine container.${RESET}"
fi

# Build or verify image
IMAGE_EXISTS=$(docker images -q "${IMAGE_NAME}" 2>/dev/null || true)
if [ -z "${IMAGE_EXISTS}" ] || [ "${FORCE_REBUILD}" = true ]; then
  echo -e "${BOLD}Building Docker sandbox image (${IMAGE_NAME})...${RESET}"
  docker build -t "${IMAGE_NAME}" -f "${DOCKERFILE_PATH}" "${SCRIPT_DIR}"
  echo -e "${GREEN}✓ Docker image built successfully.${RESET}"
else
  echo -e "${GREEN}✓ Using existing Docker image: ${IMAGE_NAME}${RESET}"
fi

# Remove any stopped container with identical name
docker rm -f "${CONTAINER_NAME}" &>/dev/null || true

# Prepare agent config mapping
# If AGENTS.md does not exist in workspace, copy a reference copy or link it
echo -e "${BOLD}Initializing sandbox session in /workspace...${RESET}"
echo -e "Inside the container, run ${BOLD}${GREEN}omp${RESET} to start the autonomous coding agent."
echo -e "Type ${BOLD}exit${RESET} or press ${BOLD}Ctrl+D${RESET} to return to your host shell."
echo -e "${BOLD}${CYAN}----------------------------------------------------------------${RESET}\n"

# Run container with interactive TTY, mounting workspace and agent config
docker run --rm -it \
  --name "${CONTAINER_NAME}" \
  --hostname "omp-sandbox" \
  --add-host="host.docker.internal:host-gateway" \
  -e UNSLOTH_ENDPOINT="http://${HOST_IP}:${UNSLOTH_PORT}/v1" \
  -e TERM="xterm-256color" \
  -v "${WORKSPACE_DIR}:/workspace:rw" \
  -v "${CONFIG_DIR}:/home/developer/.omp/agent:ro" \
  "${IMAGE_NAME}" \
  /bin/bash -c "
    echo -e '\033[1;36m'
    echo '  ╔════════════════════════════════════════════════════════════╗'
    echo '  ║       OMP CODING AGENT DOCKER SANDBOX (Active)             ║'
    echo '  ╚════════════════════════════════════════════════════════════╝'
    echo -e '\033[0m'
    echo -e '  Working Directory:  \033[0;32m/workspace\033[0m'
    echo -e '  .NET SDK Version:   \033[0;32m\$(dotnet --version 2>/dev/null || echo \"not found\")\033[0m'
    echo -e '  Ripgrep (rg):       \033[0;32m\$(rg --version 2>/dev/null | head -n 1 || echo \"installed\")\033[0m'
    echo -e '  fd-find (fd):       \033[0;32m\$(fd --version 2>/dev/null || echo \"installed\")\033[0m'
    echo -e '  OMP Binary:         \033[0;32m\$(command -v omp || echo \"/usr/local/bin/omp\")\033[0m'
    echo -e '  Agent Config:       \033[0;34m~/.omp/agent/{models.yml, AGENTS.md}\033[0m'
    echo -e '  Local Model Server: \033[0;34mhttp://host.docker.internal:${UNSLOTH_PORT}/v1\033[0m'
    echo ''
    echo -e '  \033[1;33mQuick Start:\033[0m'
    echo -e '    1. Run \033[1;32momp\033[0m to initiate the autonomous coding agent.'
    echo -e '    2. Use \033[1mrg <query>\033[0m or \033[1mfd <query>\033[0m for fast file searches.'
    echo -e '    3. Build & test with \033[1mdotnet build\033[0m or \033[1mdotnet test\033[0m.'
    echo ''
    exec /bin/bash
  "
