#!/usr/bin/env bash
set -euo pipefail

# Update bin/compile to pin a Ghostscript version (stack is resolved at install time)
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
        echo "Pin bin/compile to a specific Ghostscript version. The compile script"
        echo "resolves the Heroku stack at install time and downloads the matching"
        echo "asset from the v\$VERSION GitHub release."
        echo ""
        echo "Arguments:"
        echo "  VERSION    Ghostscript version (e.g., 10.07.1)"
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
    local base_url="https://github.com/${GITHUB_REPO}/releases/download/${tag}"

    echo "Updating bin/compile..."

    local compile_script="$REPO_ROOT/bin/compile"

    cat > "$compile_script" <<EOF
#!/usr/bin/env bash
# bin/compile <build-dir> <cache-dir> <env-dir>
set -euo pipefail

VERSION="$version"
STACK="\${STACK:-heroku-26}"

BUILD_DIR="\$1"
PKG_NAME="ghostscript-\${VERSION}-\${STACK}-linux-x86_64"
PACKAGE="${base_url}/\${PKG_NAME}.tgz"
LOCATION="\$BUILD_DIR/vendor/gs/bin"

echo "-----> Installing Ghostscript \$VERSION (\$STACK)"

mkdir -p "\$LOCATION"
if ! curl --fail -L -s "\$PACKAGE" | tar xzf - -C "\$LOCATION"; then
    echo " !     No Ghostscript \$VERSION binary available for stack: \$STACK"
    echo " !     Tried: \$PACKAGE"
    echo " !     See https://github.com/${GITHUB_REPO}/releases/tag/${tag} for available stacks."
    exit 1
fi

mv "\$LOCATION/\$PKG_NAME/gs" "\$LOCATION/gs"
rmdir "\$LOCATION/\$PKG_NAME"

echo "-----> Building runtime environment for Ghostscript"
mkdir -p "\$BUILD_DIR/.profile.d"
echo "export PATH=\"\\\$HOME/vendor/gs/bin:\\\$PATH\"" > "\$BUILD_DIR/.profile.d/ghostscript.sh"
EOF

    chmod +x "$compile_script"

    echo ""
    echo "=========================================="
    echo "bin/compile updated!"
    echo "Version:  $version"
    echo "Base URL: $base_url"
    echo "=========================================="
}

main "$@"
