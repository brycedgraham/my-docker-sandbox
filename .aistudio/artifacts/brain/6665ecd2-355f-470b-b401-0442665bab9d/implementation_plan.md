# CLI Docker Sandbox Harness for OMP Coding Agent (Remote Servers)

A purely CLI-driven, reusable Docker sandbox environment and cross-platform setup automation for remote development servers running the **OMP (oh-my-pi)** coding agent harness.

## User Review & Critical Decisions

> [!IMPORTANT]
> The plan has been revised per your instructions to remove all web applications and UI components:
> - **CLI-Only Architecture**: 100% headless and terminal-native, designed specifically for remote Linux/Windows development servers accessed over SSH.
> - **.NET SDK**: Configured with **.NET 10** SDK pre-installed in the Docker image.
> - **Search & Navigation Utilities**: `ripgrep` (`rg`) and `fd-find` (symlinked as `fd`) baked into the image.
> - **OMP Harness**: Installed globally in `/usr/local/bin/omp`, pre-configured with bash shell integration.
> - **Dual Native Scripts**: 
>   - `setup-sandbox.sh`: Hardened POSIX/Bash script for remote Linux/macOS environments.
>   - `setup-sandbox.ps1`: Native PowerShell 7+ script for Windows development hosts.
> - **Local Unsloth Provider**: `models.yml` configured for local model inference via Unsloth's OpenAI-compatible API (`http://host.docker.internal:8000/v1` or customizable host gateway).
> - **Network Policy**: `network-policy.txt` implementing a balanced preset permitting outbound communication strictly to package registries, GitHub, and local Unsloth endpoints.

---

### 1. Overview & Core Concept

- **What It Does**: Provides a reproducible, isolated CLI workspace for running autonomous coding agents using the `omp` harness on remote servers. When executed in any workspace directory, the setup script:
  1. Detects the calling directory (`$(pwd)` or `$PWD`) as the workspace root.
  2. Builds or verifies the reusable `omp-sandbox:latest` Docker image.
  3. Enforces outbound connection restrictions defined in `network-policy.txt` via Docker AI Sandbox policies (`sbx policy`) or container network boundaries.
  4. Injects agent configurations (`AGENTS.md`, `models.yml`, `config.yml`) into the sandbox user's home configuration directory.
  5. Binds the workspace into `/workspace` and immediately drops the remote SSH user into an interactive bash shell ready to execute `omp`.
- **Target Environment**: Remote development servers, CI/CD runners, and workstation machines accessed via SSH or local terminal.
- **Key Value**: Eliminates host pollution and security risks by running untrusted agent code modifications inside a restricted sandbox, while providing all essential runtimes (.NET 10, ripgrep, fd, OMP) out of the box.

---

### 2. Architecture & Execution Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│ Remote Host Server (Linux / Windows Server)                            │
│                                                                        │
│   Developer runs:                                                      │
│     cd /var/projects/my-app                                            │
│     /opt/omp-sandbox/setup-sandbox.sh                                  │
│                                                                        │
│   Script execution steps:                                              │
│     1. Validate Docker daemon & sbx CLI (or fallback to standard engine)│
│     2. Parse `network-policy.txt` & register allow rules               │
│     3. Mount workspace: /var/projects/my-app ──► /workspace            │
│     4. Mount config:    agent-config/        ──► ~/.omp/agent/         │
│     5. Exec interactive bash session inside container                  │
│                                                                        │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │ Docker Sandbox Environment (`omp-sandbox:latest`)            │     │
│   │                                                              │     │
│   │   • Working Directory: /workspace                            │     │
│   │   • Pre-installed Tools:                                     │     │
│   │     - .NET 10 SDK (`dotnet`)                                 │     │
│   │     - Ripgrep (`rg`)                                         │     │
│   │     - fd-find (`fd`)                                         │     │
│   │     - OMP Harness (`/usr/local/bin/omp`)                     │     │
│   │     - Git, Curl, Jq, Build-essential                         │     │
│   │   • Config Loaded:                                           │     │
│   │     - ~/.omp/agent/models.yml (Unsloth local endpoint)       │     │
│   │     - ~/.omp/agent/AGENTS.md  (Coding instructions)          │     │
│   │     - ~/.omp/agent/config.yml (Model role definitions)       │     │
│   │                                                              │     │
│   │   Prompt: developer@omp-sandbox:/workspace$ omp              │     │
│   └──────────────────────────────┬───────────────────────────────┘     │
│                                  │ Outbound TCP                        │
│                                  ▼                                     │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │ Network Policy Egress Filter (`network-policy.txt`)          │     │
│   │   [ALLOWED] Local host Unsloth (port 8000)                   │     │
│   │   [ALLOWED] NuGet (api.nuget.org:443)                        │     │
│   │   [ALLOWED] npm & PyPI registries                            │     │
│   │   [ALLOWED] GitHub (github.com:443, api.github.com:443)      │     │
│   │   [BLOCKED] All other unauthorized outbound traffic          │     │
│   └──────────────────────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 3. File Deliverables & Structure

