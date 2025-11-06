#!/bin/bash
# ===============================================
# 🛰️ Patagonia Fiber - Instalador Automático
# Versión 1.0
# ===============================================

APP="patagonia-netdiag"
BIN="diagnet"
REPO_URL="https://cmewalter72-cloud.github.io/Patagonia-Fiber"
TMP_DIR="/tmp/${APP}_install"
INSTALL_PATH="/usr/local/bin"
PY_REQS=("python3" "pip3")
PKG_DEB="${APP}_1.6_amd64.deb"

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

# --- Verificar dependencias base ---
echo -e "${YELLOW}🔍 Verificando dependencias del sistema...${RESET}"
for pkg in "${PY_REQS[@]}"; do
    if ! command -v "$pkg" &>/dev/null; then
        echo -e "📦 Instalando $pkg..."
        sudo apt update -qq
        sudo apt install -y "$pkg"
    fi
done

# --- Intentar instalación binaria ---
echo -e "${YELLOW}💾 Descargando paquete precompilado (.deb)...${RESET}"
if curl -fsSLO "$REPO_URL/deb/pool/main/p/${PKG_DEB}"; then
    echo -e "📦 Instalando ${PKG_DEB}..."
    sudo dpkg -i "$PKG_DEB" >/dev/null 2>&1

    # probar ejecución
    if $BIN google.com >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Instalación binaria completada correctamente.${RESET}"
        echo -e "   Ejecutá con: ${YELLOW}$BIN dominio.com${RESET}"
        exit 0
    else
        echo -e "${RED}⚠️ El binario no es compatible con esta versión de Ubuntu.${RESET}"
        echo -e "${YELLOW}🔧 Se intentará compilar una versión local...${RESET}"
    fi
else
    echo -e "${RED}❌ No se pudo descargar el .deb desde GitHub.${RESET}"
    echo -e "${YELLOW}🔧 Se intentará compilar localmente...${RESET}"
fi

# --- Compilación local ---
sudo apt install -y python3-venv >/dev/null 2>&1
python3 -m venv .venv
source .venv/bin/activate
pip install --quiet pyinstaller colorama

echo -e "${YELLOW}⚙️ Compilando versión local compatible...${RESET}"
curl -fsSL "$REPO_URL/diagnet.py" -o diagnet.py

pyinstaller --onefile --hidden-import colorama diagnet.py >/dev/null 2>&1

if [ -f "dist/diagnet" ]; then
    sudo mv dist/diagnet "$INSTALL_PATH/$BIN"
    sudo chmod +x "$INSTALL_PATH/$BIN"
    echo -e "${GREEN}✅ Compilación local completada exitosamente.${RESET}"
else
    echo -e "${RED}❌ Falló la compilación local.${RESET}"
    deactivate
    exit 1
fi

deactivate

# --- Limpieza ---
rm -rf "$TMP_DIR"
echo -e "${GREEN}🎉 Instalación completada.${RESET}"
echo -e "   Usá el comando: ${YELLOW}$BIN dominio.com${RESET}"
