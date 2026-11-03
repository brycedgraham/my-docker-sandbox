/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState } from 'react';
import { Terminal, Copy, Check, Shield, Cpu, FolderCode, BookOpen, ExternalLink, ChevronRight } from 'lucide-react';

interface FileTab {
  id: string;
  name: string;
  path: string;
  lang: string;
  content: string;
}

const FILES: FileTab[] = [
  {
    id: 'setup-sh',
    name: 'setup-sandbox.sh',
    path: './setup-sandbox.sh',
    lang: 'bash',
    content: `#!/usr/bin/env bash
# OMP Coding Agent Sandbox Setup Script (Linux / macOS)
# Creates an isolated Docker sandbox based on the current workspace directory,
# loads agent-config, applies network-policy.txt, and drops into bash.

set -euo pipefail

WORKSPACE_DIR="$(pwd)"
WORKSPACE_NAME="$(basename "$WORKSPACE_DIR")"
IMAGE_NAME="omp-sandbox:latest"
CONTAINER_NAME="omp-sbx-\${WORKSPACE_NAME,,}"

SCRIPT_DIR="$( cd -P "$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_DIR="\${SCRIPT_DIR}/agent-config"
POLICY_FILE="\${SCRIPT_DIR}/network-policy.txt"
DOCKERFILE_PATH="\${SCRIPT_DIR}/Dockerfile"

# Apply network policy if sbx CLI is present
if command -v sbx &>/dev/null; then
  sbx policy init balanced 2>/dev/null || true
  # Registers allowed destinations from network-policy.txt
fi

# Build or verify image
docker build -t "\${IMAGE_NAME}" -f "\${DOCKERFILE_PATH}" "\${SCRIPT_DIR}"

# Launch container mounting current directory & agent configs
docker run --rm -it \\
  --name "\${CONTAINER_NAME}" \\
  --hostname "omp-sandbox" \\
  --add-host="host.docker.internal:host-gateway" \\
  -e UNSLOTH_ENDPOINT="http://host.docker.internal:8000/v1" \\
  -v "\${WORKSPACE_DIR}:/workspace:rw" \\
  -v "\${CONFIG_DIR}:/home/developer/.omp/agent:ro" \\
  "\${IMAGE_NAME}" \\
  /bin/bash`
  },
  {
    id: 'setup-ps1',
    name: 'setup-sandbox.ps1',
    path: './setup-sandbox.ps1',
    lang: 'powershell',
    content: `<#
  OMP Coding Agent Sandbox Setup Script (Windows / PowerShell)
  Mounts current workspace into /workspace, loads models.yml/AGENTS.md,
  and launches an interactive bash shell for running omp.
#>
param (
    [string]$Workspace = (Get-Location).Path,
    [switch]$Rebuild,
    [string]$Name = "",
    [int]$Port = 8000
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigDir = Join-Path $ScriptDir "agent-config"
$DockerWorkspace = (Resolve-Path $Workspace).Path -replace '\\\\', '/'
$DockerConfig = $ConfigDir -replace '\\\\', '/'

docker run --rm -it \`
    --hostname "omp-sandbox" \`
    --add-host="host.docker.internal:host-gateway" \`
    -e UNSLOTH_ENDPOINT="http://host.docker.internal:\${Port}/v1" \`
    -v "\${DockerWorkspace}:/workspace:rw" \`
    -v "\${DockerConfig}:/home/developer/.omp/agent:ro" \`
    "omp-sandbox:latest" /bin/bash`
  },
  {
    id: 'dockerfile',
    name: 'Dockerfile',
    path: './Dockerfile',
    lang: 'dockerfile',
    content: `FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH="/usr/share/dotnet:/usr/local/bin:/home/developer/.local/bin:\${PATH}"

# Install core build tools, ripgrep (rg), and fd-find (fd)
RUN apt-get update && apt-get install -y --no-install-recommends \\
    ca-certificates curl wget git ripgrep fd-find jq build-essential sudo \\
    && rm -rf /var/lib/apt/lists/* && \\
    ln -s /usr/bin/fdfind /usr/local/bin/fd

# Install .NET 10 SDK
RUN mkdir -p /usr/share/dotnet && \\
    curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0 --install-dir /usr/share/dotnet && \\
    ln -s /usr/share/dotnet/dotnet /usr/local/bin/dotnet

# Install OMP (oh-my-pi) coding harness
RUN curl -fsSL https://omp.sh/install | bash && \\
    cp /root/.local/bin/omp /usr/local/bin/omp 2>/dev/null || true

# Non-root developer user with passwordless sudo
RUN useradd -m -s /bin/bash -u 1000 -G sudo developer && \\
    echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

WORKDIR /workspace
USER developer
CMD ["/bin/bash"]`
  },
  {
    id: 'network-policy',
    name: 'network-policy.txt',
    path: './network-policy.txt',
    lang: 'text',
    content: `# Docker AI Sandbox Network Policy Allowlist
# Preset: balanced (default egress deny)

# Local Unsloth LLM inference
host.docker.internal:8000
127.0.0.1:8000

# Package Registries & Development
api.nuget.org:443
*.nuget.org:443
registry.npmjs.org:443
pypi.org:443
crates.io:443

# GitHub & OMP Sources
github.com:443
api.github.com:443
raw.githubusercontent.com:443
omp.sh:443

# Remote AI APIs (Fallbacks)
api.openai.com:443
api.anthropic.com:443`
  },
  {
    id: 'models-yml',
    name: 'models.yml',
    path: './agent-config/models.yml',
    lang: 'yaml',
    content: `# Pre-configured for local models via Unsloth (OpenAI-compatible server)
providers:
  unsloth:
    name: "Local Unsloth Server"
    baseUrl: "http://host.docker.internal:8000/v1"
    apiKey: "not-needed"
    api: "openai-completions"
    models:
      - id: "unsloth/Qwen2.5-Coder-32B-Instruct"
        name: "Qwen 2.5 Coder 32B (Unsloth)"
        contextWindow: 131072
        maxTokens: 16384
      - id: "unsloth/DeepSeek-R1-Distill-Qwen-32B"
        name: "DeepSeek R1 Distill Qwen 32B (Unsloth)"
        contextWindow: 65536
        maxTokens: 16384`
  },
  {
    id: 'agents-md',
    name: 'AGENTS.md',
    path: './agent-config/AGENTS.md',
    lang: 'markdown',
    content: `# Coding Agent Guidelines for OMP Sandbox

- Tooling available: .NET 10 (dotnet), ripgrep (rg), fd-find (fd), git, omp
- Always use 'rg <pattern>' for recursive search instead of grep.
- Always use 'fd <pattern>' for directory and path search instead of find.
- Verify changes using 'dotnet build' and 'dotnet test' before completion.
- Network egress is restricted by network-policy.txt to approved endpoints.`
  }
];

