#!/usr/bin/env bash
set -euo pipefail

# Update bin/compile to use a specific Ghostscript version
# Usage: ./update.sh VERSION

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# GitHub repo (from origin remote)
GITHUB_REPO="${GITHUB_REPO:-$(git remote get-url origin 2>/dev/null | sed -E 's|.*github.com[:/]||' | sed 's/.git$//')}"

main() {
    local version="${1:-}"

    if [[ -z "$version" || "$version" == "-h" || "$version" == "--help" ]]; then
        echo "Usage: $0 VERSION"
        echo ""
        echo "Update bin/compile to use a specific Ghostscript version"
        echo ""
        echo "Arguments:"
        echo "  VERSION    Ghostscript version (e.g., 10.06.0)"
        echo ""
        echo "Environment:"
        echo "  GITHUB_REPO    Override GitHub repo (default: $GITHUB_REPO)"
        exit 1
    fi

    if [[ -z "$GITHUB_REPO" ]]; then
        echo "Error: Could not detect GitHub repo. Set GITHUB_REPO environment variable."
        exit 1
    fi

    local tag="v$version"
    local pkg_name="ghostscript-${version}-linux-x86_64"

    # Get download URL from release
    echo "Fetching release info for $tag..."

    if ! gh release view "$tag" --repo "$GITHUB_REPO" &>/dev/null; then
        echo "Error: Release $tag not found in $GITHUB_REPO"
        echo "Run ./upload.sh $version first"
        exit 1
    fi

    local url=$(gh release view "$tag" --repo "$GITHUB_REPO" --json assets -q '.assets[0].url')

    if [[ -z "$url" ]]; then
        echo "Error: Could not get download URL for release $tag"
        exit 1
    fi

    echo "Updating bin/compile..."

    local compile_script="$REPO_ROOT/bin/compile"

    cat > "$compile_script" <<EOF
#!/usr/bin/env bash
# bin/compile <build-dir> <cache-dir>

echo "-----> Installing Ghostscript $version"

BUILD_DIR=\$1
PACKAGE="$url"
BINARY="$pkg_name/gs"
LOCATION="\$BUILD_DIR/vendor/gs/bin"

mkdir -p \$LOCATION
curl \$PACKAGE -L -s -o - | tar xzf - -C \$LOCATION
mv \$LOCATION/\$BINARY \$LOCATION/gs

echo "-----> Building runtime environment for Ghostscript"

mkdir -p \$BUILD_DIR/.profile.d
echo "export PATH=\"\\\$HOME/vendor/gs/bin:\\\$PATH\"" > \$BUILD_DIR/.profile.d/ghostscript.sh
EOF

    chmod +x "$compile_script"

    echo ""
    echo "=========================================="
    echo "bin/compile updated!"
    echo "Version: $version"
    echo "URL: $url"
    echo "=========================================="
}

main "$@"
