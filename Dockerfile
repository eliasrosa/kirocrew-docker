FROM ghcr.io/kirodotdev/kirocrew:stable

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client \
    git \
    && rm -rf /var/lib/apt/lists/*

USER kirocrew
