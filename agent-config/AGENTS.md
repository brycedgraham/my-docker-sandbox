# AGENTS.md - Coding Agent Guidelines & Environment Context

Welcome to the Docker Sandbox environment for the **OMP (oh-my-pi)** coding agent harness.

## 1. Sandbox Environment & Installed Tooling

You are executing within an isolated, hardened Linux container sandbox with root privileges via `sudo`.

The following high-performance tools and SDKs are pre-installed in your environment:
- **.NET 10 SDK**: `dotnet --version` (C# 13 / .NET 10 runtimes and compiler).
- **Ripgrep (`rg`)**: High-speed recursive code search (`rg <pattern>`).
- **fd-find (`fd`)**: High-speed directory and file search (`fd <pattern>`).
- **Git**: Version control (`git status`, `git diff`, `git log`).
- **OMP Coding Harness**: Terminal agent orchestrator (`omp`).
- **Node.js & npm**: Runtime for language server protocol (LSP) servers and formatting tools.
- **Curl, JQ, Tar, Unzip, Build-essential**: Standard POSIX utilities.

---

## 2. Codebase Exploration Best Practices

When analyzing files in the `/workspace` directory:
1. **Always prefer `rg` over grep**:
   ```bash
   # Search for symbol definition
   rg "class OrderProcessor"
   # Search files of specific type
   rg "Task<IActionResult>" -t cs
   ```
2. **Always prefer `fd` over find**:
   ```bash
   # Find all C# project files
   fd -e csproj
   # Find configuration files
   fd "appsettings.*\.json"
   ```
3. **Inspect project structure cleanly**:
   ```bash
   dotnet sln list
   dotnet list package
   ```

---

## 3. Build & Test Verification

Before reporting any task complete or suggesting a commit:
1. **Run .NET compilation**:
   ```bash
   dotnet build --configuration Release --verbosity minimal
   ```
2. **Execute all test suites**:
   ```bash
   dotnet test --no-build --verbosity normal
   ```
3. **Check compiler warnings & errors**:
   Never leave unresolved compilation errors or new warnings introduced by your changes.

---

## 4. Code Modification Standards

- **Atomic, Minimal Diffs**: Only modify files directly related to the user's objective. Do not reformat unrelated files or strip comments.
- **Preserve Existing Architecture**: Respect the existing project patterns (e.g., Clean Architecture, CQRS, Minimal APIs, or ASP.NET Controller conventions).
- **Git Hygiene**: Check `git status` and `git diff` before and after modifying files.

---

## 5. Network & Security Constraints

- Outbound network egress is governed by `network-policy.txt` enforced by Docker Sandbox policies (`sbx policy`).
- **Permitted**: Local LLM server (`host.docker.internal:8000`), NuGet package feeds, npm registry, PyPI, and GitHub.
- **Prohibited**: Unapproved external HTTP/TCP requests will be rejected by the proxy. Keep all model communication directed through the configured local Unsloth provider or designated APIs.
