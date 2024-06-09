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
COPY --from=toolchain-preparation /tmp/toolchain /toolchain
COPY toolchain.cmake /opt/toolchain.cmake

# Set timezone cuz cmake needs it, dunno why tho
ENV TZ=UTC
RUN ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
RUN echo "$TZ" > /etc/timezone

RUN DEBIAN_FRONTEND=noninteractive apt update && apt install -y \
	tzdata \
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

RUN export TOOLCHAIN=$(ls /toolchain/bin/ | grep -E 'gcc$' | sed 's/...$//') && \
	sed -i "s/toolchain_here/${TOOLCHAIN}/" /opt/toolchain.cmake && \
	echo "TOOLCHAIN=${TOOLCHAIN}" >> ~/.bashrc

RUN echo "export TOOLCHAIN=$(ls /toolchain/bin/ | grep -E 'gcc$' | sed 's/...$//')" >> /root/.bashrc

ENV PATH="/toolchain/bin:${PATH}"

RUN mkdir -p /cross-chroot
ENV LD_LIBRARY_PATH=/cross-chroot:$LD_LIBRARY_PATH
ENV PATH="/cross-chroot/bin:${PATH}"

WORKDIR /project
