#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "Building Flatpak package using org.gnome.Sdk..."
# Ensure SDK is installed (you already did this)

echo "Running the build inside the Flatpak SDK container..."
flatpak run --command=bash --share=network --filesystem=$(pwd) org.gnome.Sdk//51 $(pwd)/builder/sdk_build.sh

# Setup flatpak directory
rm -rf flatpak-repo flatpak-build

# Initialize the repo
flatpak build-init flatpak-build com.limusic.desktop org.gnome.Sdk org.gnome.Platform 51
mkdir -p flatpak-build/files

# Copy staged files
cp -r flatpak-staging/* flatpak-build/files/

# Finish the build
flatpak build-finish flatpak-build \
    --share=ipc \
    --socket=x11 \
    --socket=wayland \
    --device=dri \
    --share=network \
    --socket=pulseaudio \
    --socket=session-bus \
    --socket=system-bus \
    --own-name=org.mpris.MediaPlayer2.* \
    --env=WEBKIT_DISABLE_SANDBOX=1 \
    --command=limusic

# Export to repo
flatpak build-export flatpak-repo flatpak-build

# Create the bundle
flatpak build-bundle flatpak-repo limusic.flatpak com.limusic.desktop

echo "Done! The flatpak bundle is available at limusic.flatpak."
echo "You can install it using: flatpak install --user limusic.flatpak"
