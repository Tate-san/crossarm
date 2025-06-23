#!/usr/bin/env bash
set -euo pipefail

### Constants & Defaults ###
readonly IMAGE_BASE="crossarm"
readonly SCRIPT_BASE="crossarm"
readonly DEFAULT_ARCH="arm"
readonly CROSS_SCRIPT_DIR="/usr/bin"

HOST_UID="${SUDO_UID:-$(id -u)}"
HOST_GID="${SUDO_GID:-$(id -g)}"

### Logging helpers ###
pmsg()    { printf "[ %s ] %s\n" "$1" "$2"; }
perror()  { pmsg "ERROR" "$1"; }
psuccess(){ pmsg "OK" "$1"; }
pwarning(){ pmsg "WARN" "$1"; }

### Usage ###
print_help() {
  cat <<EOF
Usage: ${0##*/} [options]

Options:
  -h            Show this help and exit
  -n            Build Docker image without cache
  -u            Uninstall the script and image
  -p            Purge sysroot volume (must be used with -u)
  -a ARCH       Set architecture (arm|aarch64). Default: ${DEFAULT_ARCH}
  -s NAME       Custom script suffix (e.g. "myname" for crossarm-myname)
EOF
}

### Set TOOLCHAIN_URL based on ARCH ###
set_arch() {
  case "$1" in
    arm)
      TOOLCHAIN_URL="https://releases.linaro.org/components/toolchain/binaries/7.2-2017.11/arm-linux-gnueabihf/gcc-linaro-7.2.1-2017.11-x86_64_arm-linux-gnueabihf.tar.xz"
      ;;
    aarch64)
      TOOLCHAIN_URL="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/10.3-2021.07/binrel/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.xz"
      ;;
    *)
      perror "Unknown architecture '$1'. Supported: arm, aarch64"
      exit 1
      ;;
  esac

  CROSS_ARCH="$1"
  IMAGE_NAME="${IMAGE_BASE}-${CROSS_ARCH}"
  SCRIPT_NAME="${SCRIPT_BASE}-${CROSS_ARCH}"
  CROSS_SHARED_VOLUME="/opt/${IMAGE_NAME}"
  CROSS_SYSROOT="/crossarm"
}

### Parse flags ###
NO_CACHE=0
UNINSTALL=0
PURGE=0
CROSS_ARCH="$DEFAULT_ARCH"
CUSTOM_NAME=""

while getopts "hnups:a:" opt; do
  case "$opt" in
    h) print_help; exit 0          ;;
    n) NO_CACHE=1                  ;;
    u) UNINSTALL=1                 ;;
    p) PURGE=1                     ;;
    a) set_arch "$OPTARG"        ;;
    s) CUSTOM_NAME="$OPTARG"     ;;
    *) print_help; exit 1          ;;
  esac
done
shift $((OPTIND-1))

if [[ -z "${TOOLCHAIN_URL:-}" ]]; then
  pwarning "No architecture specified; defaulting to '${DEFAULT_ARCH}'"
  set_arch "${DEFAULT_ARCH}"
fi

if [[ -n "$CUSTOM_NAME" ]]; then
  SCRIPT_NAME="${SCRIPT_BASE}-${CUSTOM_NAME}"
  CROSS_SHARED_VOLUME="/opt/${SCRIPT_NAME}"
fi

if [[ "$EUID" -ne 0 ]]; then
  perror "This must be run as root"
  exit 1
fi

### Uninstall ###
if (( UNINSTALL )); then
  psuccess "Removing script: ${CROSS_SCRIPT_DIR}/${SCRIPT_NAME}"
  rm -f "${CROSS_SCRIPT_DIR}/${SCRIPT_NAME}"
  psuccess "Removing Docker image: ${IMAGE_NAME}"
  docker rmi -f "${IMAGE_NAME}" || true

  if (( PURGE )); then
    psuccess "Purging shared volume: ${CROSS_SHARED_VOLUME}"
    rm -rf "${CROSS_SHARED_VOLUME}"
  fi

  psuccess "Uninstallation complete."
  exit 0
fi

### Build Docker image ###
BUILD_ARGS=()
(( NO_CACHE )) && BUILD_ARGS+=(--no-cache)
BUILD_ARGS+=(
  -t "${IMAGE_NAME}"
  --build-arg "HOST_UID=${HOST_UID}"
  --build-arg "HOST_GID=${HOST_GID}"
  --build-arg "TOOLCHAIN_URL=${TOOLCHAIN_URL}"
  --build-arg "CROSS_SYSROOT_DIR=${CROSS_SYSROOT}"
  .
)

psuccess "Building Docker image ${IMAGE_NAME}"
docker build "${BUILD_ARGS[@]}"

### Prepare shared volume ###
mkdir -p "${CROSS_SHARED_VOLUME}"
chown -R "${HOST_UID}:${HOST_GID}" "${CROSS_SHARED_VOLUME}"

### Generate launcher script ###
LAUNCHER_PATH="${SCRIPT_NAME}.sh"
cat > "${LAUNCHER_PATH}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

# Defaults
SRC_DIR="\$(pwd)"
CMD=""

print_help() {
  cat <<EOH
Usage: \${0##*/} [path] [-c command]

Arguments:
  path        Directory to mount into /project
  -c CMD      Execute CMD inside the container
EOH
}

# Parse args
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -h|--help) print_help; exit 0 ;;
    -c) shift; CMD="\$1"; shift ;;
    *) SRC_DIR="\$1"; shift ;;
  esac
done

# Resolve to absolute path
[[ "\${SRC_DIR}" != /* ]] && SRC_DIR="\$(pwd)/\${SRC_DIR}"

# Base docker command
DOCKER_CMD=(
  docker run --rm -it
  -v "\${SRC_DIR}:/project"
  -v "${CROSS_SHARED_VOLUME}:${CROSS_SYSROOT}"
  "${IMAGE_NAME}"
)

# Execute
if [[ -n "\$CMD" ]]; then
  "\${DOCKER_CMD[@]}" "\$CMD"
else
  "\${DOCKER_CMD[@]}"
fi
EOF

chmod +x "${LAUNCHER_PATH}"
psuccess "Installing launcher to ${CROSS_SCRIPT_DIR}/${SCRIPT_NAME}"
mv "${LAUNCHER_PATH}" "${CROSS_SCRIPT_DIR}/${SCRIPT_NAME}"

psuccess "Setup complete! Run '${SCRIPT_NAME}' to enter the cross-compile environment."