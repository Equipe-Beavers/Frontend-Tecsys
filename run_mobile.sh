#!/usr/bin/env bash
# Sobe o app no dispositivo físico apontando para o backend na rede local.
#
# Uso:
#   ./run_mobile.sh                # usa o IP padrão da máquina (192.168.12.83)
#   ./run_mobile.sh 192.168.0.50   # aponta para outro IP
#
# Emulador Android NÃO precisa deste script: o fallback 10.0.2.2 já funciona.
set -euo pipefail

IP="${1:-192.168.12.83}"
BASE_URL="http://${IP}:3000"

echo "→ API_BASE_URL=$BASE_URL"
cd "$(dirname "$0")"
flutter run --dart-define=API_BASE_URL="$BASE_URL" "$@"
