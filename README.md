# Heroku Buildpack for Ghostscript

Installs Ghostscript on Heroku. Currently using **Ghostscript 10.06.0**.

## Install

Add this buildpack to your Heroku app:

```bash
heroku buildpacks:add https://github.com/commandpostsoft/heroku-buildpack-ghostscript.git
```

Or with multiple buildpacks, create a `.buildpacks` file:

```
https://github.com/heroku/heroku-buildpack-ruby.git
https://github.com/commandpostsoft/heroku-buildpack-ghostscript.git
```

## Updating Ghostscript Version

### Quick Start

```bash
./build/release.sh           # Update to latest version
./build/release.sh 10.06.0   # Update to specific version
```

This script automatically:
- Checks if a precompiled release already exists
- If yes: updates `bin/compile` to use it (fast)
- If no: builds from source, uploads release, then updates (slower, requires Docker)

### Requirements

- GitHub CLI (`gh`) - `brew install gh`
- Docker (only needed if building a new version)

### Individual Scripts

For more control, you can run the steps separately:

| Script | Purpose |
|--------|---------|
| `build/build.sh VERSION` | Compile Ghostscript from source |
| `build/upload.sh VERSION` | Upload binary to GitHub release |
| `build/update.sh VERSION` | Update bin/compile with release URL |
