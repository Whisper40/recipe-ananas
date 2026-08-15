#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy

if [[ -z "${ANDROID_HOME:-}" && -d "/opt/homebrew/share/android-commandlinetools" ]]; then
	export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
fi
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:${PATH:-}"
if [[ -d "/Users/U43TX04/flutter-development/flutter/bin" ]]; then
	export PATH="/Users/U43TX04/flutter-development/flutter/bin:$PATH"
fi
export ANDROID_SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"

if [[ -z "${JAVA_HOME:-}" && -d "/opt/homebrew/opt/openjdk@17" ]]; then
	export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
fi

# Le réseau local peut intercepter TLS avec un certificat approuvé par macOS
# mais absent du truststore Java standard utilisé par Gradle.
if [[ "$(uname -s)" == "Darwin" ]]; then
	export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djavax.net.ssl.trustStoreType=KeychainStore -Djavax.net.ssl.trustStore=NONE"
fi

if [[ -z "${ANDROID_HOME:-}" || ! -d "$ANDROID_HOME" ]]; then
	echo "SDK Android introuvable. Installez Android Studio ou android-commandlinetools." >&2
	exit 1
fi

flutter pub get
flutter analyze
flutter build apk --release

mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk "dist/recette-box-$(date +%Y%m%d-%H%M%S).apk"
echo "APK disponible dans dist/"
