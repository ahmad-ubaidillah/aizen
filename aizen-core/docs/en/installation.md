# Installation

This guide covers the main installation paths for macOS, Linux, and Windows.

## Page Guide

**Who this page is for**

- First-time users installing Aizen on a local machine
- Operators choosing between package install, container deployment, and source build
- Contributors validating the baseline runtime before deeper setup

**Read this next**

- Open [Configuration](./configuration.md) after the binary is installed and on your `PATH`
- Open [Usage and Operations](./usage.md) when you are ready to run first commands and service mode
- Open [README](./README.md) if you want the broader English docs map before going deeper

**If you came from ...**

- [README](./README.md): this page is the concrete first-run path after choosing the installation track
- [Commands](./commands.md): come here first if the CLI is missing or `aizen --help` does not work yet
- [Development](./development.md): return here if a contributor workflow also needs a clean local binary setup

## Prerequisites

- If building from source, use **Zig 0.16.0**.
- Git (required for source install).

Check Zig version:

```bash
zig version
```

The output must be `0.16.0`.

## Option 1: Homebrew (recommended for macOS/Linux)

```bash
brew install aizen
aizen --help
```

If the command works, installation is complete.

## Option 2: Official Container Image (Docker / Podman)

Aizen publishes an official OCI image at `ghcr.io/aizen/aizen`.

The container stores its persistent state under `/aizen-data`:

- config: `/aizen-data/config.json`
- workspace: `/aizen-data/workspace`

The bundled starter config already uses the current schema (`agents.defaults.model.primary` plus `models.providers`), so `latest` should boot cleanly before you customize provider credentials.

### Quick one-off commands

```bash
docker run --rm -it \
  -v aizen-data:/aizen-data \
  ghcr.io/aizen/aizen:latest status
```

Initialize config interactively:

```bash
docker run --rm -it \
  -v aizen-data:/aizen-data \
  ghcr.io/aizen/aizen:latest onboard --interactive
```

Run the interactive agent:

```bash
docker run --rm -it \
  -v aizen-data:/aizen-data \
  ghcr.io/aizen/aizen:latest agent
```

Run the HTTP gateway:

```bash
docker run --rm -it \
  -p 127.0.0.1:3000:3000 \
  -v aizen-data:/aizen-data \
  ghcr.io/aizen/aizen:latest
```

### Docker Compose

The repository ships a `docker-compose.yml` that uses the official image by default.

Interactive onboarding:

```bash
docker compose --profile agent run --rm agent onboard --interactive
```

Inside the official container flow, pressing Enter at the workspace prompt keeps the volume-backed default:

- workspace: `/aizen-data/workspace`

Interactive agent session:

```bash
docker compose --profile agent run --rm agent
```

Long-running gateway:

```bash
docker compose --profile gateway up -d gateway
```

Profile behavior:

- `agent`: one-off interactive CLI container
- `gateway`: long-running HTTP gateway published on host loopback port `3000`

If you need LAN or public exposure, change the published host IP deliberately and review [Security](./security.md) first.

To pin a release tag or switch registries later, override `AIZEN_IMAGE`:

```bash
AIZEN_IMAGE=ghcr.io/aizen/aizen:v2026.3.11 docker compose --profile gateway up -d gateway
```

## Option 3: Build from Source (cross-platform)

```bash
git clone https://github.com/aizen/aizen.git
cd aizen
zig build -Doptimize=ReleaseSmall
zig build test --summary all
```

Build output:

- `zig-out/bin/aizen`

## Option 4: Android / Termux

There are three different Android / Termux paths:

- download an official pre-built Android / Termux binary from releases
- build directly inside Termux on the Android device
- cross-compile an Android binary from another machine

### Termux native build

```bash
pkg update
pkg install git zig
git clone https://github.com/aizen/aizen.git
cd aizen
zig version
zig build -Doptimize=ReleaseSmall
./zig-out/bin/aizen --help
```

Notes:

- Use **Zig 0.16.0** exactly.
- If `zig build` fails immediately, verify the Zig version first.
- This uses the native target of the current Termux environment, so you usually do **not** need `-Dtarget`.
- On Android / Termux, prefer foreground use first (`agent`, `gateway`) before trying to manage it as a background service.
- Official releases publish pre-built Android / Termux binaries for `aarch64`, `armv7`, and `x86_64`.
- For the fuller Android / Termux path, including troubleshooting, see [Termux Guide](./termux.md).

### Cross-compiling for Android

If you are building on another machine for a Termux / Android device, pass an explicit Zig target and an Android libc/sysroot file. `-Dtarget` alone is not enough:

```bash
zig build -Dtarget=aarch64-linux-android.24 -Doptimize=ReleaseSmall --libc /path/to/android-libc-aarch64.txt
```

Common Android targets:

- `aarch64-linux-android.24`
- `arm-linux-androideabi.24` with `-Dcpu=baseline+v7a`
- `x86_64-linux-android.24`

Use the target that matches the phone or emulator architecture.
See [`.github/workflows/release.yml`](../../.github/workflows/release.yml) for a complete example of generating the `--libc` file from the Android NDK.
Official releases also attach matching Android / Termux binaries built for Android API 24.

## Add binary to PATH

### Compiled binary file

#### macOS/Linux（zsh/bash）

```bash
zig build -Doptimize=ReleaseSmall -p "$HOME/.local"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
# bash users: use ~/.bashrc
source ~/.zshrc
```

#### Windows（PowerShell）

```powershell
zig build -Doptimize=ReleaseSmall -p "$HOME\.local"

$bin = "$HOME\.local\bin"
$user_path = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not ($user_path -split ";" | Where-Object { $_ -eq $bin })) {
  [Environment]::SetEnvironmentVariable("Path", "$user_path;$bin", "User")
}
$env:Path = "$env:Path;$bin"
```

### Downloaded aizen binary file (Windows, Powershell)
Download the Windows `.zip` archive from the releases page, extract it, and then run the following commands with administrator privileges in Powershell to add the directory containing `aizen.exe` to the Windows `PATH` environment variable:

```Powershell 
$old = [Environment]::GetEnvironmentVariable("Path", "Machine")
$new = "$old;x:\path\to\aizen"
[Environment]::SetEnvironmentVariable("Path", $new, "Machine")
```

## Verify Installation

```bash
aizen --help
aizen --version
aizen status
```

If `status` returns component state successfully, runtime basics are ready.

## Upgrade and Uninstall

### Homebrew（Recommended for macOS/Linux）

- update:
```bash
brew update
brew upgrade aizen
```
- uninstall:
```bash
brew uninstall aizen
```
#### Command line(CMD) (Windows)

- update: `aizen update`

- uninstall: delete the `aizen` binary file and remove the entry of the directory containing the binary file in environment variables PATH if it exists.

### Source install

- Upgrade: `git pull`, then rebuild with `zig build -Doptimize=ReleaseSmall`.
- Uninstall: delete the installed `aizen` binary and remove the PATH entry.

## Next Steps

- Run `aizen onboard --interactive`, then continue with [Configuration](./configuration.md)
- Use [Usage and Operations](./usage.md) for first-run commands, service mode, and troubleshooting
- Keep [Commands](./commands.md) nearby if you want a task-based CLI reference after install

## Related Pages

- [README](./README.md)
- [Termux Guide](./termux.md)
- [Configuration](./configuration.md)
- [Usage and Operations](./usage.md)
- [Commands](./commands.md)
