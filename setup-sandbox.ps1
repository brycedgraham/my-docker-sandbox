<#
.SYNOPSIS
    OMP Coding Agent Sandbox Setup Script (Windows / PowerShell)
    Documentation: https://docs.docker.com/ai/sandboxes/ | https://omp.sh/docs

.DESCRIPTION
    Creates an isolated Docker sandbox based on the current workspace directory,
    loads agent-config (AGENTS.md & models.yml), enforces network policy,
    and drops the user into an interactive bash shell ready to execute `omp`.

.PARAMETER Workspace
    Path to the workspace to mount into the sandbox. Defaults to current directory.

.PARAMETER Rebuild
    Force rebuild of the Docker sandbox image.

.PARAMETER Name
    Custom container/sandbox name.

.PARAMETER Port
    Port on the host where local Unsloth / vLLM is listening. Defaults to 8000.

.EXAMPLE
    .\setup-sandbox.ps1
    .\setup-sandbox.ps1 -Rebuild
    .\setup-sandbox.ps1 -Workspace "C:\Repos\MyProject" -Port 8000
#>

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$Workspace = (Get-Location).Path,

    [switch]$Rebuild,

    [string]$Name = "",

    [int]$Port = 8000,

    [string]$HostIp = "host.docker.internal"
)

$ErrorActionPreference = "Stop"

# Colors
function Write-Cyan ($text)   { Write-Host $text -ForegroundColor Cyan }
function Write-Green ($text)  { Write-Host $text -ForegroundColor Green }
function Write-Yellow ($text) { Write-Host $text -ForegroundColor Yellow }
function Write-Red ($text)    { Write-Host $text -ForegroundColor Red }

# Determine script directories
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigDir = Join-Path $ScriptDir "agent-config"
$PolicyFile = Join-Path $ScriptDir "network-policy.txt"
$Dockerfile = Join-Path $ScriptDir "Dockerfile"
$ImageName = "omp-sandbox:latest"

# Normalize workspace directory
$ResolvedWorkspace = (Resolve-Path -Path $Workspace).Path
$WorkspaceBasename = Split-Path -Leaf $ResolvedWorkspace
if ([string]::IsNullOrWhiteSpace($Name)) {
    $CleanName = ($WorkspaceBasename.ToLower() -replace '[^a-z0-9_-]', '-')
    $Name = "omp-sbx-$CleanName"
}

Write-Cyan "================================================================"
Write-Cyan "      OMP Coding Agent Sandbox Launcher (Windows CLI)           "
Write-Cyan "================================================================"
Write-Host "  Workspace:       " -NoNewline; Write-Green $ResolvedWorkspace
Write-Host "  Container Name:  " -NoNewline; Write-Cyan $Name
Write-Host "  Agent Config:    " -NoNewline; Write-Host $ConfigDir
Write-Host "  Network Policy:  " -NoNewline; Write-Host $PolicyFile
Write-Host "  Unsloth Host:    " -NoNewline; Write-Host "http://${HostIp}:${Port}/v1"
Write-Cyan "----------------------------------------------------------------"

# Verify required files
if (-not (Test-Path $ConfigDir)) {
    Write-Red "Error: agent-config directory not found at $ConfigDir"
    exit 1
}

if (-not (Test-Path (Join-Path $ConfigDir "models.yml")) -or -not (Test-Path (Join-Path $ConfigDir "AGENTS.md"))) {
    Write-Red "Error: models.yml or AGENTS.md missing in $ConfigDir"
    exit 1
}

# Verify Docker availability
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Red "Error: Docker CLI not found. Please install Docker Desktop for Windows: https://docs.docker.com/desktop/setup/install/windows-install/"
    exit 1
}

# Check Docker daemon connectivity
try {
    $null = docker info 2>&1
} catch {
    Write-Red "Error: Cannot connect to Docker daemon. Ensure Docker Desktop is running."
    exit 1
}

# Apply network policy if Docker AI Sandboxes CLI (sbx) is available
$sbxCmd = Get-Command sbx -ErrorAction SilentlyContinue
if ($sbxCmd) {
    Write-Green "✓ Docker AI Sandboxes CLI (sbx) detected."
    Write-Host "  Registering network policy allow rules..."
    if (Test-Path $PolicyFile) {
        sbx policy init balanced 2>$null | Out-Null
        Get-Content $PolicyFile | ForEach-Object {
            $line = $_.Trim()
            if (-not [string]::IsNullOrWhiteSpace($line) -and -not $line.StartsWith("#") -and -not $line.StartsWith("[") -and -not $line.Contains("=")) {
                sbx policy allow network $line 2>$null | Out-Null
            }
        }
        Write-Green "✓ Sandbox network policy rules successfully registered."
    }
} else {
    Write-Yellow "ℹ 'sbx' CLI not found; running with standard Docker container."
}

# Check if image exists
$imageCheck = docker images -q $ImageName 2>$null
if (-not $imageCheck -or $Rebuild) {
    Write-Host "Building Docker sandbox image ($ImageName)..." -ForegroundColor White
    docker build -t $ImageName -f $Dockerfile $ScriptDir
    if ($LASTEXITCODE -ne 0) {
        Write-Red "Error: Failed to build Docker image."
        exit 1
    }
    Write-Green "✓ Docker image built successfully."
} else {
    Write-Green "✓ Using existing Docker image: $ImageName"
}

# Clean up any existing container with same name
docker rm -f $Name 2>$null | Out-Null

# Convert Windows paths for Docker volume mounting
$DockerWorkspace = $ResolvedWorkspace -replace '\\', '/'
$DockerConfig = $ConfigDir -replace '\\', '/'

Write-Host "`nInitializing sandbox session in /workspace..." -ForegroundColor White
Write-Host "Inside container, run " -NoNewline
Write-Green "omp"
Write-Host " to start the autonomous coding agent."
Write-Host "Type " -NoNewline; Write-Host "exit" -ForegroundColor Yellow -NoNewline; Write-Host " or Ctrl+D to return to Windows.`n"

# Run container interactively
docker run --rm -it `
    --name $Name `
    --hostname "omp-sandbox" `
    --security-opt="no-new-privileges:true" `
    --add-host="host.docker.internal:host-gateway" `
    -e UNSLOTH_ENDPOINT="http://${HostIp}:${Port}/v1" `
    -e TERM="xterm-256color" `
    -v "${DockerWorkspace}:/workspace:rw" `
    -v "${DockerConfig}:/home/developer/.omp/agent:ro" `
    $ImageName `
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
      echo -e '  Local Model Server: \033[0;34mhttp://host.docker.internal:${Port}/v1\033[0m'
      echo ''
      echo -e '  \033[1;33mQuick Start:\033[0m'
      echo -e '    1. Run \033[1;32momp\033[0m to initiate the autonomous coding agent.'
      echo -e '    2. Use \033[1mrg <query>\033[0m or \033[1mfd <query>\033[0m for fast file searches.'
      echo -e '    3. Build & test with \033[1mdotnet build\033[0m or \033[1mdotnet test\033[0m.'
      echo ''
      exec /bin/bash
    "
