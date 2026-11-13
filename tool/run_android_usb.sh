#!/usr/bin/env bash

set -euo pipefail

backend_port="${BACKEND_PORT:-3000}"
android_sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Android/Sdk}}"
adb_bin="$android_sdk/platform-tools/adb"

if [[ ! -x "$adb_bin" ]]; then
  echo "ADB não encontrado em: $adb_bin" >&2
  echo "Defina ANDROID_SDK_ROOT ou ANDROID_HOME e tente novamente." >&2
  exit 1
fi

device_id="${1:-}"
if [[ -z "$device_id" ]]; then
  device_id="$($adb_bin devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
fi

if [[ -z "$device_id" ]]; then
  echo "Nenhum aparelho Android autorizado foi encontrado." >&2
  echo "Conecte o cabo, ative a depuração USB e aceite a autorização no celular." >&2
  exit 1
fi

echo "Configurando o acesso USB ao backend na porta $backend_port..."
"$adb_bin" -s "$device_id" reverse "tcp:$backend_port" "tcp:$backend_port"

echo "Iniciando o Flutter no dispositivo $device_id..."
exec flutter run \
  -d "$device_id" \
  --dart-define="API_BASE_URL=http://127.0.0.1:$backend_port"
