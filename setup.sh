#!/usr/bin/env bash
#
# facefusion-swap :: setup.sh
# Apple Silicon Mac에 실시간 얼굴 대체(웹캠 익명화) 환경을 구성한다.
# 몇 번을 다시 실행해도 안전하다(idempotent).
#
set -euo pipefail

FACEFUSION_VERSION="3.8.2"
PYTHON_VERSION="3.12"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR="$ROOT/vendor/facefusion"
VENV="$ROOT/.venv"

log()  { printf "\033[1;36m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; exit 1; }

# ------------------------------------------------------------------
# 1. 실행 환경 점검
# ------------------------------------------------------------------
[[ "$(uname -s)" == "Darwin" ]] || die "macOS 전용 스크립트입니다."
[[ "$(uname -m)" == "arm64"  ]] || die "Apple Silicon(M1 이상)이 필요합니다. Intel Mac은 CoreML 가속이 없어 실시간 처리가 어렵습니다."
command -v brew >/dev/null 2>&1 || die "Homebrew가 필요합니다. https://brew.sh 에서 먼저 설치하세요."

log "환경: $(sw_vers -productName) $(sw_vers -productVersion) / $(sysctl -n machdep.cpu.brand_string)"

# ------------------------------------------------------------------
# 2. 시스템 의존성 (ffmpeg / uv / OBS)
# ------------------------------------------------------------------
log "시스템 의존성 확인"

if command -v ffmpeg >/dev/null 2>&1; then
	echo "    ffmpeg  : 이미 설치됨"
else
	echo "    ffmpeg  : 설치 중"
	brew install ffmpeg
fi

if command -v uv >/dev/null 2>&1; then
	echo "    uv      : 이미 설치됨 ($(uv --version))"
else
	echo "    uv      : 설치 중"
	brew install uv
fi

if [[ -d "/Applications/OBS.app" ]]; then
	echo "    OBS     : 이미 설치됨"
else
	echo "    OBS     : 설치 중"
	brew install --cask obs
fi

# ------------------------------------------------------------------
# 3. FaceFusion 소스 (vendor/, 버전 고정)
# ------------------------------------------------------------------
if [[ -d "$VENDOR/.git" ]]; then
	log "FaceFusion 소스 $FACEFUSION_VERSION 로 정렬"
	git -C "$VENDOR" fetch --depth 1 -f origin "refs/tags/$FACEFUSION_VERSION:refs/tags/$FACEFUSION_VERSION"
	git -C "$VENDOR" checkout -q "$FACEFUSION_VERSION"
else
	log "FaceFusion $FACEFUSION_VERSION 내려받는 중"
	mkdir -p "$(dirname "$VENDOR")"
	git clone --depth 1 --branch "$FACEFUSION_VERSION" \
		https://github.com/facefusion/facefusion.git "$VENDOR"
fi

# ------------------------------------------------------------------
# 4. 파이썬 환경 (uv)
#    - uv가 Python 3.12를 직접 받아오므로 시스템 파이썬을 건드리지 않는다.
#    - onnxruntime는 requirements.txt에 이미 고정되어 있고,
#      macOS arm64 휠에 CoreML Execution Provider가 포함되어 있다.
# ------------------------------------------------------------------
log "Python $PYTHON_VERSION 가상환경 준비 (uv)"
uv venv --python "$PYTHON_VERSION" "$VENV"

log "의존성 설치"
VIRTUAL_ENV="$VENV" uv pip install --requirement "$VENDOR/requirements.txt"

# CoreML EP가 실제로 잡히는지 확인
log "CoreML 가속 확인"
if "$VENV/bin/python" - <<'PY'
import sys
import onnxruntime
providers = onnxruntime.get_available_providers()
print("    providers:", ", ".join(providers))
sys.exit(0 if "CoreMLExecutionProvider" in providers else 1)
PY
then
	echo "    CoreML  : 사용 가능"
else
	warn "CoreMLExecutionProvider를 찾지 못했습니다. CPU로 동작하여 매우 느릴 수 있습니다."
fi

# ------------------------------------------------------------------
# 5. 추론 모델
#    기본값은 "받지 않음". 얼굴 대체에 필요한 모델만 첫 실행 때 자동으로 내려받는다(약 2GB).
#    force-download는 모든 프로세서(나이 변조, 립싱크 등)의 모델까지 받아 8GB 이상을 쓴다.
#    오프라인 환경에서 미리 전부 받아두려면 FF_PREFETCH=1 로 실행한다.
# ------------------------------------------------------------------
if [[ "${FF_PREFETCH:-0}" == "1" ]]; then
	log "전체 모델 사전 다운로드 (8GB 이상, 수십 분 소요)"
	if ! (cd "$VENDOR" && "$VENV/bin/python" facefusion.py force-download --download-scope lite); then
		warn "사전 다운로드에 실패했습니다. 첫 실행 시 자동으로 다시 시도합니다."
	fi
else
	log "모델은 첫 실행 시 필요한 것만 자동으로 내려받습니다 (약 2GB)"
fi

# ------------------------------------------------------------------
# 6. 안내
# ------------------------------------------------------------------
cat <<'EOF'

────────────────────────────────────────────────────────────
 설치 완료

 다음 순서로 진행하세요.

  1) faces/ 에 대체할 얼굴 이미지 1장을 넣습니다.
     반드시 AI 생성 가상 얼굴을 쓰세요. (예: https://thispersondoesnotexist.com)

  2) ./run.sh

  3) 브라우저 UI에서
       WEBCAM MODE = udp
       SOURCE 이미지 확인 후 START

  4) OBS → 소스 + → 미디어 소스
       "로컬 파일" 체크 해제
       입력: udp://127.0.0.1:27000
       입력 형식: mpegts
       → "가상 카메라 시작"

  5) Zoom / Meet / Teams 에서 카메라를 "OBS Virtual Camera" 로 선택

 자세한 설명과 문제 해결은 README.md 를 참고하세요.
────────────────────────────────────────────────────────────
EOF
