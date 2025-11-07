#!/bin/bash
# =====================================================
# 🌐 Patagonia Fiber - Instalador Rápido
# Versión 1.0
# =====================================================

URL="https://cmewalter72-cloud.github.io/Patagonia-Fiber/install.sh"
TITLE="🛰️ Patagonia Fiber Diagnet"

echo -e "\033[1;32m${TITLE}\033[0m"
echo "=============================================="
echo "Descargando instalador oficial..."
echo

if curl -fsSL "$URL" -o /tmp/netdiag_installer.sh; then
    chmod +x /tmp/netdiag_installer.sh
    echo -e "\033[1;33m⚙️  Ejecutando instalador...\033[0m"
    bash /tmp/netdiag_installer.sh
    echo
    echo -e "\033[1;32m✅ Instalación finalizada.\033[0m"
else
    echo -e "\033[1;31m❌ Error: No se pudo descargar el instalador desde GitHub.\033[0m"
    echo "Verificá tu conexión o contactá al soporte de Patagonia Fiber."
    exit 1
fi
