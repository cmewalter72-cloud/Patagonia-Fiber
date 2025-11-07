#!/bin/bash
# =====================================================
# 🛰️ Patagonia Fiber - Instalador Automático NetDiag
# Versión 1.2 - Estable (fix HTTP/2 & compatibilidad)
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

log() { echo "[$(date '+%F %T')] $1" | sudo tee -a "$LOG_FILE" >/dev/null; }

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR" || exit 1
log "Inicio de instalación."

# --- Dependencias ---
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

# --- Descarga segura del binario ---
echo -e "${YELLOW}💾 Descargando paquete precompilado (.deb)...${RESET}"
log "Descargando $PKG_DEB desde $REPO_URL"
if curl --http1.1 -fsSL -o "$PKG_DEB" "$REPO_URL/deb/pool/main/p/$PKG_DEB"; then
    echo -e "📦 Instalando ${PKG_DEB}..."
    sudo dpkg -i "$PKG_DEB" >>"$LOG_FILE" 2>&1
    if command -v $BIN >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Instalación binaria completada correctamente.${RESET}"
        log "Instalación binaria exitosa."
        FINISH_MODE="binario"
    else
        echo -e "${RED}⚠️ Binario incompatible con este Ubuntu.${RESET}"
        FINISH_MODE="compilado"
    fi
else
    echo -e "${RED}❌ Error descargando el binario.${RESET}"
    FINISH_MODE="compilado"
fi

# --- Compilación local ---
if [ "$FINISH_MODE" = "compilado" ]; then
    echo -e "${YELLOW}⚙️ Compilando versión local compatible...${RESET}"
    python3 -m venv .venv
    source .venv/bin/activate
    pip install --quiet pyinstaller colorama
    curl --http1.1 -fsSL -o diagnet.py "$REPO_URL/diagnet.py"
    pyinstaller --onefile --hidden-import colorama diagnet.py >>"$LOG_FILE" 2>&1
    if [ -f "dist/diagnet" ]; then
        sudo mv dist/diagnet "$INSTALL_PATH/$BIN"
        sudo chmod +x "$INSTALL_PATH/$BIN"
        echo -e "${GREEN}✅ Compilación local completada exitosamente.${RESET}"
        log "Compilación local exitosa."
    else
        echo -e "${RED}❌ Falló la compilación local.${RESET}"
        log "Error compilando localmente."
        deactivate
        exit 1
    fi
    deactivate
fi

# --- Alias ---
if ! grep -q "alias netdiag=" ~/.bashrc; then
    echo "alias netdiag='${BIN}'" >>~/.bashrc
    log "Alias creado: netdiag"
fi

rm -rf "$TMP_DIR"
echo -e "${GREEN}🎉 Instalación completada.${RESET}"
echo -e "   👉 Usá: ${YELLOW}diagnet dominio.com${RESET}"
echo -e "   👉 o: ${YELLOW}netdiag dominio.com${RESET}"
log "Instalación finalizada. Modo: $FINISH_MODE"
echo -e "📄 Log: ${YELLOW}$LOG_FILE${RESET}"
