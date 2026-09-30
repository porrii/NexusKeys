#!/usr/bin/env bash
#
# Compila NexusKeys para Android desde Linux.
#
# Antes de compilar, comprueba que esta maquina tiene lo necesario (Flutter,
# Git, JDK 17, Android SDK con las licencias aceptadas) y avisa de TODO lo
# que falte de una vez -con una explicacion y la URL de donde conseguirlo
# cada uno-, en vez de pararse en el primer hueco. No instala nada por si
# mismo a proposito: cada herramienta la instala el usuario donde y como
# prefiera.
#
# Si todo esta en orden, compila con la salida de flutter en directo en la
# terminal.
#
# Windows no es un target que se pueda compilar desde Linux (Flutter necesita
# el propio MSVC de una maquina Windows) - para eso usa compilar.bat en un
# PC con Windows.
#
# Uso:
#   ./compilar.sh --android [--limpio] [--debug]
#   ./compilar.sh --ayuda

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -t 1 ]; then
    C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_RED=$'\033[31m'
    C_YELLOW=$'\033[33m'; C_MAGENTA=$'\033[35m'; C_GRAY=$'\033[90m'; C_RESET=$'\033[0m'
else
    C_CYAN=""; C_GREEN=""; C_RED=""; C_YELLOW=""; C_MAGENTA=""; C_GRAY=""; C_RESET=""
fi

banner() {
    echo ""
    echo "${C_MAGENTA}========================================================${C_RESET}"
    echo "${C_MAGENTA}   NexusKeys - script de compilacion${C_RESET}"
    echo "${C_MAGENTA}========================================================${C_RESET}"
}

usage() {
    banner
    cat <<EOF

Uso:
  ./compilar.sh --android [--limpio] [--debug]

Opciones:
  --android        Compila el APK de Android.
  --limpio         Ejecuta 'flutter clean' antes de compilar.
  --debug          Compila en modo debug en vez de release.
  --sin-comprobar  Salta la comprobacion de requisitos (para quien ya
                   sabe que su maquina esta lista).
  --ayuda, -h      Muestra esta ayuda.

El resultado se copia a dist/android/, nombrado con la version leida de
pubspec.yaml.

Nota: Windows no es un target que se pueda compilar desde Linux (Flutter
necesita el propio MSVC de una maquina Windows real). Para eso usa
compilar.bat en un PC con Windows.
EOF
}

ok()      { echo "${C_GREEN}    [OK]    $1${C_RESET}"; }
missing() { echo "${C_RED}    [FALTA] $1${C_RESET}"; }
detail()  { echo "        $1"; echo "${C_CYAN}        $2${C_RESET}"; }

# --- Parseo de argumentos --------------------------------------------------

platform=""
clean=0
debug_build=0
skip_checks=0
show_help=0

for arg in "$@"; do
    case "${arg,,}" in
        --android)       platform="android" ;;
        --windows)       platform="windows" ;;
        --limpio)        clean=1 ;;
        --debug)         debug_build=1 ;;
        --sin-comprobar) skip_checks=1 ;;
        --ayuda|-h|--help) show_help=1 ;;
        *) echo "Argumento no reconocido: $arg" >&2 ;;
    esac
done

if [ "$show_help" = "1" ]; then
    usage
    exit 0
fi
if [ -z "$platform" ]; then
    usage
    exit 1
fi

if [ "$platform" = "windows" ]; then
    banner
    echo ""
    echo "${C_RED}Windows no se puede compilar desde Linux.${C_RESET}"
    echo "Flutter necesita el compilador de Visual Studio (MSVC) de una maquina"
    echo "Windows real para el target de escritorio Windows - no hay forma de"
    echo "compilarlo de forma cruzada desde aqui."
    echo ""
    echo "Usa compilar.bat en un PC con Windows para eso."
    exit 1
fi

banner
echo ""
echo "Plataforma: $platform"

# --- Deteccion de herramientas ----------------------------------------------

find_java17() {
    local candidate major

    if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
        major="$("$JAVA_HOME/bin/java" -version 2>&1 | grep -m1 'version' | sed -E 's/.*version "?([0-9]+).*/\1/')"
        if [ "$major" = "17" ]; then echo "$JAVA_HOME"; return 0; fi
    fi

    for candidate in /usr/lib/jvm/*17* "$HOME"/.jdks/*17* /opt/*jdk*17* "$HOME/Android/Sdk/jbr"; do
        [ -x "$candidate/bin/java" ] || continue
        major="$("$candidate/bin/java" -version 2>&1 | grep -m1 'version' | sed -E 's/.*version "?([0-9]+).*/\1/')"
        if [ "$major" = "17" ]; then echo "$candidate"; return 0; fi
    done

    if command -v java >/dev/null 2>&1; then
        major="$(java -version 2>&1 | grep -m1 'version' | sed -E 's/.*version "?([0-9]+).*/\1/')"
        if [ "$major" = "17" ]; then
            candidate="$(command -v java)"
            dirname "$(dirname "$candidate")"
            return 0
        fi
    fi

    return 1
}

find_android_sdk() {
    local candidate
    for candidate in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Android/Sdk"; do
        [ -n "$candidate" ] || continue
        if [ -x "$candidate/platform-tools/adb" ]; then echo "$candidate"; return 0; fi
    done
    return 1
}

