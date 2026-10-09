#!/bin/bash
set -e

# Copy source to a safe place to avoid messing with host's target dir permissions if things go wrong,
# but since UID is 1000, we can just build directly.
cd /workspace

# Build frontend
cd /workspace/ui
pnpm install

# Build the optimized release
# We use znver2 which is the architecture of the Steam Deck's AMD Zen 2 CPU.
export RUSTFLAGS="-C target-cpu=znver2"

cd /workspace/ui
pnpm run build

cd /workspace/src-tauri
cargo build --release

# The output will be in src-tauri/target/release/bundle/
# We will copy the needed files for flatpak to a staging directory
mkdir -p /workspace/flatpak-staging/bin
mkdir -p /workspace/flatpak-staging/share/applications
mkdir -p /workspace/flatpak-staging/share/icons/hicolor

# The output binary could be named limusic or limusic-app depending on Tauri version
if [ -f "src-tauri/target/release/limusic" ]; then
    cp src-tauri/target/release/limusic /workspace/flatpak-staging/bin/limusic
elif [ -f "src-tauri/target/release/limusic-app" ]; then
    cp src-tauri/target/release/limusic-app /workspace/flatpak-staging/bin/limusic
else
    echo "Could not find built binary!"
    exit 1
fi


# Create a desktop file
cat <<EOF > /workspace/flatpak-staging/share/applications/com.limusic.desktop.desktop
[Desktop Entry]
Name=Limusic
Exec=limusic
Icon=com.limusic.desktop
Type=Application
Categories=AudioVideo;Music;
Terminal=false
EOF

# Copy icons (assuming they are in src-tauri/icons/)
# The bundle deb or appimage generation might already put them somewhere, but let's copy manually
for size in 32 64 128; do
    mkdir -p /workspace/flatpak-staging/share/icons/hicolor/${size}x${size}/apps/
    cp src-tauri/icons/${size}x${size}.png /workspace/flatpak-staging/share/icons/hicolor/${size}x${size}/apps/com.limusic.desktop.png || true
done
mkdir -p /workspace/flatpak-staging/share/icons/hicolor/256x256/apps/
cp src-tauri/icons/128x128@2x.png /workspace/flatpak-staging/share/icons/hicolor/256x256/apps/com.limusic.desktop.png || true

echo "Build completed successfully inside container. Files staged in flatpak-staging/"
