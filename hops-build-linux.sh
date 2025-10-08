#!/bin/bash
set -e

# Write the Dockerfile into the current directory.
cat << 'EOF' > Dockerfile
# Use a slim Debian base image
FROM quay.io/pypa/manylinux_2_28_x86_64 AS build

# Build arguments to allow setting user/group from host values.
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USER_NAME=user
ARG GROUP_NAME=user

# Always start as root for package install
USER root

# Install build deps via yum/dnf (no apt-get here).
# Note: manylinux images already include lots of toolchain bits.
RUN yum -y update && \
    yum -y install \
      gcc gcc-c++ make \
      git wget curl ca-certificates \
      openssl-devel libffi-devel zlib-devel bzip2 bzip2-devel \
      readline-devel sqlite-devel ncurses-devel gdbm-devel nss-devel \
      xz xz-devel tk tk-devel which findutils && \
    yum clean all && rm -rf /var/cache/yum

# Create non-root user
RUN groupadd -g ${GROUP_ID} ${GROUP_NAME} && \
    useradd -m -u ${USER_ID} -g ${GROUP_NAME} -s /bin/bash ${USER_NAME}

# Use the bundled Python 3.11 from manylinux (adjust if you need a different ABI)
ENV PYBIN=/opt/python/cp311-cp311/bin

# Install uv with the manylinux Python
RUN ${PYBIN}/pip install --upgrade pip && \
    ${PYBIN}/pip install uv

# Install Rust for the non-root user (keeps cargo in their home)
USER ${USER_NAME}
ENV HOME=/home/${USER_NAME}
WORKDIR ${HOME}
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
ENV PATH="${HOME}/.cargo/bin:${PATH}"

# (Optional) expose the manylinux Python first on PATH for convenience
ENV PATH="${PYBIN}:${PATH}"

EOF

echo "Dockerfile created."
# Build the Docker image with host user/group info.
docker build \
  --build-arg USER_ID="$(id -u)" \
  --build-arg GROUP_ID="$(id -g)" \
  --build-arg USER_NAME="$(id -un)" \
  --build-arg GROUP_NAME="$(id -ng)" \
  -t delta-rs-build .

echo "Docker image built successfully."

# Run the container, mounting the current directory and executing build.sh.
docker run --rm=true \
   -v "$(pwd):/home/$(id -un)"/delta-rs \
   delta-rs-build \
   /bin/bash -c "cd /home/$(id -un)/delta-rs/python && make clean && export MATURIN_EXTRA_ARGS='--release --compatibility manylinux_2_28' && make build"