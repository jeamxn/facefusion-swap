#!/usr/bin/env bash
#
# facefusion-swap :: bench.sh
# 이 맥에서 cpu / coreml 중 무엇이 빠른지 실측한다.
#
# 얼굴 스왑 모델은 입력이 작아서 CoreML(ANE/GPU) 전송 오버헤드가 이득을 넘어서는 경우가 많다.
# M4 Pro에서는 CPU가 2.6배 빨랐다. 맥마다 다르므로 직접 재보고 FF_PROVIDER 를 정한다.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR="$ROOT/vendor/facefusion"
PY="$ROOT/.venv/bin/python"

[[ -x "$PY" ]] || { echo "먼저 ./setup.sh 를 실행하세요." >&2; exit 1; }

echo "실행 프로바이더별 처리 속도를 측정합니다. 각 1~2분 걸립니다."
echo

cd "$VENDOR"
for provider in cpu coreml; do
	printf '%-8s ' "$provider"
	fps="$("$PY" facefusion.py benchmark \
		--benchmark-resolutions 240p \
		--benchmark-cycle-count 1 \
		--processors face_swapper \
		--execution-providers "$provider" \
		--execution-thread-count "${FF_THREADS:-8}" 2>&1 \
		| tr '\r' '\n' | grep -a 'target-240p' | awk -F'|' '{gsub(/ /,"",$7); print $7}')"
	echo "${fps:-측정 실패} fps"
done

cat <<'EOF'

숫자가 큰 쪽을 쓰세요.

  FF_PROVIDER=cpu    ./run.sh
  FF_PROVIDER=coreml ./run.sh

run.sh 기본값은 cpu 입니다.
EOF