# --- Comprobacion de requisitos --------------------------------------------

echo ""
echo "${C_CYAN}==> Comprobando requisitos para $platform...${C_RESET}"
echo ""

missing_count=0

if command -v flutter >/dev/null 2>&1; then
    ok "Flutter SDK"
else
    missing "Flutter SDK"
    detail "Necesario para compilar cualquier plataforma." "https://docs.flutter.dev/get-started/install/linux"
    missing_count=$((missing_count + 1))
fi

if command -v git >/dev/null 2>&1; then
    ok "Git"
else
    missing "Git"
    detail "Lo usan el propio Flutter SDK y 'flutter pub get'." "https://git-scm.com/download/linux"
    missing_count=$((missing_count + 1))
fi

java17_home=""
if java17_home="$(find_java17)"; then
    ok "JDK 17"
else
    missing "JDK 17"
    detail "Gradle/Kotlin de este proyecto necesitan exactamente Java 17, ni 21 ni 11. Instalalo y define JAVA_HOME." "https://adoptium.net/temurin/releases/?version=17"
    missing_count=$((missing_count + 1))
fi

sdk_root=""
if sdk_root="$(find_android_sdk)"; then
    ok "Android SDK - platform-tools"
    if [ -f "$sdk_root/licenses/android-sdk-license" ]; then
        ok "Licencias del Android SDK aceptadas"
    else
        missing "Licencias del Android SDK aceptadas"
        detail "Ejecuta: sdkmanager --licenses, o flutter doctor --android-licenses." "https://developer.android.com/studio#command-tools"
        missing_count=$((missing_count + 1))
    fi
else
    missing "Android SDK - platform-tools"
    detail "Instala las command-line tools, coloca 'adb' en <sdk>/platform-tools/, y define ANDROID_HOME/ANDROID_SDK_ROOT." "https://developer.android.com/studio#command-tools"
    missing_count=$((missing_count + 1))
fi

if [ "$missing_count" -gt 0 ] && [ "$skip_checks" = "0" ]; then
    echo ""
    echo "${C_RED}Requisitos pendientes antes de poder compilar: $missing_count${C_RESET}"
    echo "${C_YELLOW}Instala cada cosa donde prefieras y vuelve a ejecutar este script - no hace${C_RESET}"
    echo "${C_YELLOW}falta que sea todo de golpe, pero no se compilara nada hasta que este todo listo.${C_RESET}"
    echo "${C_GRAY}--sin-comprobar salta esta comprobacion, para quien ya sabe que esta bien.${C_RESET}"
    exit 1
fi

if [ "$missing_count" -gt 0 ]; then
    echo ""
    echo "${C_YELLOW}[AVISO] Comprobacion saltada por --sin-comprobar - requisitos pendientes: $missing_count; si la compilacion falla, sera por esto.${C_RESET}"
fi

echo ""
echo "${C_GREEN}Requisitos en orden. Empezando a compilar...${C_RESET}"

# --- Version del proyecto ---------------------------------------------------

full_version="$(grep -E '^version:' pubspec.yaml | head -1 | sed -E 's/^version:[[:space:]]*//')"
if [ -z "$full_version" ]; then
    echo "${C_RED}No se pudo leer la version desde pubspec.yaml${C_RESET}"
    exit 1
fi
version="${full_version%%+*}"
echo "Version: $full_version"

# --- Compilacion -------------------------------------------------------------

if [ -n "$java17_home" ]; then export JAVA_HOME="$java17_home"; fi
if [ -n "$sdk_root" ]; then export ANDROID_HOME="$sdk_root"; export ANDROID_SDK_ROOT="$sdk_root"; fi

if [ "$clean" = "1" ]; then
    echo ""
    echo "${C_CYAN}==> flutter clean${C_RESET}"
    flutter clean || { echo "${C_RED}FALLO: flutter clean${C_RESET}"; exit 1; }
fi

echo ""
echo "${C_CYAN}==> flutter pub get${C_RESET}"
flutter pub get || { echo "${C_RED}FALLO: flutter pub get${C_RESET}"; exit 1; }

if [ "$debug_build" = "1" ]; then build_mode="debug"; else build_mode="release"; fi
dist_dir="dist/android"
mkdir -p "$dist_dir"

if [ ! -f "key.properties" ]; then
    echo "${C_YELLOW}[AVISO] No hay key.properties: el APK se firmara con la clave de depuracion, no valida para una release real.${C_RESET}"
fi

echo ""
echo "${C_CYAN}==> flutter build apk --$build_mode${C_RESET}"
flutter build apk "--$build_mode" || { echo "${C_RED}FALLO: flutter build apk${C_RESET}"; exit 1; }

apk_src="build/app/outputs/flutter-apk/app-$build_mode.apk"
if [ ! -f "$apk_src" ]; then
    echo "${C_RED}No se encontro el APK generado en $apk_src${C_RESET}"
    exit 1
fi

apk_dest="$dist_dir/NexusKeys-$version.apk"
cp -f "$apk_src" "$apk_dest"
ok "APK copiado a $apk_dest"

echo ""
echo "${C_MAGENTA}========================================================${C_RESET}"
echo "${C_GREEN} Compilacion completa: $dist_dir${C_RESET}"
echo "${C_MAGENTA}========================================================${C_RESET}"
