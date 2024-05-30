FROM --platform=$BUILDPLATFORM rust:bookworm as tooling

ARG FNM_VERSION=1.35.1
ARG RYE_VERSION=0.34.0

RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y \
  gcc-x86-64-linux-gnu \
  gcc-aarch64-linux-gnu

ENV HOST_CC=gcc
ENV CC_x86_64_unknown_linux_gnu=x86_64-linux-gnu-gcc
ENV CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc
ENV CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=x86_64-linux-gnu-gcc
ENV CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc

ARG TARGETPLATFORM

RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; \
  then echo aarch64-unknown-linux-gnu > .rust-target; \
  elif [ "$TARGETPLATFORM" = "linux/amd64" ]; \
  then echo x86_64-unknown-linux-gnu > .rust-target; \
  else echo "Unsupported arch: $TARGETPLATFORM"; exit 1; \
  fi

RUN rustup target add $(cat .rust-target)

RUN cargo install --root /root/.cargo fnm \
  --version ${FNM_VERSION} \
  --target $(cat .rust-target)

RUN cargo install --root /root/.cargo rye \
  --git https://github.com/astral-sh/rye \
  --tag ${RYE_VERSION} \
  --target $(cat .rust-target)

FROM --platform=$TARGETPLATFORM rust:bookworm as devcontainer

COPY --from=tooling /root/.cargo/bin/fnm /usr/local/bin/fnm
COPY --from=tooling /root/.cargo/bin/rye /usr/local/bin/rye

ARG NODE_VERSION=18
ARG PYTHON_VERSION=3.8

USER root
WORKDIR /root

ENV HOME=/root
ENV FNM_DIR=${HOME}/.fnm
ENV RYE_HOME=${HOME}/.rye

ENV PATH=${FNM_DIR}/aliases/default/bin:${RYE_HOME}/shims:${HOME}/.cargo/bin:${HOME}/.local/bin:${PATH}

RUN fnm install ${NODE_VERSION} \
  && fnm default ${NODE_VERSION}

RUN rye self install --yes \
  && rye toolchain fetch ${PYTHON_VERSION}

RUN echo "" >> ${HOME}/.zshrc \
  && echo 'eval "$(fnm env)"' >> ${HOME}/.zshrc \
  && echo 'source "$HOME/.rye/env"' >> ${HOME}/.zshrc

RUN npm install -g "pnpm@^8"
