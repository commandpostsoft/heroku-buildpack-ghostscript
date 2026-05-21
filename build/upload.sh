#!/usr/bin/env bash
set -euo pipefail

# Upload Ghostscript binary to GitHub release (one asset per Heroku stack)
# Usage: ./upload.sh VERSION [STACK]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"

# GitHub repo (from origin remote)
GITHUB_REPO="${GITHUB_REPO:-$(git remote get-url origin 2>/dev/null | sed -E 's|.*github.com[:/]||' | sed 's/.git$//')}"

main() {
    local version="${1:-}"
    local stack="${2:-heroku-26}"

    if [[ -z "$version" || "$version" == "-h" || "$version" == "--help" ]]; then
        echo "Usage: $0 VERSION [STACK]"
        echo ""
        echo "Upload Ghostscript binary to GitHub release as a stack-specific asset"
        echo ""
        echo "Arguments:"
        echo "  VERSION    Ghostscript version (e.g., 10.07.1)"
        echo "  STACK      Heroku stack: heroku-22, heroku-24, heroku-26 (default: heroku-26)"
        echo ""
        echo "Environment:"
        echo "  GITHUB_REPO    Override GitHub repo (default: $GITHUB_REPO)"
        exit 1
    fi

    if ! command -v gh &>/dev/null; then
        echo "Error: GitHub CLI (gh) is required. Install with: brew install gh"
        exit 1
    fi

    local pkg_name="ghostscript-${version}-${stack}-linux-x86_64"
    local asset="$OUTPUT_DIR/${pkg_name}.tgz"
    local tag="v$version"

    if [[ ! -f "$asset" ]]; then
        echo "Error: Package not found: $asset"
        echo "Run ./build.sh $version $stack first"
        exit 1
    fi

    if [[ -z "$GITHUB_REPO" ]]; then
        echo "Error: Could not detect GitHub repo. Set GITHUB_REPO environment variable."
        exit 1
    fi

    echo "=========================================="
    echo "Version: $version"
    echo "Stack:   $stack"
    echo "Package: $asset"
    echo "GitHub:  $GITHUB_REPO"
    echo "=========================================="

    if gh release view "$tag" --repo "$GITHUB_REPO" &>/dev/null; then
        echo "Release $tag exists - uploading asset..."
        gh release upload "$tag" "$asset" --repo "$GITHUB_REPO" --clobber
    else
        echo "Creating GitHub release $tag..."
        gh release create "$tag" \
            --repo "$GITHUB_REPO" \
            --title "Ghostscript $version" \
            --notes "Precompiled Ghostscript $version for Linux x86_64 (Heroku compatible). Stack-specific binaries are attached as separate assets." \
            "$asset"
    fi

    local download_url="https://github.com/${GITHUB_REPO}/releases/download/${tag}/${pkg_name}.tgz"

    echo ""
    echo "=========================================="
    echo "Upload complete!"
    echo "Release: https://github.com/$GITHUB_REPO/releases/tag/$tag"
    echo "Asset:   $download_url"
    echo "=========================================="
}

main "$@"
