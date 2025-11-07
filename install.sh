#!/bin/bash
# =====================================================
# 🛰️ Patagonia Fiber - Instalador Automático NetDiag
# Versión 1.3 - Detección de versión Ubuntu + fallback
# =====================================================

APP="patagonia-netdiag"
BIN="diagnet"
REPO_URL="https://cmewalter72-cloud.github.io/Patagonia-Fiber"
TMP_DIR="/tmp/${APP}_install"
INSTALL_PATH="/usr/local/bin"

PKG_DEB_NEW="${APP}_1.6_amd64.deb"
PKG_DEB_OLD="${APP}_1.6_amd64_legacy.deb"   # (opcional, si luego lo subimos)
GLIBC_MIN="2.38"

# --- Colores ---
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
RESET="\033[0m"

echo -e "${GREEN}🚀 Instalador de ${APP} iniciado...${RESET}"

# --- Preparar entorno ---
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR" || exit 1

# --- Detectar versión de Ubuntu y glibc ---
UBU_VERSION=$(lsb_release -rs | cut -d'.' -f1 2>/dev/null || echo 0)
GLIBC_VERSION=$(ldd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
PKG_DEB="$PKG_DEB_NEW"

echo -e "${YELLOW}🧭 Detectando entorno...${RESET}"
echo -e "Ubuntu ${UBU_VERSION}  |  glibc ${GLIBC_VERSION:-desconocido}"

if [[ "$GLIBC_VERSION" < "$GLIBC_MIN" ]]; then
    echo -e "${YELLOW}⚠️ glibc < ${GLIBC_MIN}, usando versión alternativa o compilación local...${RESET}"
    PKG_DEB="$PKG_DEB_OLD"
fi

# --- Paquetes requeridos ---
REQ_PKGS=(python3 python3-pip python3-venv traceroute dnsutils curl openssl whois)

echo -e "${YELLOW}🔍 Verificando dependencias del sistema...${RESET}"
for pkg in "${REQ_PKGS[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        echo -e "📦 Instalando $pkg..."
        sudo apt-get update -qq
        sudo apt-get install -y "$pkg" >/dev/null 2>&1
    fi
done

# --- Intentar instalación binaria ---
echo -e "${YELLOW}💾 Descargando paquete precompilado (.deb)...${RESET}"

if curl --http1.1 -fsSLO "$REPO_URL/deb/pool/main/p/${PKG_DEB}"; then
    echo -e "📦 Instalando ${PKG_DEB}..."
    sudo dpkg -i "$PKG_DEB" >/dev/null 2>&1

    # Probar ejecución
    if $BIN google.com >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Instalación binaria completada correctamente.${RESET}"
        echo -e "   Ejecutá con: ${YELLOW}$BIN dominio.com${RESET}"
        FINISH_MODE="binario"
    else
        echo -e "${RED}⚠️ El binario no es compatible con esta versión (${GLIBC_VERSION}).${RESET}"
        echo -e "${YELLOW}🔧 Se intentará compilar una versión local...${RESET}"
        FINISH_MODE="compilado"
    fi
else
    echo -e "${RED}❌ No se pudo descargar el .deb desde GitHub.${RESET}"
    echo -e "${YELLOW}🔧 Se intentará compilar localmente...${RESET}"
    FINISH_MODE="compilado"
fi

# --- Compilación local (si corresponde) ---
if [ "$FINISH_MODE" = "compilado" ]; then
    python3 -m venv .venv
    source .venv/bin/activate
    pip install --quiet pyinstaller colorama
    curl --http1.1 -fsSL "$REPO_URL/diagnet.py" -o diagnet.py

    echo -e "${YELLOW}⚙️ Compilando versión local compatible...${RESET}"
    pyinstaller --onefile --hidden-import colorama diagnet.py >/dev/null 2>&1

    if [ -f "dist/diagnet" ]; then
        sudo mv dist/diagnet "$INSTALL_PATH/$BIN"
        sudo chmod +x "$INSTALL_PATH/$BIN"
        echo -e "${GREEN}✅ Compilación local completada exitosamente.${RESET}"
        FINISH_MODE="compilado"
    else
        echo -e "${RED}❌ Falló la compilación local.${RESET}"
        deactivate
        exit 1
    fi
    deactivate
fi

# --- Crear alias corto (netdiag) ---
if ! grep -q "alias netdiag=" ~/.bashrc; then
    echo "alias netdiag='${BIN}'" >>~/.bashrc
fi

# --- Limpieza ---
rm -rf "$TMP_DIR"
echo -e "${GREEN}🎉 Instalación completada.${RESET}"
echo -e "   Usá los comandos:"
echo -e "   👉 ${YELLOW}$BIN dominio.com${RESET}"
echo -e "   👉 ${YELLOW}netdiag dominio.com${RESET}"
echo -e "   (${YELLOW}Modo: ${FINISH_MODE:-desconocido}${RESET})"