The repository will provide the following clean, self-contained files:

1. **`Dockerfile`**:
   - Base: Ubuntu 24.04 LTS (x86_64 and arm64 compatible).
   - Installs:
     - .NET 10 SDK via Microsoft's official installation scripts and feeds.
     - `ripgrep` (`rg`), `fd-find` (with `/usr/local/bin/fd` symlink).
     - Standard dev utilities: `git`, `curl`, `wget`, `jq`, `ca-certificates`, `procps`, `build-essential`.
     - OMP CLI harness (`curl -fsSL https://omp.sh/install | sh`) installed system-wide in `/usr/local/bin/omp`.
   - User setup: Non-root `developer` user with sudo privileges, default working directory `/workspace`.

2. **`setup-sandbox.sh` (Linux / macOS)**:
   - Remote-server friendly Bash script with interactive TTY detection (`-it`).
   - Supports CLI flags:
     - `--rebuild` (forces Docker image rebuild).
     - `--name <name>` (custom container/sandbox name).
     - `--host-ip <ip>` (custom host IP for local Unsloth service).
     - `--help` (usage documentation).
   - Automatically detects current working directory (`$(pwd)`) as `/workspace`.
   - Auto-detects Docker AI Sandboxes CLI (`sbx`) if available:
     - Applies rules from `network-policy.txt` via `sbx policy allow network`.
     - Launches sandbox using `sbx run` or `sbx create`.
   - If standard Docker is used:
     - Configures Docker container with `--add-host=host.docker.internal:host-gateway`.
     - Drops user into `/bin/bash` in `/workspace`.

3. **`setup-sandbox.ps1` (Windows Server / PowerShell)**:
   - Native PowerShell 7+ equivalent handling Windows path resolution, environment variables, policy registration, and interactive console allocation.

4. **`network-policy.txt`**:
   - Plain-text configuration file consumed by `setup-sandbox.sh` and `setup-sandbox.ps1`.
   - Defines allowed outbound hostnames and ports:
     - `host.docker.internal:8000` (Local Unsloth API)
     - `api.nuget.org:443`, `*.nuget.org:443` (.NET package feeds)
     - `registry.npmjs.org:443`, `pypi.org:443`, `files.pythonhosted.org:443`
     - `github.com:443`, `api.github.com:443`, `raw.githubusercontent.com:443`
     - `omp.sh:443`

5. **`agent-config/` Directory**:
   - `models.yml`: Pre-configured for local Unsloth (OpenAI-compatible protocol), pointing to `http://host.docker.internal:8000/v1` with model aliases (`unsloth/Qwen2.5-Coder-32B-Instruct`, `unsloth/DeepSeek-R1-Distill-Qwen-32B`), context limits, and temperature defaults.
   - `AGENTS.md`: Production-ready instructions detailing workflow expectations:
     - Use of `rg` and `fd` for code inspection.
     - .NET 10 compilation (`dotnet build`, `dotnet test`).
     - Safe git branch hygiene and atomic diffs.
   - `config.yml`: OMP agent role assignments (`default`, `plan`, `slow`, `task`, `advisor`).

6. **`README.md`**:
   - Step-by-step remote server deployment guide:
     - Host prerequisites (Docker / Docker Desktop / Docker AI Sandboxes CLI `sbx`).
     - Running Unsloth on host (`vllm serve` or `unsloth` server on port 8000).
     - Starting sandboxes from any repository directory.
     - Troubleshooting network policies and host connectivity.

---

### 4. Verification & Testing Steps

- Verify image builds cleanly (`docker build -t omp-sandbox:latest .`).
- Verify .NET 10 SDK (`dotnet --version` outputs 10.x).
- Verify `rg` and `fd` are immediately available in PATH.
- Verify `omp --version` / `omp --help` executes inside the container.
- Verify configuration files are mounted to `~/.omp/agent/` (`models.yml`, `AGENTS.md`).
- Verify script drops directly into `/bin/bash` in `/workspace`.
