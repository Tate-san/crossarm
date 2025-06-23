# syntax=docker/dockerfile:1
ARG IMAGE="ubuntu"
ARG IMAGE_VERSION="20.04"
ARG TOOLCHAIN_URL=""
ARG TOOLCHAIN_DIR="/toolchain"
ARG CROSS_SYSROOT_DIR="/crossarm"

ARG USER_NAME=crossarm
ARG HOST_UID=1000
ARG HOST_GID=1000

FROM ${IMAGE}:${IMAGE_VERSION} AS toolchain-preparation
ARG TOOLCHAIN_URL
ARG TOOLCHAIN_DIR

# Download everything to the /tmp folder
WORKDIR /tmp

RUN apt update && apt install -y \
	wget \
	tar \
	xz-utils


RUN wget $TOOLCHAIN_URL -O toolchain.tar.xz
RUN mkdir -p ${TOOLCHAIN_DIR} && tar -xvf toolchain.tar.xz -C ${TOOLCHAIN_DIR} --strip-components=1

# FINAL
FROM ${IMAGE}:${IMAGE_VERSION} AS final 
LABEL maintainer="burnek.matyas@gmail.com" \
      version="1.0.1" \
      description="Image for ARM & AARCH64 crosscompiling"

ARG USER_NAME
ARG HOST_UID
ARG HOST_GID
ARG TOOLCHAIN_DIR
ARG CROSS_SYSROOT_DIR

# Copy required files to the final image
COPY --from=toolchain-preparation ${TOOLCHAIN_DIR} ${TOOLCHAIN_DIR}
COPY toolchain.cmake ${TOOLCHAIN_DIR}/toolchain.cmake
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set timezone cuz cmake needs it, dunno why tho
ENV TZ=UTC
RUN ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
RUN echo "$TZ" > /etc/timezone

# Update and install necessary packages
RUN DEBIAN_FRONTEND=noninteractive apt update && apt install -y \
	tzdata \
	rsync \
	pkg-config \
	git \
	make \
	build-essential \
	libssl-dev \
	cmake \
	python3 \
	libclang-dev \
	clang \
	vim \
	wget \
	sshpass \
	ninja-build

# Alias python3 to python
RUN cp /usr/bin/python3 /usr/bin/python

# Make the sysroot dir
RUN mkdir -p ${CROSS_SYSROOT_DIR} 

# Set root password
RUN echo 'root:toor' | chpasswd
# Create nonroot user
RUN groupadd -g ${HOST_GID} ${USER_NAME} && useradd -g ${HOST_GID} -m -s /bin/bash -u ${HOST_UID} ${USER_NAME}

# Own the sysroot and toolchain folders
RUN chown -R ${HOST_UID}:${HOST_GID} ${CROSS_SYSROOT_DIR} ${TOOLCHAIN_DIR}

# Determine the cross-compiler prefix at build time and generate profile script
RUN GCC_BIN_PATH=$(ls "${TOOLCHAIN_DIR}/bin/" | grep -E 'gcc$' | head -n1) \
 && CROSS_PREFIX=$(basename "$GCC_BIN_PATH" | sed 's/gcc$//') \
 && SYSROOT_PATH="${CROSS_SYSROOT_DIR}/${CROSS_PREFIX%-*}" \
 && sed -i "s/toolchain_here/${CROSS_PREFIX}/" ${TOOLCHAIN_DIR}/toolchain.cmake \
 && mkdir -p "$SYSROOT_PATH" \
 && cat <<EOF > /etc/profile.d/cross.sh
export CROSS_SYSROOT_DIR=${CROSS_SYSROOT_DIR}
export TOOLCHAIN_DIR=${TOOLCHAIN_DIR}
export CROSS_COMPILE=${CROSS_PREFIX}
export SYSROOT=${SYSROOT_PATH}
export PATH=\${PATH:-}:${TOOLCHAIN_DIR}/bin:${SYSROOT_PATH}/bin
export CMAKE_TOOLCHAIN=${TOOLCHAIN_DIR}/toolchain.cmake
export LD_LIBRARY_PATH=\$SYSROOT:\${LD_LIBRARY_PATH:-}
EOF

RUN chown -R ${HOST_UID}:${HOST_GID} /etc/profile.d/cross.sh

# Swap to nonroot user
USER ${HOST_UID}:${HOST_GID}
WORKDIR /project

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash", "-i"]
