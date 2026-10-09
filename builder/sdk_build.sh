#!/bin/bash
set -e

# This script runs INSIDE org.gnome.Sdk//51
WORKSPACE=$(pwd)

export HOME=$WORKSPACE/builder/home
mkdir -p $HOME
export PATH="$HOME/.cargo/bin:$HOME/node/bin:$PATH"

echo "=== Installing Rust ==="
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
rustup default stable

echo "=== Installing Node.js and pnpm ==="
cd $HOME
if [ ! -d "node" ]; then
    wget https://nodejs.org/dist/v22.23.3/node-v22.23.3-linux-x64.tar.xz -O node.tar.xz
    tar xf node.tar.xz
    mv node-v22.23.3-linux-x64 node
fi
npm install -g pnpm
npm install -g @tauri-apps/cli

echo "=== Building libass ==="
cd $WORKSPACE/builder
if [ ! -d "libass" ]; then
    git clone https://github.com/libass/libass.git
    cd libass
    git checkout 0.17.5
    git submodule update --init --recursive
else
    cd libass
fi
./autogen.sh
./configure --prefix=$WORKSPACE/builder/mpv_install --disable-static --enable-asm --enable-harfbuzz --enable-fontconfig
make -j$(nproc)
make install

echo "=== Building libplacebo ==="
cd $WORKSPACE/builder
if [ ! -d "libplacebo" ]; then
    git clone https://github.com/haasn/libplacebo.git
    cd libplacebo
    git checkout v7.360.1
    git submodule update --init --recursive
else
    cd libplacebo
fi
export PKG_CONFIG_PATH="$WORKSPACE/builder/mpv_install/lib64/pkgconfig:$WORKSPACE/builder/mpv_install/lib/pkgconfig:$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="$WORKSPACE/builder/mpv_install/lib64:$WORKSPACE/builder/mpv_install/lib:$LD_LIBRARY_PATH"
rm -rf build
meson setup build -Dvulkan=enabled -Dshaderc=enabled --prefix=$WORKSPACE/builder/mpv_install
meson compile -C build
meson install -C build

echo "=== Building libmpv ==="
cd $WORKSPACE/builder
if [ ! -d "mpv" ]; then
    git clone https://github.com/mpv-player/mpv.git
    cd mpv
else
    cd mpv
fi
git fetch --tags
git reset --hard HEAD
git clean -fdx
git fetch origin master
git reset --hard FETCH_HEAD
git clean -fdx

# We build mpv without GUI, just the shared library.
# GNOME SDK provides wayland, x11, ffmpeg, vulkan, etc.
rm -rf build
meson setup build -Dlibmpv=true -Dcplayer=false -Dalsa=enabled -Dwayland=auto -Dx11=auto -Dvulkan=enabled --prefix=$WORKSPACE/builder/mpv_install
meson compile -C build
meson install -C build

echo "=== Building Limusic frontend ==="
cd $WORKSPACE/ui
rm -rf node_modules
pnpm install
pnpm run build

echo "=== Building Limusic Rust backend ==="
cd $WORKSPACE/src-tauri
# Add our custom compiled libmpv to the library path for linking
export PKG_CONFIG_PATH="$WORKSPACE/builder/mpv_install/lib64/pkgconfig:$WORKSPACE/builder/mpv_install/lib/pkgconfig:$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="$WORKSPACE/builder/mpv_install/lib64:$WORKSPACE/builder/mpv_install/lib:$LD_LIBRARY_PATH"
export RUSTFLAGS="-C target-cpu=znver2 -L native=$WORKSPACE/builder/mpv_install/lib64 -L native=$WORKSPACE/builder/mpv_install/lib"

tauri build --no-bundle

echo "=== Staging Files ==="
mkdir -p $WORKSPACE/flatpak-staging/bin
mkdir -p $WORKSPACE/flatpak-staging/lib
mkdir -p $WORKSPACE/flatpak-staging/share/applications
mkdir -p $WORKSPACE/flatpak-staging/share/icons/hicolor

# The output binary could be named limusic or limusic-app depending on Tauri version
if [ -f "$WORKSPACE/target/release/limusic" ]; then
    cp $WORKSPACE/target/release/limusic $WORKSPACE/flatpak-staging/bin/limusic
elif [ -f "$WORKSPACE/target/release/limusic-app" ]; then
    cp $WORKSPACE/target/release/limusic-app $WORKSPACE/flatpak-staging/bin/limusic
else
    echo "Could not find built binary!"
    exit 1
fi

# Copy all compiled libraries (mpv, ass, placebo)
cp -a $WORKSPACE/builder/mpv_install/lib64/*.so* $WORKSPACE/flatpak-staging/lib/ 2>/dev/null || true
cp -a $WORKSPACE/builder/mpv_install/lib/*.so* $WORKSPACE/flatpak-staging/lib/ 2>/dev/null || true

# Desktop file
cat <<EOF > $WORKSPACE/flatpak-staging/share/applications/com.limusic.desktop.desktop
[Desktop Entry]
Name=Limusic
Exec=limusic
Icon=com.limusic.desktop
Type=Application
Categories=AudioVideo;Music;
Terminal=false
StartupWMClass=limusic
EOF

# Icons
for size in 32 64 128; do
    mkdir -p $WORKSPACE/flatpak-staging/share/icons/hicolor/${size}x${size}/apps/
    cp $WORKSPACE/src-tauri/icons/${size}x${size}.png $WORKSPACE/flatpak-staging/share/icons/hicolor/${size}x${size}/apps/com.limusic.desktop.png || true
done
mkdir -p $WORKSPACE/flatpak-staging/share/icons/hicolor/256x256/apps/
cp $WORKSPACE/src-tauri/icons/128x128@2x.png $WORKSPACE/flatpak-staging/share/icons/hicolor/256x256/apps/com.limusic.desktop.png || true

echo "Done staging!"
