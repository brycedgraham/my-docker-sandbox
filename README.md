# OMP Docker Sandbox Environment & Setup Scripts

A reusable, hardened Docker sandbox environment and cross-platform setup automation for the **[OMP (oh-my-pi)](https://omp.sh)** coding agent harness, designed for remote development servers and local workstations.

## Features

- **Isolated Sandbox**: MicroVM/Container isolation powered by [Docker AI Sandboxes](https://docs.docker.com/ai/sandboxes/) or standard Docker engine.
- **Calling Directory Workspace Mounting**: Automatically binds whichever workspace directory you execute the script from into `/workspace` inside the sandbox.
- **Built-in Tooling**:
  - **.NET 10 SDK** (`dotnet`)
  - **ripgrep** (`rg`) for rapid code search
  - **fd-find** (`fd`) for high-speed file discovery
  - **OMP CLI** (`omp`) pre-installed system-wide in `/usr/local/bin`
  - **Node.js 22 LTS**, Git, JQ, Build-essential
- **Pre-configured Local LLMs (Unsloth)**:
  - `agent-config/models.yml` pre-configured to communicate with an OpenAI-compatible Unsloth/vLLM server running on the host at `http://host.docker.internal:8000/v1`.
- **Egress Network Policy (`network-policy.txt`)**:
  - Balanced preset allowing necessary outbound connections to package feeds (NuGet, npm, PyPI), GitHub, and the local model host, while blocking unauthorized destinations.
- **Cross-Platform**:
  - `setup-sandbox.sh` for Linux & macOS
  - `setup-sandbox.ps1` for Windows PowerShell 7+

---

## Directory Structure

```text
.
├── Dockerfile              # Reusable sandbox image with .NET 10, rg, fd, OMP
├── setup-sandbox.sh        # Linux / macOS setup & launcher script
├── setup-sandbox.ps1       # Windows PowerShell setup & launcher script
├── network-policy.txt      # Outbound allowed connections policy
└── agent-config/
    ├── AGENTS.md           # Instructions, coding guidelines & tooling for OMP
    ├── models.yml          # Unsloth OpenAI-compatible model configuration
    └── config.yml          # OMP agent roles (default, plan, task, advisor)
```

---

## Quick Start (Remote Linux Server / macOS)

### 1. Host Machine Prerequisites
Ensure Docker is installed on your remote server:
```bash
docker --version
```
*(Optional)* If using Docker Desktop or Docker AI Sandboxes CLI:
```bash
sbx --version
```

### 2. Start Unsloth / vLLM on the Host (Port 8000)
Run your local coding model on your host GPU server (listening on all interfaces or host-gateway):
```bash
# Example using vLLM / Unsloth:
vllm serve unsloth/Qwen2.5-Coder-32B-Instruct --port 8000 --host 0.0.0.0
```

### 3. Launch Sandbox from any Repository
Navigate to any project repository on your server and call `setup-sandbox.sh`:
```bash
cd /path/to/your/project
/path/to/omp-sandbox/setup-sandbox.sh
```

To make it globally available from any directory:
```bash
# Add a symlink to your user PATH
ln -s /path/to/omp-sandbox/setup-sandbox.sh ~/.local/bin/omp-sandbox

# Then in any project:
cd ~/my-dotnet-project
omp-sandbox
```

The script will:
1. Verify or build the `omp-sandbox:latest` image.
2. Register the allowed outbound destinations from `network-policy.txt`.
3. Mount your current directory to `/workspace`.
4. Inject `models.yml` and `AGENTS.md` into `~/.omp/agent/`.
5. Drop you into an interactive bash shell in `/workspace`.

### 4. Run the Agent
Inside the container terminal:
```bash
developer@omp-sandbox:/workspace$ omp
```

---

## Quick Start (Windows / Windows Server)

In PowerShell, navigate to your project and run:
```powershell
cd C:\Path\To\YourProject
& "C:\Path\To\omp-sandbox\setup-sandbox.ps1"
```

To force rebuild the image:
```powershell
& "C:\Path\To\omp-sandbox\setup-sandbox.ps1" -Rebuild
```

---

## CLI Options

Both scripts support the following parameters:

| Flag (Bash) | Parameter (PowerShell) | Description | Default |
|-------------|------------------------|-------------|---------|
| `-r`, `--rebuild` | `-Rebuild` | Force rebuild of the Docker sandbox image | `false` |
| `-n`, `--name` | `-Name` | Custom container name | `omp-sbx-<workspace>` |
| `-p`, `--port` | `-Port` | Host port where local Unsloth is listening | `8000` |
| `-h`, `--help` | `Get-Help` | Display usage instructions | — |

---

## Network Policy (`network-policy.txt`)

Docker Sandboxes isolate agent network egress through a host proxy. The included `network-policy.txt` defines:

- **Local Host Inference**: `host.docker.internal:8000`, `127.0.0.1:8000`, `172.17.0.1:8000`
- **.NET & Package Registries**: `api.nuget.org:443`, `registry.npmjs.org:443`, `pypi.org:443`, `crates.io:443`
- **Git Repositories**: `github.com:443`, `api.github.com:443`, `raw.githubusercontent.com:443`
- **OMP Updates**: `omp.sh:443`
- **Cloud AI Fallbacks**: `api.openai.com:443`, `api.anthropic.com:443`, `generativelanguage.googleapis.com:443`

All other unlisted outbound TCP/UDP traffic is denied by default to prevent data exfiltration.

---

## Agent Configuration

### `models.yml`
Located at `agent-config/models.yml`, pre-configured for Unsloth:
```yaml
providers:
  unsloth:
    name: "Local Unsloth Server"
    baseUrl: "http://host.docker.internal:8000/v1"
    apiKey: "not-needed"
    api: "openai-completions"
    models:
      - id: "unsloth/Qwen2.5-Coder-32B-Instruct"
        contextWindow: 131072
        maxTokens: 16384
```

### `AGENTS.md`
Located at `agent-config/AGENTS.md`, contains instructions read by the coding agent regarding:
- Utilizing `rg` for high-speed textual search instead of grep.
- Utilizing `fd` for rapid path and file finding.
- Running `dotnet build` and `dotnet test` before marking tasks complete.
- Adhering to atomic git diffs and network boundaries.

---

## Verification Commands Inside Sandbox

Once dropped into the sandbox bash shell, you can verify all tooling:
```bash
# Verify .NET 10 SDK
dotnet --version

# Verify Ripgrep
rg --version

# Verify fd-find
fd --version

# Verify OMP binary
omp --help

# Test connection to host Unsloth server
curl -s http://host.docker.internal:8000/v1/models
```
