# hadolint global ignore=DL3008,DL4006
FROM ubuntu:24.04 AS builder

ARG PROFILE=release

RUN apt-get update \
    && apt-get -y --no-install-recommends install build-essential curl libssl-dev pkg-config ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
RUN /root/.cargo/bin/rustup update

COPY . /app
WORKDIR /app
RUN /root/.cargo/bin/cargo build --$PROFILE --package crunch

# ===== SECOND STAGE ======
FROM ubuntu:24.04

RUN apt-get update \
    && apt-get -y --no-install-recommends install ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ARG PROFILE=release
COPY --from=builder /app/target/$PROFILE/crunch /usr/local/bin

# Add the credentials needed to run crunch for this environment
ARG NETWORK=devnet
COPY --from=builder /app/environments/cc3/$NETWORK/* /

RUN useradd -U -s /bin/sh crunch
USER crunch

ENV RUST_BACKTRACE=1
ENV RUST_LOG="info"

RUN /usr/local/bin/crunch --version

ENTRYPOINT [ "/usr/local/bin/crunch" ]
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD curl --fail http://127.0.0.1:9999 || exit 1
