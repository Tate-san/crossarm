ARGS=""
IMAGE_NAME="crossarm"
CROSS_SCRIPT_NAME="crossarm"
DEFAULT_ARCH="arm"
CROSS_ARCH=$DEFAULT_ARCH
CROSS_SCRIPT_PATH="/usr/bin"

pmsg(){
  printf "[%s] %s\n" "$1" "$2"
}

perror(){
  pmsg "-" "$1"
}

psuccess(){
  pmsg "+" "$1"
}

pwarning(){
  pmsg "*" "$1"
}

if [ "$EUID" -ne 0 ]
  then perror "Please run as root"
  exit
fi

function print_help {
	function print_arg {
		printf "   %-35s - %s\n" "$1 | $2" "$3"
	}
	printf "%s <ARGS>\n\n" $0
	printf " Arguments:\n"
	print_arg "-h" "--help" "Prints this help"
	print_arg "-n" "--no-cache" "Build docker image without caching"
	print_arg "-u" "--uninstall" "Uninstall script"
	print_arg "-p" "--purge" "Remove chroot (has to be combined with uninstall, otherwise wont work)"
	print_arg "-a" "--architecture <ARCHITECTURE>" "Build crosscompiling image for architecture. Available archs: arm, aarch64 (default: $DEFAULT_ARCH)"
}

#$1 - arch name
function set_arch {
	case "$1" in
		"arm" )
			TOOLCHAIN_URL="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-x86_64-arm-none-linux-gnueabihf.tar.xz"
			break ;;
		"aarch64" )  
			TOOLCHAIN_URL="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/10.3-2021.07/binrel/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.xz"
			break ;;
		* ) perror "Unknown architecture, available: arm, aarch64"; exit
	esac
	CROSS_ARCH=$1
}

set_arch $CROSS_ARCH 

while true; do
  case "$1" in
		-h | --help ) print_help; exit;;
    -n | --no-cache ) ARGS+="--no-cache "; shift ;;
		-u | --uninstall ) UNINSTALL=1; shift ;;
		-p | --purge ) PURGE=1; shift ;;
		-a | --architecture )
			ARCHITECTURE_SET=1
			if [ -z $2 ]; then perror "Missing architecture"; print_help; exit; fi;
			set_arch $2
			shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

CROSS_SCRIPT_NAME=${CROSS_SCRIPT_NAME}-${CROSS_ARCH}
IMAGE_NAME=${IMAGE_NAME}-${CROSS_ARCH}

if [[ -z $ARCHITECTURE_SET ]]; then
	pwarning "Using default architecture $DEFAULT_ARCH"
fi

if [[ ! -z $UNINSTALL ]]; then
	psuccess "Removing ${CROSS_SCRIPT_PATH}/${CROSS_SCRIPT_NAME}"
	rm -r ${CROSS_SCRIPT_PATH}/${CROSS_SCRIPT_NAME}
	psuccess "Removing docker image ${IMAGE_NAME}"
	docker rmi ${IMAGE_NAME}

	if [[ ! -z $PURGE ]]; then
		psuccess "Removing chroot ${CROSS_CHROOT}"
		rm -r ${CROSS_CHROOT}
		
	fi
	psuccess "${IMAGE_NAME} has been successfully uninstalled"
	exit
fi

docker build $ARGS \
	-t $IMAGE_NAME \
	--build-arg "TOOLCHAIN_URL=${TOOLCHAIN_URL}" \
	--build-arg "TOOLCHAIN_ARCHIVE=${TOOLCHAIN_ARCHIVE}" \
	--build-arg "TOOLCHAIN_FOLDER=${TOOLCHAIN_FOLDER}" \
	.

CROSS_LIBS_PATH="/opt/${IMAGE_NAME}/chroot"

mkdir -p $CROSS_LIBS_PATH

<< EOF > ${CROSS_SCRIPT_NAME}.sh cat
#!/bin/bash

SRC_DIR=\$(pwd)
CROSS_CHROOT=$CROSS_LIBS_PATH

if [[ \$# -ge 1 ]]; then
	SRC_DIR=\$1
	if [[ "\$SRC_DIR" != /* ]]; then
		SRC_DIR=\$(pwd)/\${SRC_DIR}
	fi
fi

docker run \
	-v \${SRC_DIR}:/project \
	-v \${CROSS_CHROOT}:/cross-chroot \
	--rm \
	-it ${IMAGE_NAME} 
EOF

chmod +x ${CROSS_SCRIPT_NAME}.sh
psuccess "Installing to ${CROSS_SCRIPT_PATH}/${CROSS_SCRIPT_NAME}"
psuccess "Chroot is located at ${CROSS_LIBS_PATH}"
mv ${CROSS_SCRIPT_NAME}.sh ${CROSS_SCRIPT_PATH}/${CROSS_SCRIPT_NAME}
psuccess "To enter the crosscompile environment run ${CROSS_SCRIPT_NAME}"
