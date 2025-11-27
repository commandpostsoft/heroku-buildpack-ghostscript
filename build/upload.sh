#!/usr/bin/env bash
set -euo pipefail

# Upload Ghostscript binary to GitHub release
# Usage: ./upload.sh VERSION

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"

# GitHub repo (from origin remote)
GITHUB_REPO="${GITHUB_REPO:-$(git remote get-url origin 2>/dev/null | sed -E 's|.*github.com[:/]||' | sed 's/.git$//')}"

main() {
    local version="${1:-}"

    if [[ -z "$version" || "$version" == "-h" || "$version" == "--help" ]]; then
        echo "Usage: $0 VERSION"
        echo ""
        echo "Upload Ghostscript binary to GitHub release"
        echo ""
        echo "Arguments:"
        echo "  VERSION    Ghostscript version (e.g., 10.06.0)"
        echo ""
        echo "Environment:"
        echo "  GITHUB_REPO    Override GitHub repo (default: $GITHUB_REPO)"
        exit 1
    fi

    if ! command -v gh &>/dev/null; then
        echo "Error: GitHub CLI (gh) is required. Install with: brew install gh"
        exit 1
    fi

    local pkg_name="ghostscript-${version}-linux-x86_64"
    local asset="$OUTPUT_DIR/${pkg_name}.tgz"
    local tag="v$version"

    if [[ ! -f "$asset" ]]; then
        echo "Error: Package not found: $asset"
        echo "Run ./build.sh $version first"
        exit 1
    fi

    if [[ -z "$GITHUB_REPO" ]]; then
        echo "Error: Could not detect GitHub repo. Set GITHUB_REPO environment variable."
        exit 1
    fi

    echo "=========================================="
    echo "Version: $version"
    echo "Package: $asset"
    echo "GitHub Repo: $GITHUB_REPO"
    echo "=========================================="

    # Check if release already exists
    if gh release view "$tag" --repo "$GITHUB_REPO" &>/dev/null; then
        echo "Release $tag already exists. Skipping upload."
        echo ""
        echo "Download URL:"
        gh release view "$tag" --repo "$GITHUB_REPO" --json assets -q '.assets[0].url'
        exit 0
    fi

    echo "Creating GitHub release $tag..."
    gh release create "$tag" \
        --repo "$GITHUB_REPO" \
        --title "Ghostscript $version" \
        --notes "Precompiled Ghostscript $version for Linux x86_64 (Heroku compatible)" \
        "$asset"

    echo ""
    echo "=========================================="
    echo "Upload complete!"
    echo "Release: https://github.com/$GITHUB_REPO/releases/tag/$tag"
    echo ""
    echo "Download URL:"
    gh release view "$tag" --repo "$GITHUB_REPO" --json assets -q '.assets[0].url'
    echo "=========================================="
}

main "$@"
