# Setup GH CLI

The `setup-gh` Action configures the GitHub CLI as a GitHub tool using Bash scripts.

## Usage

The following parameters are supported:

- `version` - The version of the GH CLI to set up. Can specify `latest` or an exact version. **Default:** `latest`.

It returns the following outputs:

- `path` - The path to directory containing the GH CLI binary.
- `version` - The version of the CLI that was configured

The Action also publishes an environment variable, `GH_VERSION` that contains the tool version.


### Basic Configuration

#### Typical setup

```yaml
- uses: kenmuse/setup-gh@v1
```

or

```yaml
- uses: kenmuse/setup-gh@v1
  with:
    version: 2.72.0
```

## Tool path

The CLI is installed in the path `${RUNNER_TOOL_CACHE}/gh-cli/${VERSION}/${PLATFORM}`

