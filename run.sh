#!/usr/bin/env bash
#
# facefusion-swap :: run.sh
# FaceFusion 웹캠 UI를 CoreML 가속으로 띄운다.
#
# 환경변수로 조정 가능:
#   FF_SOURCE    대체할 얼굴 이미지 경로 (기본: faces/ 의 첫 이미지)
#   FF_PROVIDER  실행 프로바이더 (기본: cpu). ./bench.sh 로 자기 맥에 맞는 값을 찾을 것
#   FF_THREADS   추론 스레드 수 (기본: 8)
#   FF_EXTRA     facefusion에 그대로 넘길 추가 인자
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR="$ROOT/vendor/facefusion"
VENV="$ROOT/.venv"
PY="$VENV/bin/python"

die() { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; exit 1; }

[[ -x "$PY" ]]          || die "가상환경이 없습니다. 먼저 ./setup.sh 를 실행하세요."
[[ -d "$VENDOR/.git" ]] || die "FaceFusion 소스가 없습니다. 먼저 ./setup.sh 를 실행하세요."

# 소스 얼굴 결정: FF_SOURCE > faces/ 의 첫 이미지
SOURCE="${FF_SOURCE:-}"
if [[ -z "$SOURCE" ]]; then
	SOURCE="$(find "$ROOT/faces" -maxdepth 1 -type f \
		\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
		2>/dev/null | sort | head -1 || true)"
fi

if [[ -z "$SOURCE" ]]; then
	cat >&2 <<'EOF'
[x] 대체할 얼굴 이미지가 없습니다.

    faces/ 폴더에 이미지 1장을 넣고 다시 실행하세요.
    실존 인물 사진 대신 AI 생성 가상 얼굴을 사용하세요.

      curl -L https://thispersondoesnotexist.com/random-person.jpeg -o faces/synthetic.jpg
EOF
	exit 1
fi

# 기본값이 cpu인 이유:
# M4 Pro 실측에서 coreml 7.8fps vs cpu 20.0fps 로 CPU가 2.6배 빨랐다.
# 얼굴 스왑 모델은 입력이 작아(256px) ANE/GPU 전송 오버헤드가 이득을 넘어선다.
# 맥마다 다를 수 있으니 ./bench.sh 로 확인 후 FF_PROVIDER 로 바꿔 쓸 것.
PROVIDER="${FF_PROVIDER:-cpu}"

echo "==> 소스 얼굴  : $SOURCE"
echo "==> 프로바이더 : $PROVIDER (변경: FF_PROVIDER=coreml ./run.sh)"
echo "==> UI         : http://127.0.0.1:7860"
echo

cd "$VENDOR"
exec "$PY" facefusion.py run \
	--ui-layouts webcam \
	--execution-providers "$PROVIDER" \
	--execution-thread-count "${FF_THREADS:-8}" \
	--processors face_swapper \
	--source-paths "$SOURCE" \
	${FF_EXTRA:-}
