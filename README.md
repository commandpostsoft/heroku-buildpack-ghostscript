# Heroku Buildpack for Ghostscript

Installs Ghostscript on Heroku. Currently pinned to **Ghostscript 10.07.1**.

Stack-specific binaries are published as separate assets on each release. The
compile script reads `$STACK` at install time and downloads the matching
package, so the same buildpack works across `heroku-22`, `heroku-24`, and
`heroku-26` (provided a binary has been built and uploaded for that stack).

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
./build/release.sh                       # Latest version, heroku-26
./build/release.sh 10.07.1               # Specific version, heroku-26
./build/release.sh 10.07.1 heroku-24     # Specific version, specific stack
./build/release.sh latest heroku-22      # Latest version, specific stack
```

This script automatically:
- Checks if the stack-specific asset already exists on the release
- If yes: re-pins `bin/compile` (fast)
- If no: builds from source on the matching Ubuntu image, uploads the asset
  to the v$VERSION release, then re-pins `bin/compile`

To support a new stack on an existing release, just run `release.sh` again
with a different `STACK` argument — it appends a new asset.

### Requirements

- GitHub CLI (`gh`) — `brew install gh`
- Docker (only needed if building a new binary)

### Stack → Ubuntu mapping

| Heroku Stack | Ubuntu Image |
|--------------|--------------|
| heroku-22    | ubuntu:22.04 |
| heroku-24    | ubuntu:24.04 |
| heroku-26    | ubuntu:26.04 |

### Individual Scripts

For more control, you can run the steps separately:

| Script | Purpose |
|--------|---------|
| `build/build.sh VERSION [STACK]`  | Compile Ghostscript from source for one stack |
| `build/upload.sh VERSION [STACK]` | Upload that binary as a release asset |
| `build/update.sh VERSION`         | Re-pin bin/compile to a version |
