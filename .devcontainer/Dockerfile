# Dev container for the Chess app: Flutter + Rust + flutter_rust_bridge +
# Android SDK/NDK + Linux-desktop deps. Versions pinned to match the project.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# System tooling: Flutter/desktop deps, Android build deps, project utilities.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git wget unzip zip xz-utils zstd ca-certificates gnupg \
    build-essential clang cmake ninja-build pkg-config \
    libgtk-3-dev liblzma-dev libstdc++-12-dev \
    openjdk-17-jdk-headless \
    python3 \
    usbutils android-tools-adb \
 && rm -rf /var/lib/apt/lists/*

ARG USERNAME=dev
RUN useradd -m -s /bin/bash ${USERNAME}
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# ---- Rust (rustup) + Android cross-targets + flutter_rust_bridge codegen ----
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --default-toolchain stable --profile minimal
ENV PATH="/home/${USERNAME}/.cargo/bin:${PATH}"
RUN rustup component add clippy rustfmt \
 && rustup target add aarch64-linux-android armv7-linux-androideabi \
                      x86_64-linux-android i686-linux-android
RUN cargo install flutter_rust_bridge_codegen --version 2.12.0 --locked

# ---- Flutter SDK (pinned) ----
RUN git clone https://github.com/flutter/flutter.git -b 3.44.0 --depth 1 \
      /home/${USERNAME}/flutter
ENV PATH="/home/${USERNAME}/flutter/bin:/home/${USERNAME}/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN git config --global --add safe.directory /home/${USERNAME}/flutter \
 && flutter config --no-analytics --enable-linux-desktop \
 && flutter precache --linux --android \
 && flutter doctor || true

# ---- Android SDK + NDK ----
ENV ANDROID_HOME="/home/${USERNAME}/Android/Sdk"
ENV ANDROID_NDK_HOME="${ANDROID_HOME}/ndk/28.2.13676358"
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && cd ${ANDROID_HOME}/cmdline-tools \
 && curl -sSL https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -o cmdtools.zip \
 && unzip -q cmdtools.zip && mv cmdline-tools latest && rm cmdtools.zip
ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"
RUN yes | sdkmanager --licenses >/dev/null 2>&1 || true
RUN sdkmanager "platform-tools" "platforms;android-36" "build-tools;35.0.0" \
               "ndk;28.2.13676358" "cmake;3.22.1" \
 && flutter doctor || true

CMD ["bash"]
