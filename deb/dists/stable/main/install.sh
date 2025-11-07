#!/bin/bash
# =====================================================
# 🛰️ Patagonia Fiber - Instalador Automático NetDiag
# Versión 1.1 - Full AutoCheck
# =====================================================

APP="patagonia-diagnet"
BIN="diagnet"
REPO_URL="https://cmewalter72-cloud.github.io/Patagonia-Fiber"
TMP_DIR="/tmp/${APP}_install"
INSTALL_PATH="/usr/local/bin"
PKG_DEB="${APP}_1.6_amd64.deb"
LOG_FILE="/var/log/patagonia-netdiag-install.log"

# --- Colores ---
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
RESET="\033[0m"

echo -e "${GREEN}🚀 Instalador de ${APP} iniciado...${RESET}"

sudo mkdir -p "$(dirname "$LOG_FILE")"
sudo touch "$LOG_FILE"

# --- Registrar en log ---
log() {
    echo "[$(date '+%F %T')] $1" | sudo tee -a "$LOG_FILE" >/dev/null
}

# --- Preparar entorno ---
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR" || exit 1
log "Inicio de instalación."

# --- Paquetes necesarios ---
REQ_PKGS=(python3 python3-pip python3-venv traceroute dnsutils curl openssl whois)

echo -e "${YELLOW}🔍 Verificando dependencias del sistema...${RESET}"
for pkg in "${REQ_PKGS[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        echo -e "📦 Instalando $pkg..."
        log "Instalando dependencia: $pkg"
        sudo apt-get install -y "$pkg" >>"$LOG_FILE" 2>&1
    else
        log "Dependencia OK: $pkg"
    fi
done

# --- Intentar instalación binaria ---
echo -e "${YELLOW}💾 Descargando paquete precompilado (.deb)...${RESET}"
log "Descargando $PKG_DEB desde $REPO_URL"
if curl -fsSLO "$REPO_URL/deb/pool/main/p/${PKG_DEB}"; then
    echo -e "📦 Instalando ${PKG_DEB}..."
    sudo dpkg -i "$PKG_DEB" >>"$LOG_FILE" 2>&1

    # probar ejecución
    if $BIN google.com >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Instalación binaria completada correctamente.${RESET}"
        log "Instalación binaria exitosa."
        FINISH_MODE="binario"
    else
        echo -e "${RED}⚠️ El binario no es compatible con esta versión de Ubuntu.${RESET}"
        echo -e "${YELLOW}🔧 Se intentará compilar una versión local...${RESET}"
        log "Falla binaria, iniciando compilación local."
        FINISH_MODE="compilado"
    fi
else
    echo -e "${RED}❌ No se pudo descargar el .deb desde GitHub.${RESET}"
    echo -e "${YELLOW}🔧 Se intentará compilar localmente...${RESET}"
    log "Falla descarga binario, modo compilación local."
    FINISH_MODE="compilado"
fi

# --- Compilación local (si corresponde) ---
if [ "$FINISH_MODE" = "compilado" ]; then
    python3 -m venv .venv
    source .venv/bin/activate
    pip install --quiet pyinstaller colorama
    curl -fsSL "$REPO_URL/diagnet.py" -o diagnet.py

    echo -e "${YELLOW}⚙️ Compilando versión local compatible...${RESET}"
    pyinstaller --onefile --hidden-import colorama diagnet.py >>"$LOG_FILE" 2>&1

    if [ -f "dist/diagnet" ]; then
        sudo mv dist/diagnet "$INSTALL_PATH/$BIN"
        sudo chmod +x "$INSTALL_PATH/$BIN"
        echo -e "${GREEN}✅ Compilación local completada exitosamente.${RESET}"
        log "Compilación local finalizada OK."
    else
        echo -e "${RED}❌ Falló la compilación local.${RESET}"
        log "Error: compilación local fallida."
        deactivate
        exit 1
    fi
    deactivate
fi

# --- Crear alias corto (netdiag) ---
if ! grep -q "alias netdiag=" ~/.bashrc; then
    echo "alias netdiag='${BIN}'" >>~/.bashrc
    log "Alias creado: netdiag"
fi

# --- Limpieza ---
rm -rf "$TMP_DIR"
echo -e "${GREEN}🎉 Instalación completada.${RESET}"
echo -e "   Usá los comandos:"
echo -e "   👉 ${YELLOW}diagnet dominio.com${RESET}"
echo -e "   👉 ${YELLOW}netdiag dominio.com${RESET}"
log "Instalación finalizada. Modo: $FINISH_MODE"

echo
echo -e "📄 Log de instalación: ${YELLOW}$LOG_FILE${RESET}"
