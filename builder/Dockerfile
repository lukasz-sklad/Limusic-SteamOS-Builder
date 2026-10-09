FROM docker.io/library/archlinux:latest

# Install dependencies
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    rustup \
    base-devel \
    git \
    nodejs \
    pnpm \
    webkit2gtk-4.1 \
    gtk3 \
    pango \
    cairo \
    gdk-pixbuf2 \
    libsoup3 \
    glib2 \
    base \
    wget \
    jq \
    mpv

# Setup Rust
RUN rustup default stable

# We will mount the source code here
CMD ["/bin/bash", "/home/deck/build.sh"]
