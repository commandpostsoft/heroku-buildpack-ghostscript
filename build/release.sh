#!/usr/bin/env bash
set -euo pipefail

# Release Ghostscript for a Heroku stack - all-in-one
# Checks if the stack-specific asset exists; builds + uploads if not; pins bin/compile
# Usage: ./release.sh [VERSION] [STACK]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# GitHub repo (from origin remote)
GITHUB_REPO="${GITHUB_REPO:-$(git remote get-url origin 2>/dev/null | sed -E 's|.*github.com[:/]||' | sed 's/.git$//')}"

# Get latest Ghostscript version
get_latest_version() {
    curl -s "https://api.github.com/repos/ArtifexSoftware/ghostpdl-downloads/releases" | \
        grep '"tag_name"' | \
        grep -v 'rc[0-9]' | \
        head -1 | \
        sed -E 's/.*"gs([0-9]+)".*/\1/' | \
        sed -E 's/([0-9]{1,2})([0-9]{2})([0-9]{1,2})?/\1.\2.\3/' | \
        sed 's/\.$/\.0/'
}

# Check if a stack-specific asset exists on the release
asset_exists() {
    local version="$1"
    local stack="$2"
    local tag="v$version"
    local pkg_name="ghostscript-${version}-${stack}-linux-x86_64.tgz"

    gh release view "$tag" --repo "$GITHUB_REPO" --json assets \
        -q ".assets[] | select(.name == \"$pkg_name\") | .name" 2>/dev/null | \
        grep -q "$pkg_name"
}

main() {
    local version="${1:-latest}"
    local stack="${2:-heroku-26}"

    if [[ "$version" == "-h" || "$version" == "--help" ]]; then
        echo "Usage: $0 [VERSION] [STACK]"
        echo ""
        echo "Build/release Ghostscript for a Heroku stack"
        echo ""
        echo "Arguments:"
        echo "  VERSION    Ghostscript version (e.g., 10.07.1) or 'latest' (default)"
        echo "  STACK      Heroku stack: heroku-22, heroku-24, heroku-26 (default: heroku-26)"
        echo ""
        echo "If the stack-specific asset already exists on the v\$VERSION release,"
        echo "the build step is skipped and bin/compile is just re-pinned."
        exit 0
    fi

    if ! command -v gh &>/dev/null; then
        echo "Error: GitHub CLI (gh) is required. Install with: brew install gh"
        exit 1
    fi

    if [[ "$version" == "latest" ]]; then
        echo "Fetching latest Ghostscript version..."
        version=$(get_latest_version)
    fi

    echo "=========================================="
    echo "Ghostscript Version: $version"
    echo "Heroku Stack:        $stack"
    echo "GitHub Repo:         $GITHUB_REPO"
    echo "=========================================="
    echo ""

    if asset_exists "$version" "$stack"; then
        echo "Asset for $stack already exists on v$version - skipping build"
        echo ""
    else
        echo "Asset for $stack not found on v$version - building from source"
        echo ""

        if ! command -v docker &>/dev/null; then
            echo "Error: Docker is required for building. Install Docker Desktop."
            exit 1
        fi

        "$SCRIPT_DIR/build.sh" "$version" "$stack"
        "$SCRIPT_DIR/upload.sh" "$version" "$stack"
    fi

    "$SCRIPT_DIR/update.sh" "$version"

    echo ""
    echo "Done! Don't forget to commit and push your changes."
}

main "$@"
