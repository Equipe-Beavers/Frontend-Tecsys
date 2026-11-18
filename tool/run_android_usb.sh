#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."
if ! command -v curl >/dev/null; then
  echo "curl é necessário para verificar o frontend web local." >&2
  exit 1
fi

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

"$adb_bin" -s "$device_id" reverse tcp:8080 tcp:8080

# The native app cannot serve an HTML page to the email's browser. Run Flutter
# web as a companion, keeping every interface in the frontend repository.
web_pid=""
cleanup() {
  if [[ -n "$web_pid" ]]; then
    kill "$web_pid" 2>/dev/null || true
    wait "$web_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

web_ready() {
  curl --fail --silent --max-time 2 http://127.0.0.1:8080/flutter_bootstrap.js >/dev/null
}

if ! web_ready; then
  web_log="$(mktemp "${TMPDIR:-/tmp}/geomash-recovery-web.XXXXXX")"
  echo "Iniciando o frontend web para os links de recuperação..."
  echo "Log do frontend web: $web_log"
  flutter run -d web-server --release --web-hostname=127.0.0.1 --web-port=8080 \
    --dart-define="API_BASE_URL=http://127.0.0.1:$backend_port" >"$web_log" 2>&1 &
  web_pid=$!
  ready=false
  for ((attempt=0; attempt<180; attempt++)); do
    if ! kill -0 "$web_pid" 2>/dev/null; then
      echo "Falha ao iniciar o frontend web. Confira $web_log." >&2
      tail -n 15 "$web_log" >&2
      exit 1
    fi
    if web_ready; then ready=true; break; fi
    sleep 1
  done
  if [[ "$ready" != true ]]; then
    echo "O frontend web não ficou pronto. Confira $web_log." >&2
    exit 1
  fi
fi
echo "Recuperação disponível no navegador do Android em http://127.0.0.1:8080/."

echo "Iniciando o Flutter no dispositivo $device_id..."
flutter run \
  -d "$device_id" \
  --dart-define="API_BASE_URL=http://127.0.0.1:$backend_port"
