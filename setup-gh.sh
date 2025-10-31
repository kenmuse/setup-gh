#!/usr/bin/env bash
set -euo pipefail

# The main entry point for the script
# This script installs the GitHub CLI (gh) tool on a Linux system by 
# downloading a specific release.
# It takes two optional positional arguments:
#  1. TOOL_VERSION: The version of the GitHub CLI to install. If not provided, it installs the latest version.
#  2. TOOL_PATH: The directory where the tool will be installed. If not provided,
#     it defaults to value provided by the AGENT_TOOLSDIRECTORY or RUNNER_TOOL_CACHE
#     environment variables.
function main () {

  # Initial parameter configuration
  declare -r TOOL_VERSION=${1:-}
  declare -r TOOL_PATH=${2:-${AGENT_TOOLSDIRECTORY:-${RUNNER_TOOL_CACHE:-/tmp/gh}}}
  declare -r DOWNLOAD_PATH=${RUNNER_TEMP:-/tmp}


  # If the script is running on GitHub, allow debug logging
  # Otherwise, all output is logged
  if [ ! -z "${CI:-}" ]; then
    declare -r DEBUG_CMD=::debug::
    declare -r ERR_CMD=::error::
  else
    declare -r DEBUG_CMD=''
    declare -r ERR_CMD='ERROR: '
  fi

  # If the version is not specified, identify the latest version
  # from the GitHub releases
  if [ -z "${TOOL_VERSION}" ]; then
    echo "${DEBUG_CMD}No version specified"
    declare -r VERSION=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | grep '"tag_name":' | sed -E 's/[^:]+:\ \"v([^\"]+).+/\1/')
    echo "GH - latest version is v${VERSION}"
  else
    declare -r VERSION=${TOOL_VERSION}
  fi

  # Just in case it's already available in a global path
  # outside of the proper tools folder
  declare -r EXISTING_GH_PATH=$(which gh || echo "")
  if [ -n "${EXISTING_GH_PATH}" ]; then
    echo "${DEBUG_CMD}Found existing GitHub CLI installation at ${EXISTING_GH_PATH}"
    declare -r EXISTING_VERSION=$(${EXISTING_GH_PATH} --version | grep "gh version ${VERSION}")
    if [ -n "${EXISTING_VERSION}" ]; then
      echo "${DEBUG_CMD}Existing GitHub CLI installation matches requested version ${VERSION}"
      exit 0
    fi
  fi

  # Determine the architecture of the system. This assumes
  # only ARM64 and AMD64 are supported architectures.
  PROCESSOR_ARCHITECTURE=$(uname -m)
  if [ "${PROCESSOR_ARCHITECTURE}" == "arm64" ] || [ "${PROCESSOR_ARCHITECTURE}" == "aarch64" ]; then
    declare -r PLATFORM=arm64
  else
    declare -r PLATFORM=amd64
  fi
  
  # Build the complete installation path. This is where
  # the tool will be unpacked.
  declare -r INSTALL_PATH="${TOOL_PATH}/gh-cli/${VERSION}/${PLATFORM}"
  declare -r INSTALL_MARKER="${TOOL_PATH}/gh-cli/${VERSION}/${PLATFORM}.complete"

  # If the tool is not already installed, download and install it
  if [ ! -f "${INSTALL_MARKER}" ]; then
    echo "${DEBUG_CMD}Installing GH CLI v${VERSION}"
    declare -r BINARY_ARCHIVE="gh_${VERSION}_linux_${PLATFORM}.tar.gz"
    declare -r DOWNLOAD_URL="https://github.com/cli/cli/releases/download/v${VERSION}/${BINARY_ARCHIVE}"
    declare -r RELEASE_SHA=$(curl -SsL https://github.com/cli/cli/releases/download/v${VERSION}/gh_${VERSION}_checksums.txt)
    
    mkdir -p "${DOWNLOAD_PATH}"
    curl -sLfo "${DOWNLOAD_PATH}/${BINARY_ARCHIVE}" "${DOWNLOAD_URL}"

    pushd "${DOWNLOAD_PATH}" > /dev/null

    if command -v shasum >/dev/null; then
      if ! echo "${RELEASE_SHA}" | shasum -c --ignore-missing --status; then
        echo "${ERR_CMD}Checksum verification failed. Aborting installation." >&2
        exit 1
      fi
    else
      if command -v sha256sum >/dev/null; then
        if ! echo "${RELEASE_SHA}" | sha256sum -c --ignore-missing --status; then
          echo "${ERR_CMD}Checksum verification failed. Aborting installation." >&2
          exit 1
        fi
      else
        echo "${ERR_CMD}Could not verify checksum. Requires sha256sum or shasum command."
      fi
    fi

    popd >/dev/null
    echo "${DEBUG_CMD}Checksum verification passed"
        
    # Use attestation to verify the binary and its build provenance
    # However, this relies on having 'gh' already installed to perform the verification
    # to avoid simply trusting the results from the downloaded binary.
    if ! ${EXISTING_GH_PATH} at verify -R cli/cli "${DOWNLOAD_PATH}/${BINARY_ARCHIVE}"; then
      echo "${ERR_CMD}Attestation verification failed. Aborting installation." >&2
      exit 1
    fi

    mkdir -p "${INSTALL_PATH}"
    tar xzvf "${DOWNLOAD_PATH}/${BINARY_ARCHIVE}" -C "${INSTALL_PATH}"  --strip-components=1 > /dev/null

    rm "${DOWNLOAD_PATH}/${BINARY_ARCHIVE}"
    touch ${INSTALL_MARKER}
  else
    echo "${DEBUG_CMD}GH CLI v${VERSION} already installed"
  fi
  
  # If there is a GITHUB_PATH environment variable,
  # append the installation path to it. Otherwise add it to the PATH
  if [ ! -z "${GITHUB_PATH:-}" ]; then
    echo "${INSTALL_PATH}/bin" >> ${GITHUB_PATH:-/dev/null}
  else
    export PATH=${INSTALL_PATH}/bin:$PATH
  fi

  # If there is a GITHUB_OUTPUT environment variable,
  # write the installation path and version as step outputs.
  if [ ! -z "${GITHUB_OUTPUT:-}" ]; then
    echo "${DEBUG_CMD}Configuring output"
    echo "${DEBUG_CMD}  PATH=${INSTALL_PATH}/bin"
    echo "${DEBUG_CMD}  VERSION=$VERSION"
    echo "${DEBUG_CMD}  Writing to ${GITHUB_OUTPUT:-/dev/null}"
    
    echo "PATH=${INSTALL_PATH}/bin" >> ${GITHUB_OUTPUT:-/dev/null}
    echo "VERSION=$VERSION" >> ${GITHUB_OUTPUT:-/dev/null}
  fi

  # If there is a GITHUB_ENV environment variable,
  # create a GH_VERSION variable with the version. Otherwise,
  # export the version as an environment variable.
  if [ ! -z "${GITHUB_ENV:-}" ]; then
    echo "GH_VERSION=$VERSION" >> ${GITHUB_ENV:-/dev/null}
  else
    export GH_VERSION=$VERSION
  fi
}

# Call the main function with all arguments passed to the script
main "$@"
