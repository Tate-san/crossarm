ARG IMAGE_VERSION="20.04"

FROM ubuntu:${IMAGE_VERSION} AS toolchain-preparation

WORKDIR /tmp

RUN apt update && apt install -y \
	wget \
	tar \
	xz-utils

# ARM32
#ARG arm_url="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-x86_64-arm-none-linux-gnueabihf.tar.xz"

# ARM64
# GLIBC 2.30
ARG TOOLCHAIN_URL="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/10.3-2021.07/binrel/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.xz"

RUN wget $TOOLCHAIN_URL -O toolchain.tar.xz
RUN mkdir toolchain && tar -xvf toolchain.tar.xz -C toolchain --strip-components=1

# FINAL
FROM ubuntu:${IMAGE_VERSION} AS final 

# Set timezone cuz cmake needs it, dunno why tho
ENV TZ=UTC
RUN ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
RUN echo "$TZ" > /etc/timezone

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
	python3-distutils \
	libclang-dev \
	clang \
	ninja-build

RUN cp /usr/bin/python3 /usr/bin/python

COPY --from=toolchain-preparation /tmp/toolchain /toolchain
COPY toolchain.cmake /opt/toolchain.cmake
	
RUN mkdir -p /cross-sysroot

# Create nonroot user
ARG USER_NAME=crossarm
ARG HOST_UID=1000
ARG HOST_GID=1000
RUN groupadd -g ${HOST_GID} ${USER_NAME} && useradd -g ${HOST_GID} -m -s /bin/bash -u ${HOST_UID} ${USER_NAME}

RUN chown -R ${USER_NAME}:${USER_NAME} /cross-sysroot
RUN chown -R ${USER_NAME}:${USER_NAME} /toolchain
RUN chown -R ${USER_NAME}:${USER_NAME} /opt

USER ${HOST_UID}:${HOST_GID}

RUN export CROSS_COMPILE=$(ls /toolchain/bin/ | grep -E 'gcc$' | sed 's/...$//') && \
	export SYSROOT=/cross-sysroot/$(echo $CROSS_COMPILE | rev | cut -c2- | rev) && \
	sed -i "s/toolchain_here/${CROSS_COMPILE}/" /opt/toolchain.cmake && \
	echo "export CROSS_COMPILE=${CROSS_COMPILE}" >> /home/crossarm/.bashrc && \
	echo "export SYSROOT=${SYSROOT}" >> /home/crossarm/.bashrc && \
	echo "export PATH=${PATH}:${SYSROOT}/bin:/cross-sysroot/bin" >> /home/crossarm/.bashrc && \
	echo "export CMAKE_TOOLCHAIN=/opt/toolchain.cmake" >> /home/crossarm/.bashrc && \
	echo "export LD_LIBRARY_PATH=${SYSROOT}:${LD_LIBRARY_PATH}" >> /home/crossarm/.bashrc

WORKDIR /project
ENTRYPOINT rsync -avrq /toolchain/* /cross-sysroot/ && /bin/bash
