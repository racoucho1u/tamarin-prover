# WARNING: This Dockerfile has been made to compile tamarin-prover based on August 2025
# tamarin-prover development branch, with current dependencies. Compiling older versions
# may be difficult, while probably possible, you may want to downgrade debian to an older
# version to downgrade dependencies versions. Legacy version pipelines are built with nix
# packages, this is not applicable here, as this method is broken for the development branch.
# I have no reproducibility guaranties for this pipeline : I recommend to try to build the
# image by yourself and then give the dockerfile to batch-tamarin.

# Tamarin Prover Local Build using Debian Sid (debian:sid is used for getting the
# latest versions of dependencies, especially for maude. debian-sid maude was v3.4
# in Aug 2025, you can find older "pinned" versions with debian:bullseye -> maude v3.1
# and debian:bookworm -> maude v3.2, when I write this, debian:trixie with maude v3.4
# will be launched soon. There is no older version available with apt).
# Built for batch-tamarin Docker execution using Stack from local source

############################################################################################
# USAGE:
# 1. Place your tamarin-prover source code in the same directory as this Dockerfile
# 2. Rename your tamarin source directory to "tamarin-prover" (or change the COPY line below)
# 3. Build with: docker build -f local-tamarin.Dockerfile -t tamarin-prover:{version_tag} .

# You can replace {version_tag} with a tag of your choice, i.e. tamarin-prover:local
############################################################################################

FROM debian:sid AS builder

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8

# Install all required dependencies in one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Essential build tools
    build-essential \
    pkg-config \
    # Haskell development
    haskell-stack \
    ghc \
    # Tamarin runtime dependencies
    maude \
    graphviz \
    # Development utilities
    ca-certificates \
    # GHC dependencies
    libffi-dev \
    libgmp-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for building
RUN groupadd -r tamarin && useradd -r -g tamarin -s /bin/bash -m tamarin
USER tamarin
WORKDIR /home/tamarin

# Copy local tamarin-prover source
# CHANGE THIS LINE if you want to name your source an other way
COPY --chown=tamarin:tamarin tamarin-prover/ /home/tamarin/tamarin-prover/

# Build tamarin-prover with stack
WORKDIR /home/tamarin/tamarin-prover
RUN stack setup && \
    stack build --system-ghc && \
    stack install --system-ghc --local-bin-path /home/tamarin/.local/bin

# Verify the build
RUN /home/tamarin/.local/bin/tamarin-prover test

# Runtime stage
FROM debian:sid AS runtime

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    TAMARIN_VERSION=develop

# Install only runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    maude \
    graphviz \
    ca-certificates \
    # Runtime libraries
    libffi8 \
    libgmp10 \
    zlib1g \
    libnuma1 \
    curl \
    python3\
    pip\
    pipx\
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r tamarin && useradd -r -g tamarin -s /bin/bash -m tamarin

# Copy built binary from builder stage
COPY --from=builder --chown=tamarin:tamarin /home/tamarin/.local/bin/tamarin-prover /usr/local/bin/tamarin-prover

# Install batch-tamarin using pipx
ENV PIPX_HOME=/home/tamarin/.local/bin
ENV PIPX_BIN_DIR=/home/tamarin/.local/bin
RUN pipx install batch-tamarin==1.0.0

# Install python modules.
# NOTE: the venv MUST live outside /workspace: /workspace is bind-mounted at runtime,
# so anything built there in the image is hidden by the host directory.
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir \
       tabulate numpy matplotlib pandas pydot pyparsing tree_sitter
ENV PATH=/opt/venv/bin:/home/tamarin/.local/bin:$PATH

# COPY artifacts/strategiesBenchmark/tamarin-prover-1.4.1-2468-g300638b4 /home/tamarin/.local/bin/

# Switch to non-root user
# USER tamarin
# WORKDIR /workspace

# Verify installation works
RUN tamarin-prover test

# Getting the container ready for review
WORKDIR /workspace/tamarin-prover

# Default command
CMD ["bash"]