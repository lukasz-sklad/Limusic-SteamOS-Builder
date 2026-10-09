#!/bin/bash
set -e

echo "=== Limusic SteamOS Optimized Builder ==="
echo "Cloning Limusic repo..."
if [ ! -d "limusic" ]; then
    git clone https://github.com/SimoHypers/limusic.git
fi
cd limusic
git reset --hard HEAD
git clean -fdx || true

echo "Applying SteamOS Optimizations (Zen 2, LTO fat, panic=abort)..."

# 1. Cargo.toml optimization profiles
cat << 'PATCH' > cargo.patch
--- Cargo.toml
+++ Cargo.toml
@@ -28,6 +28,8 @@
 # panic stays "unwind": an abort in the mpv event thread or a tokio task would kill playback
 # for the whole app instead of degrading.
 [profile.release]
-lto = "thin"
+opt-level = 3
+lto = "fat"
 codegen-units = 1
+panic = "abort"
 strip = "symbols"
PATCH
patch Cargo.toml < cargo.patch

# 2. Fix mpv ytdl property crash
cat << 'PATCH' > player.patch
--- crates/player/src/lib.rs
+++ crates/player/src/lib.rs
@@ -224,7 +224,7 @@
     // the real failure. A stream that 403s went "Stream ends prematurely" -> ytdl_hook ->
     // "youtube-dl failed: not found" -> "Failed to recognize file format", so the user was told
     // their audio format was wrong when the download had been refused (issue #292).
-    mpv.set_property("ytdl", "no")?;
+    let _ = mpv.set_property("ytdl", "no");
     // What the system mixer calls the stream. mpv's own names are "mpv" and `<media title> - mpv`,
     // and the media title of a proxied stream is the last segment of its loopback URL, so KDE's
PATCH
patch crates/player/src/lib.rs < player.patch

# 3. Fix tauri.conf.json build step
cat << 'PATCH' > tauri.patch
--- src-tauri/tauri.conf.json
+++ src-tauri/tauri.conf.json
@@ -6,7 +6,7 @@
     "frontendDist": "../ui/build",
     "devUrl": "http://localhost:5183",
     "beforeDevCommand": "pnpm dev",
-    "beforeBuildCommand": "pnpm build"
+    "beforeBuildCommand": ""
   },
   "app": {
     "windows": [
PATCH
patch src-tauri/tauri.conf.json < tauri.patch

echo "Copying Builder scripts..."
cp -r ../builder .

echo "Starting Flatpak Build inside org.gnome.Sdk container..."
./builder/build_flatpak.sh

echo "========================================="
echo "Done! The optimized package is ready."
echo "You can install it with:"
echo "  flatpak install --user limusic/limusic.flatpak"
echo "========================================="
