#!/usr/bin/env bash
# Sem endereço, usa a configuração comum do app (USB preparado por npm run dev).
# Para Wi-Fi, ainda é possível informar explicitamente o IP do computador.
set -euo pipefail

cd "$(dirname "$0")"
if [[ $# -gt 0 && "$1" != -* ]]; then
  api_host="$1"
  shift
  exec flutter run --dart-define="API_BASE_URL=http://$api_host:3000" "$@"
fi
exec flutter run "$@"
