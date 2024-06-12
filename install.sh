#!/bin/bash

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
	print_arg "-p" "--purge" "Remove sysroot (has to be combined with uninstall, otherwise wont work)"
	print_arg "-a" "--architecture <ARCHITECTURE>" "Build crosscompiling image for architecture. Available archs: arm, aarch64 (default: $DEFAULT_ARCH)"
}

#$1 - arch name
function set_arch {
	case "$1" in
		"arm" )
			TOOLCHAIN_URL="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/10.3-2021.07/binrel/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf.tar.xz"
			;;
		"aarch64" )  
			TOOLCHAIN_URL="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/10.3-2021.07/binrel/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.xz"
			;;
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
CROSS_SHARED_VOLUME="/opt/${IMAGE_NAME}"
CROSS_SYSROOT="${CROSS_SHARED_VOLUME}"

if [[ -z $ARCHITECTURE_SET ]]; then
	pwarning "Using default architecture $DEFAULT_ARCH"
fi

if [[ ! -z $UNINSTALL ]]; then
	psuccess "Removing ${CROSS_SCRIPT_PATH}/${CROSS_SCRIPT_NAME}"
	rm -r ${CROSS_SCRIPT_PATH}/${CROSS_SCRIPT_NAME}
	psuccess "Removing docker image ${IMAGE_NAME}"
	docker rmi -f ${IMAGE_NAME}

	if [[ ! -z $PURGE ]]; then
		psuccess "Removing shared volume ${CROSS_SHARED_VOLUME}"
		rm -r ${CROSS_SHARED_VOLUME}
		
	fi
	psuccess "${IMAGE_NAME} has been successfully uninstalled"
	exit
fi

docker build $ARGS \
	-t $IMAGE_NAME \
	--build-arg "TOOLCHAIN_URL=${TOOLCHAIN_URL}" \
	.

mkdir -p $CROSS_SYSROOT
chown -R $(logname):$(logname) ${CROSS_SHARED_VOLUME}

<< EOF > ${CROSS_SCRIPT_NAME}.sh cat
#!/bin/bash

SRC_DIR=\$(pwd)

function print_help {
	function print_arg {
		printf "   %-35s - %s\\n" "\$1 | \$2" "\$3"
	}
	printf "%s <PATH> <ARGS>\\n\\n" \$0
	printf " <PATH> - Folder to be opened in the crossarm environment\\n\\n"
	printf " Arguments:\\n"
	print_arg "-h" "--help" "Prints this help"
	print_arg "-c" "--command <COMMAND>" "Run image with command"
}

while true; do
	if [[ -z \$1 ]]; then break; fi
  case "\$1" in
		-h | --help ) print_help; exit;;
    -c | --command ) 
			if [[ -z \$2 ]]; then 
				echo "Missing command"
				exit
			fi
			COMMAND="\$2"
			shift 2 ;;
    -- ) shift; break ;;
    * ) SRC_DIR=\$1; 
				if [[ "\$SRC_DIR" != /* ]]; then
					SRC_DIR=\$(pwd)/\${SRC_DIR}
				fi
			shift ;;
  esac
done

if [[ -z \$COMMAND ]]; then
	docker run \
		-v \${SRC_DIR}:/project \
		-v ${CROSS_SYSROOT}:/cross-sysroot \
		--rm \
		-it ${IMAGE_NAME} 
else
	docker run \
		-v \${SRC_DIR}:/project \
		-v ${CROSS_SYSROOT}:/cross-sysroot \
		--rm \
		-it ${IMAGE_NAME} \
		bash -c "\${COMMAND}"
fi
EOF

chmod +x ${CROSS_SCRIPT_NAME}.sh
psuccess "Installing to ${CROSS_SCRIPT_PATH}/${CROSS_SCRIPT_NAME}"
psuccess "Shared volume is located at ${CROSS_SHARED_VOLUME}"
psuccess "Sysroot is located at ${CROSS_SYSROOT}"
mv ${CROSS_SCRIPT_NAME}.sh ${CROSS_SCRIPT_PATH}/${CROSS_SCRIPT_NAME}
psuccess "To enter the crosscompile environment run ${CROSS_SCRIPT_NAME}"
