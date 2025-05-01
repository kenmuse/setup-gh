#!/usr/bin/env bash
set -euo pipefail

function main () {
  declare -r TOOL_VERSION=${1:-}
  declare -r TOOL_PATH=${2:-${AGENT_TOOLSDIRECTORY:-${RUNNER_TOOL_CACHE:-/tmp/gh}}}
  declare -r DOWNLOAD_PATH=${RUNNER_TEMP:-/tmp}
  
  if [ -z "${GITHUB_ENV:-}" ]; then
    declare -r DEBUG_CMD=::debug::
  else
    declare -r DEBUG_CMD
  fi

  if [ -z "${TOOL_VERSION}" ]; then
    echo "${DEBUG_CMD}No version specified"
    declare -r VERSION=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | grep '"tag_name":' | sed -E 's/[^:]+:\ \"v([^\"]+).+/\1/')
    echo "Installing GH Latest (${VERSION})"
  else
    declare -r VERSION=${TOOL_VERSION}
    echo "${DEBUG_CMD}Installing GH ${VERSION}"
  fi

  PROCESSOR_ARCHITECTURE=$(uname -m)
  if [ "${PROCESSOR_ARCHITECTURE}" == "arm64" ] || [ "${PROCESSOR_ARCHITECTURE}" == "aarch64" ]; then
    declare -r PLATFORM=arm64
  else
    declare -r PLATFORM=amd64
  fi
  
  declare -r INSTALL_PATH="${TOOL_PATH}/gh-cli/${VERSION}/${PLATFORM}"
  
  echo "TOOL PAth: ${TOOL_PATH}"
  echo "DOWNLOAD PAth: ${DOWNLOAD_PATH}"
  echo ARC
  
  if [ ! -f "${INSTALL_PATH}/bin/gh" ]; then
    echo "${DEBUG_CMD}Installing GH CLI ${VERSION}"
    declare -r DOWNLOAD_URL="https://github.com/cli/cli/releases/download/v${VERSION}/gh_${VERSION}_linux_${PLATFORM}.tar.gz"
    declare -r BINARY_ARCHIVE="cli.tar.gz"
    
    curl -sLfo "${DOWNLOAD_PATH}/${BINARY_ARCHIVE}" "${DOWNLOAD_URL}"
    mkdir -p "${INSTALL_PATH}"
    tar xzvf "${DOWNLOAD_PATH}/${BINARY_ARCHIVE}" -C "${INSTALL_PATH}"  --strip-components=1 > /dev/null
    rm "${DOWNLOAD_PATH}/${BINARY_ARCHIVE}"
  fi
  
  if [ -z "${GITHUB_PATH:-}" ]; then
    echo "${INSTALL_PATH}/bin" >> ${GITHUB_PATH:-/dev/null}
  else
    export PATH=${INSTALL_PATH}/bin:$PATH
  fi
  if [ -z "${GITHUB_OUTPUT:-}" ]; then
    echo "path=${INSTALL_PATH}/bin" >> ${GITHUB_OUTPUT:-/dev/null}
    echo "version=$VERSION" >> ${GITHUB_OUTPUT:-/dev/null}
  fi
  if [ -z "${GITHUB_ENV:-}" ]; then
    echo "GH_VERSION=$VERSION"
  else
    export GH_VERSION=$VERSION
  fi
}

main "$@"