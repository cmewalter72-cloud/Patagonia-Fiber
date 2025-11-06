#!/bin/bash
# ============================================
# 🛰️ PatagoniaFiber NetDiag Installer v1.6
# Instalador universal con descarga remota
# ============================================

set -e

REPO_URL="https://raw.githubusercontent.com/cmewalter72-cloud/Patagonia-Fiber/main/diagnet.py"
DEST="/usr/local/bin/diagnet"
TMP_FILE="/tmp/diagnet_temp.py"

echo "──────────────────────────────────────────────"
echo "🧩 Instalando PatagoniaFiber NetDiag v1.6"
echo "──────────────────────────────────────────────"

# Detectar gestor de paquetes
if command -v apt >/dev/null 2>&1; then
  PKG_MANAGER="apt"
  UPDATE_CMD="sudo apt update -y"
  INSTALL_CMD="sudo apt install -y"
elif command -v dnf >/dev/null 2>&1; then
  PKG_MANAGER="dnf"
  UPDATE_CMD="sudo dnf makecache"
  INSTALL_CMD="sudo dnf install -y"
elif command -v yum >/dev/null 2>&1; then
  PKG_MANAGER="yum"
  UPDATE_CMD="sudo yum makecache"
  INSTALL_CMD="sudo yum install -y"
elif command -v zypper >/dev/null 2>&1; then
  PKG_MANAGER="zypper"
  UPDATE_CMD="sudo zypper refresh"
  INSTALL_CMD="sudo zypper install -y"
else
  echo "❌ No se detectó un gestor de paquetes compatible."
  exit 1
fi

echo "📦 Gestor detectado: $PKG_MANAGER"
echo "📥 Actualizando índices..."
eval $UPDATE_CMD >/dev/null 2>&1 || true

# Dependencias
DEPENDENCIAS=(python3 python3-pip traceroute dnsutils curl openssl whois)
echo "🔧 Verificando dependencias..."
for pkg in "${DEPENDENCIAS[@]}"; do
  if ! command -v ${pkg%% *} >/dev/null 2>&1; then
    echo "➡️ Instalando $pkg..."
    eval "$INSTALL_CMD $pkg" >/dev/null 2>&1
  else
    echo "✅ $pkg ya instalado."
  fi
done

# Instalar colorama
echo "🎨 Verificando colorama..."
if python3 -c "import colorama" >/dev/null 2>&1; then
  echo "✅ colorama ya disponible."
else
  echo "📦 Instalando colorama..."
  if command -v pipx >/dev/null 2>&1; then
    pipx install colorama || true
  else
    sudo apt install pipx -y >/dev/null 2>&1 || true
    pipx install colorama || sudo pip3 install colorama --break-system-packages
  fi
fi

# Descargar script desde GitHub
echo "🌐 Descargando NetDiag desde el repositorio oficial..."
curl -fsSL "$REPO_URL" -o "$TMP_FILE" || {
  echo "❌ No se pudo descargar el script desde GitHub."
  exit 1
}

# Instalar y ocultar
echo "📂 Instalando en /usr/local/bin..."
sudo mv "$TMP_FILE" "$DEST"
sudo chmod +x "$DEST"
sudo chown root:root "$DEST"

# Limpiar temporales
rm -f "$TMP_FILE" 2>/dev/null || true

# Verificación
if [ -x "$DEST" ]; then
  echo "✅ Instalación completada correctamente."
  echo "──────────────────────────────────────────────"
  echo "📡 Ejecutá desde cualquier lugar:"
  echo "   diagnet salud.rionegro.gov.ar"
  echo "──────────────────────────────────────────────"
  echo "Para desinstalar: sudo rm /usr/local/bin/diagnet"
else
  echo "⚠️ Instalación incompleta. Verificá permisos."
fi
