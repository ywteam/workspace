# FROM alpine:edge
# FROM mcr.microsoft.com/devcontainers/base:alpine-3.19
FROM ubuntu:jammy
# ca-certificates \
RUN apt-get update && apt-get install -y --no-install-recommends \    
    apt-utils \    
    curl \
    git \
    gnupg \
    jq \
    bash \
    bsdmainutils \
    uuid-runtime \
    lsb-release \
    openssh-client \
    procps \
    software-properties-common \
    parallel \
    # sudo \
    # unzip \
    # wget \
    # zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* 