export default function App() {
  const [activeTab, setActiveTab] = useState<string>('setup-sh');
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const selectedFile = FILES.find((f) => f.id === activeTab) || FILES[0];

  const handleCopy = (id: string, text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 font-sans flex flex-col">
      {/* Top Header */}
      <header className="border-b border-slate-800 bg-slate-900/60 backdrop-blur px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center text-cyan-400">
            <Terminal className="w-4 h-4" />
          </div>
          <div>
            <h1 className="text-sm font-semibold tracking-wide text-slate-100 flex items-center gap-2">
              OMP Docker Sandbox Environment
              <span className="text-xs font-mono text-cyan-400 font-normal">CLI Mode</span>
            </h1>
            <p className="text-xs text-slate-400">Headless remote development server harness for omp.sh</p>
          </div>
        </div>

        <div className="flex items-center gap-4 text-xs text-slate-400">
          <a
            href="https://omp.sh/docs"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1.5 hover:text-cyan-400 transition-colors"
          >
            <span>omp.sh Docs</span>
            <ExternalLink className="w-3.5 h-3.5" />
          </a>
          <a
            href="https://docs.docker.com/ai/sandboxes/"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1.5 hover:text-cyan-400 transition-colors"
          >
            <span>Docker Sandboxes</span>
            <ExternalLink className="w-3.5 h-3.5" />
          </a>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 max-w-7xl w-full mx-auto p-6 grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Quick CLI commands & overview */}
        <div className="lg:col-span-4 space-y-6">
          {/* Quick Start Card */}
          <div className="bg-slate-900/80 border border-slate-800 rounded-lg p-5">
            <div className="flex items-center gap-2 mb-3">
              <Terminal className="w-4 h-4 text-cyan-400" />
              <h2 className="text-sm font-semibold text-slate-200">Remote Server Quick Start</h2>
            </div>
            <p className="text-xs text-slate-400 mb-4 leading-relaxed">
              Navigate to your workspace on your remote server and execute the launcher script to drop directly into an isolated bash shell:
            </p>

            <div className="space-y-3 font-mono text-xs">
              <div className="bg-slate-950 border border-slate-800 rounded p-3 relative group">
                <span className="text-slate-500 select-none"># 1. Linux / macOS</span>
                <div className="text-cyan-300 mt-1 select-all">./setup-sandbox.sh</div>
                <button
                  onClick={() => handleCopy('cli-sh', './setup-sandbox.sh')}
                  className="absolute top-2.5 right-2.5 text-slate-400 hover:text-slate-200"
                  title="Copy command"
                >
                  {copiedId === 'cli-sh' ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                </button>
              </div>

              <div className="bg-slate-950 border border-slate-800 rounded p-3 relative group">
                <span className="text-slate-500 select-none"># 2. Windows PowerShell</span>
                <div className="text-cyan-300 mt-1 select-all">.\setup-sandbox.ps1</div>
                <button
                  onClick={() => handleCopy('cli-ps1', '.\\setup-sandbox.ps1')}
                  className="absolute top-2.5 right-2.5 text-slate-400 hover:text-slate-200"
                  title="Copy command"
                >
                  {copiedId === 'cli-ps1' ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                </button>
              </div>

              <div className="bg-slate-950 border border-slate-800 rounded p-3 relative group">
                <span className="text-slate-500 select-none"># 3. Inside Sandbox</span>
                <div className="text-emerald-400 mt-1 select-all">omp</div>
                <button
                  onClick={() => handleCopy('cli-omp', 'omp')}
                  className="absolute top-2.5 right-2.5 text-slate-400 hover:text-slate-200"
                  title="Copy command"
                >
                  {copiedId === 'cli-omp' ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                </button>
              </div>
            </div>
          </div>

          {/* Capabilities Grid */}
          <div className="bg-slate-900/80 border border-slate-800 rounded-lg p-5 space-y-4">
            <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-400">Environment Specifications</h2>

            <div className="space-y-3 text-xs">
              <div className="flex items-start gap-3">
                <Cpu className="w-4 h-4 text-cyan-400 mt-0.5 shrink-0" />
                <div>
                  <div className="font-medium text-slate-200">.NET 10 SDK & Tooling</div>
                  <div className="text-slate-400 text-[11px]">.NET 10 compiler, ripgrep (rg), and fd-find (fd) pre-installed</div>
                </div>
              </div>

              <div className="flex items-start gap-3">
                <Shield className="w-4 h-4 text-emerald-400 mt-0.5 shrink-0" />
                <div>
                  <div className="font-medium text-slate-200">Network Egress Filter</div>
                  <div className="text-slate-400 text-[11px]">network-policy.txt balanced rules for NuGet, npm, GitHub & host Unsloth</div>
                </div>
              </div>

              <div className="flex items-start gap-3">
                <FolderCode className="w-4 h-4 text-blue-400 mt-0.5 shrink-0" />
                <div>
                  <div className="font-medium text-slate-200">Calling Directory Workspace</div>
                  <div className="text-slate-400 text-[11px]">Auto-mounts the invocation directory to /workspace</div>
                </div>
              </div>

              <div className="flex items-start gap-3">
                <BookOpen className="w-4 h-4 text-amber-400 mt-0.5 shrink-0" />
                <div>
                  <div className="font-medium text-slate-200">Unsloth Local LLMs</div>
                  <div className="text-slate-400 text-[11px]">models.yml pointing to host.docker.internal:8000/v1 (OpenAI API)</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Right Column: Interactive File & Config Viewer */}
        <div className="lg:col-span-8 flex flex-col bg-slate-900/80 border border-slate-800 rounded-lg overflow-hidden">
          {/* File Tabs */}
          <div className="flex items-center overflow-x-auto border-b border-slate-800 bg-slate-950/60 px-2 pt-2 scrollbar-none">
            {FILES.map((file) => (
              <button
                key={file.id}
                onClick={() => setActiveTab(file.id)}
                className={`flex items-center gap-2 px-3 py-2 text-xs font-mono rounded-t transition-colors whitespace-nowrap border-b-2 ${
                  activeTab === file.id
                    ? 'bg-slate-900 text-cyan-300 border-cyan-400 font-medium'
                    : 'text-slate-400 border-transparent hover:text-slate-200 hover:bg-slate-900/40'
                }`}
              >
                <span>{file.name}</span>
              </button>
            ))}
          </div>

          {/* Subheader with file path and copy */}
          <div className="px-4 py-2 bg-slate-900 border-b border-slate-800/80 flex items-center justify-between text-xs font-mono text-slate-400">
            <span className="flex items-center gap-1.5 text-slate-300">
              <ChevronRight className="w-3.5 h-3.5 text-cyan-400" />
              {selectedFile.path}
            </span>
            <button
              onClick={() => handleCopy(selectedFile.id, selectedFile.content)}
              className="flex items-center gap-1.5 px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs transition-colors"
            >
              {copiedId === selectedFile.id ? (
                <>
                  <Check className="w-3 h-3 text-emerald-400" />
                  <span className="text-emerald-400">Copied</span>
                </>
              ) : (
                <>
                  <Copy className="w-3 h-3" />
                  <span>Copy File</span>
                </>
              )}
            </button>
          </div>

          {/* Code Viewer */}
          <div className="flex-1 p-4 bg-slate-950 font-mono text-xs overflow-x-auto text-slate-300 leading-relaxed selection:bg-cyan-500/30">
            <pre className="whitespace-pre">{selectedFile.content}</pre>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-slate-800 py-3 px-6 text-center text-xs text-slate-500 font-mono">
        OMP Coding Agent Sandbox Harness · Designed for Remote Linux / Windows Development Servers
      </footer>
    </div>
  );
}
