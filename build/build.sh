#!/usr/bin/env bash
set -euo pipefail

# Build Ghostscript for Linux x86_64
# Usage: ./build.sh [VERSION]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/workspace"
OUTPUT_DIR="$SCRIPT_DIR/output"

# Get latest Ghostscript version from GitHub releases
get_latest_version() {
    curl -s "https://api.github.com/repos/ArtifexSoftware/ghostpdl-downloads/releases" | \
        grep '"tag_name"' | \
        grep -v 'rc[0-9]' | \
        head -1 | \
        sed -E 's/.*"gs([0-9]+)".*/\1/' | \
        sed -E 's/([0-9]{1,2})([0-9]{2})([0-9]{1,2})?/\1.\2.\3/' | \
        sed 's/\.$/\.0/'
}

# Convert version to tag format (10.06.0 -> gs10060)
version_to_tag() {
    local version="$1"
    echo "gs$(echo "$version" | tr -d '.')"
}

# Download Ghostscript source
download_source() {
    local version="$1"
    local gs_tag=$(version_to_tag "$version")
    local url="https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/${gs_tag}/ghostscript-${version}.tar.gz"

    echo "Downloading Ghostscript $version source..."
    mkdir -p "$BUILD_DIR"
    curl -L -o "$BUILD_DIR/ghostscript-${version}.tar.gz" "$url"

    echo "Extracting..."
    cd "$BUILD_DIR"
    tar xzf "ghostscript-${version}.tar.gz"
}

# Build using Docker (for Linux x86_64 binary)
build_with_docker() {
    local version="$1"

    echo "Building Ghostscript $version with Docker (linux/amd64)..."

    cat > "$BUILD_DIR/Dockerfile" <<'DOCKERFILE'
FROM --platform=linux/amd64 ubuntu:22.04

RUN apt-get update && apt-get install -y \
    build-essential \
    autoconf \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
DOCKERFILE

    docker build \
        --platform linux/amd64 \
        -t "ghostscript-builder:$version" \
        "$BUILD_DIR"

    docker run --rm \
        --platform linux/amd64 \
        -v "$BUILD_DIR:/build" \
        -v "$OUTPUT_DIR:/output" \
        "ghostscript-builder:$version" \
        bash -c "cd /build/ghostscript-${version} && \
                 ./configure --disable-cups --disable-gtk --with-drivers=FILES && \
                 make -j\$(nproc) && \
                 strip bin/gs && \
                 cp bin/gs /output/gs"

    echo "Binary built: $OUTPUT_DIR/gs"
}

# Package the binary
package_binary() {
    local version="$1"
    local pkg_name="ghostscript-${version}-linux-x86_64"
    local pkg_dir="$OUTPUT_DIR/$pkg_name"

    echo "Packaging binary..."
    mkdir -p "$pkg_dir"
    cp "$OUTPUT_DIR/gs" "$pkg_dir/"

    cd "$OUTPUT_DIR"
    tar czf "${pkg_name}.tgz" "$pkg_name"

    echo ""
    echo "=========================================="
    echo "Build complete!"
    echo "Package: $OUTPUT_DIR/${pkg_name}.tgz"
    echo "=========================================="
}

# Cleanup
cleanup() {
    echo "Cleaning up workspace..."
    rm -rf "$BUILD_DIR"
}

# Main
main() {
    local version="${1:-latest}"

    if [[ "$version" == "-h" || "$version" == "--help" ]]; then
        echo "Usage: $0 [VERSION]"
        echo ""
        echo "Build Ghostscript for Linux x86_64"
        echo ""
        echo "Arguments:"
        echo "  VERSION    Ghostscript version (e.g., 10.06.0) or 'latest'"
        exit 0
    fi

    if ! command -v docker &>/dev/null; then
        echo "Error: Docker is required for building Linux binaries."
        exit 1
    fi

    if [[ "$version" == "latest" ]]; then
        echo "Fetching latest Ghostscript version..."
        version=$(get_latest_version)
    fi

    echo "Building Ghostscript $version..."

    mkdir -p "$OUTPUT_DIR"
    trap cleanup EXIT

    download_source "$version"
    build_with_docker "$version"
    package_binary "$version"
}

main "$@"
