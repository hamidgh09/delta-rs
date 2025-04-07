#!/bin/bash
set -e

# Write the Dockerfile into the current directory.
cat << 'EOF' > Dockerfile
# Use a slim Debian base image
FROM python:3.11.9-slim

# Build arguments to allow setting user/group from host values.
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USER_NAME=user
ARG GROUP_NAME=user

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/${USER_NAME}

# Install system dependencies required for building Python and for other tools.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    curl \
    ca-certificates \
    libssl-dev \
    libffi-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncursesw5-dev \
    libgdbm-dev \
    libnss3-dev \
    liblzma-dev \
    tk-dev \
    python3 \
    python3-pip \
    git \
    patchelf \
    curl \
 && rm -rf /var/lib/apt/lists/*


# Install the "uv" Python package via pip
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install uv

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Create a group and user with the specified IDs, and set up the home directory.
RUN groupadd -g ${GROUP_ID} ${GROUP_NAME} && \
    useradd -m -u ${USER_ID} -g ${GROUP_NAME} -s /bin/bash ${USER_NAME}

RUN chown -R ${USER_NAME}:${GROUP_NAME} ${HOME}

# Switch to the new user.
USER ${USER_NAME}
WORKDIR ${HOME}

ENV PATH=${HOME}/.cargo/bin:$PATH

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
   /bin/bash -c "cd /home/$(id -un)/delta-rs/python && make clean && make build"