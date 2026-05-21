#!/usr/bin/env bash
set -euo pipefail

# Build Ghostscript for a specific Heroku stack (Linux x86_64)
# Usage: ./build.sh VERSION [STACK]

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

# Map a Heroku stack to its Ubuntu base image
stack_to_ubuntu() {
    case "$1" in
        heroku-22) echo "ubuntu:22.04" ;;
        heroku-24) echo "ubuntu:24.04" ;;
        heroku-26) echo "ubuntu:26.04" ;;
        *) echo "" ;;
    esac
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
    local stack="$2"
    local ubuntu_image="$3"

    echo "Building Ghostscript $version for $stack ($ubuntu_image)..."

    cat > "$BUILD_DIR/Dockerfile" <<DOCKERFILE
FROM --platform=linux/amd64 ${ubuntu_image}

RUN apt-get update && apt-get install -y \\
    build-essential \\
    autoconf \\
    curl \\
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
DOCKERFILE

    docker build \
        --platform linux/amd64 \
        -t "ghostscript-builder:${version}-${stack}" \
        "$BUILD_DIR"

    docker run --rm \
        --platform linux/amd64 \
        -v "$BUILD_DIR:/build" \
        -v "$OUTPUT_DIR:/output" \
        "ghostscript-builder:${version}-${stack}" \
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
    local stack="$2"
    local pkg_name="ghostscript-${version}-${stack}-linux-x86_64"
    local pkg_dir="$OUTPUT_DIR/$pkg_name"

    echo "Packaging binary..."
    rm -rf "$pkg_dir"
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
    local stack="${2:-heroku-26}"

    if [[ "$version" == "-h" || "$version" == "--help" ]]; then
        echo "Usage: $0 VERSION [STACK]"
        echo ""
        echo "Build Ghostscript for a specific Heroku stack (Linux x86_64)"
        echo ""
        echo "Arguments:"
        echo "  VERSION    Ghostscript version (e.g., 10.07.1) or 'latest'"
        echo "  STACK      Heroku stack: heroku-22, heroku-24, heroku-26 (default: heroku-26)"
        exit 0
    fi

    if ! command -v docker &>/dev/null; then
        echo "Error: Docker is required for building Linux binaries."
        exit 1
    fi

    local ubuntu_image=$(stack_to_ubuntu "$stack")
    if [[ -z "$ubuntu_image" ]]; then
        echo "Error: Unknown stack '$stack'. Supported: heroku-22, heroku-24, heroku-26"
        exit 1
    fi

    if [[ "$version" == "latest" ]]; then
        echo "Fetching latest Ghostscript version..."
        version=$(get_latest_version)
    fi

    echo "Building Ghostscript $version for $stack..."

    mkdir -p "$OUTPUT_DIR"
    trap cleanup EXIT

    download_source "$version"
    build_with_docker "$version" "$stack" "$ubuntu_image"
    package_binary "$version" "$stack"
}

main "$@"
