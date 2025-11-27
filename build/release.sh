#!/usr/bin/env bash
set -euo pipefail

# Release Ghostscript - all-in-one script
# Checks if release exists, builds if needed, updates bin/compile
# Usage: ./release.sh [VERSION]

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

# Check if release exists
release_exists() {
    local version="$1"
    local tag="v$version"
    gh release view "$tag" --repo "$GITHUB_REPO" &>/dev/null
}

main() {
    local version="${1:-latest}"

    if [[ "$version" == "-h" || "$version" == "--help" ]]; then
        echo "Usage: $0 [VERSION]"
        echo ""
        echo "Build/release Ghostscript for Heroku"
        echo ""
        echo "Arguments:"
        echo "  VERSION    Ghostscript version (e.g., 10.06.0) or 'latest' (default)"
        echo ""
        echo "If a release already exists, just updates bin/compile."
        echo "If not, builds from source, uploads, then updates."
        exit 0
    fi

    # Check dependencies
    if ! command -v gh &>/dev/null; then
        echo "Error: GitHub CLI (gh) is required. Install with: brew install gh"
        exit 1
    fi

    # Get version
    if [[ "$version" == "latest" ]]; then
        echo "Fetching latest Ghostscript version..."
        version=$(get_latest_version)
    fi

    echo "=========================================="
    echo "Ghostscript Version: $version"
    echo "GitHub Repo: $GITHUB_REPO"
    echo "=========================================="
    echo ""

    # Check if release exists
    if release_exists "$version"; then
        echo "Release v$version already exists - using existing binary"
        echo ""
        "$SCRIPT_DIR/update.sh" "$version"
    else
        echo "Release v$version not found - building from source"
        echo ""

        if ! command -v docker &>/dev/null; then
            echo "Error: Docker is required for building. Install Docker Desktop."
            exit 1
        fi

        "$SCRIPT_DIR/build.sh" "$version"
        "$SCRIPT_DIR/upload.sh" "$version"
        "$SCRIPT_DIR/update.sh" "$version"
    fi

    echo ""
    echo "Done! Don't forget to commit and push your changes."
}

main "$@"
