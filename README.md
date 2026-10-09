# Limusic SteamOS Optimized Builder

This repository contains a set of scripts to automatically clone, patch, and compile the [Limusic](https://github.com/SimoHypers/limusic) application specifically optimized for the Steam Machine (SteamOS) and its Zen 2 architecture.

## Why this builder?
The default release of Limusic is compiled for generic x86_64 architectures. Building it on SteamOS locally with these scripts brings several benefits:
- **Maximum Zen 2 Optimizations**: Compiled with `RUSTFLAGS="-C target-cpu=znver2"` utilizing specific instructions for the Steam Machine CPU.
- **Aggressive LTO (Link-Time Optimization)**: Rust profile is set to `lto = "fat"`, `opt-level = 3`, and `codegen-units = 1`. This dramatically increases build time but provides the highest possible runtime performance and smallest binary size.
- **Fast Panics**: `panic = "abort"` reduces overhead.
- **Built-in dependencies**: Compiles a custom, headless `mpv` player directly from source with Wayland, X11, and Vulkan support, avoiding host OS library conflicts.
- **Sandbox Fixes**: Disables WebKitGTK sandbox in Flatpak (`WEBKIT_DISABLE_SANDBOX=1`) to prevent custom URI scheme (`tauri://localhost`) crashes, ensuring the UI loads perfectly.
- **Flatpak Containerized**: The entire compilation happens cleanly inside the `org.gnome.Sdk//51` Flatpak container. No root access or modifications to your underlying immutable SteamOS are required.

## 🛡️ Safe for SteamOS (Containerized Build)
One of the biggest challenges of compiling software on the Steam Machine is its immutable root filesystem. 
This builder **completely bypasses this limitation** by doing 100% of the compilation inside a Flatpak SDK container (`org.gnome.Sdk`). 
- **No `sudo` or `pacman` required.**
- **No unlocking the root filesystem.**
- **Leaves zero mess on your host OS** (all dependencies like Node.js, Rust, and C compilers are downloaded and executed strictly within the isolated sandbox).

## Requirements
You only need Flatpak and the GNOME SDK installed on your Steam Machine.
Open your terminal (Konsole) and run:

```bash
flatpak install flathub org.gnome.Sdk//51 org.gnome.Platform//51
```

## How to Build
1. Clone this repository (or download the zip).
2. Open a terminal in the folder.
3. Run the builder script:
   ```bash
   ./build.sh
   ```
4. Grab a coffee. ☕ The script will download the Limusic source, apply the optimization patches, download the Rust compiler inside the sandbox, build `libass`, `libplacebo`, `mpv`, the Node.js frontend, and the Rust backend. This will take around 10-15 minutes on a Steam Machine.

## Installation
Once the build is complete, you will find a `limusic.flatpak` file in the `limusic/` directory.
Install it by running:
```bash
flatpak install --user limusic/limusic.flatpak
```
*(If you are updating an existing installation, add `--reinstall -y` to the command).*

After installation, "Limusic" will appear in your KDE Plasma application menu and can be added to Gaming Mode as a Non-Steam Game!

## Credits
- [Limusic](https://github.com/SimoHypers/limusic) by SimoHypers.
- SteamOS optimizations and fixes generated via AI Assistance.
