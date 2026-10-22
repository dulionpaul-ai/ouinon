#!/usr/bin/env bash
# Installe, dans une session Claude neuve, ce qu'il faut pour compiler
# Ouinon : Flutter 3.47.7, le SDK Android (36), et le miroir Maven
# (Maven Central répond souvent « trop de demandes » depuis les sessions).
#
# Lancement depuis la racine du dépôt : bash tool/installer_outils.sh
# Ensuite, dans chaque commande :
#   export ANDROID_HOME=/home/user/outils/android
#   export PATH=/home/user/outils/flutter/bin:$PATH
set -euo pipefail

OUTILS=/home/user/outils
FLUTTER_VERSION=3.47.7
mkdir -p "$OUTILS"

if [ ! -x "$OUTILS/flutter/bin/flutter" ]; then
  echo "Flutter $FLUTTER_VERSION…"
  curl -sSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C "$OUTILS"
fi
git config --global --add safe.directory "$OUTILS/flutter"
export PATH="$OUTILS/flutter/bin:$PATH"
flutter config --no-analytics >/dev/null 2>&1 || true
dart --disable-analytics >/dev/null 2>&1 || true

export ANDROID_HOME="$OUTILS/android"
if [ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
  echo "Outils Android…"
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  curl -sSL -o /tmp/outils-android.zip \
    https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip
  unzip -q /tmp/outils-android.zip -d "$ANDROID_HOME/cmdline-tools"
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  rm /tmp/outils-android.zip
fi
yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1 || true
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" \
  "platform-tools" "platforms;android-36" "build-tools;36.0.0" >/dev/null

# Miroir Google de Maven Central, pour cette session seulement (hors dépôt).
mkdir -p ~/.gradle/init.d
cat > ~/.gradle/init.d/miroir.gradle.kts <<'GRADLE'
// Session Claude seulement : Maven Central répond 429, ses adresses sont
// remplacées par le miroir Google de Maven Central.
val miroir = uri("https://maven-central.storage-download.googleapis.com/maven2/")

fun RepositoryHandler.versMiroir() = all {
    if (this is MavenArtifactRepository &&
        url.toString().startsWith("https://repo.maven.apache.org")
    ) {
        url = miroir
    }
}

beforeSettings {
    pluginManagement.repositories.versMiroir()
    dependencyResolutionManagement.repositories.versMiroir()
}
allprojects {
    buildscript.repositories.versMiroir()
    repositories.versMiroir()
}
GRADLE

flutter pub get
echo "Prêt. Vérifier : flutter analyze && flutter test"
