# facefusion-swap

macOS(Apple Silicon)에서 **웹캠 얼굴을 실시간으로 다른 얼굴로 대체**해 화상회의에 내보내는 셋업입니다.
개인정보 보호(얼굴 비노출) 목적이며, 모든 처리는 **로컬에서만** 이루어집니다. 영상이 외부로 전송되지 않습니다.

```
[내장/외장 웹캠]
      │
      ▼
[FaceFusion]  ← CoreML(Apple GPU) 가속으로 얼굴 대체
      │  mpegts over UDP
      ▼
udp://127.0.0.1:27000
      │
      ▼
[OBS 미디어 소스] ──▶ [OBS 가상 카메라]
                            │
                            ▼
                 Zoom / Meet / Teams / Discord
```

---

## ⚠️ 먼저 읽어주세요

- **대체할 얼굴은 반드시 AI 생성 가상 얼굴을 사용하세요.** (예: [thispersondoesnotexist.com](https://thispersondoesnotexist.com))
  실존 인물의 얼굴을 사용하면 초상권 침해·사칭이 되어, "개인정보 보호"라는 목적 자체가 무너집니다.
- 회의 상대에게 **필터/아바타를 쓰고 있다는 사실을 밝히세요.** 신원 확인이 필요한 자리(면접, 계약, KYC, 금융/공공 절차)에서는 사용하지 마세요.
- 업스트림 [FaceFusion](https://github.com/facefusion/facefusion)은 **OpenRAIL-AS** 라이선스로, 동의 없는 인물 묘사·기만 목적 사용을 금지합니다.

---

## 요구사항

| 항목 | 요구사항 |
|---|---|
| 기기 | Apple Silicon Mac (M1 이상). **Intel Mac은 불가** — CoreML 가속이 없어 실시간이 안 나옵니다 |
| OS | macOS 13 Ventura 이상 |
| RAM | 최소 16GB (권장 24GB+) |
| 디스크 | 약 5GB (의존성 + 얼굴 대체 모델) |
| 사전 설치 | [Homebrew](https://brew.sh) |

나머지(ffmpeg, uv, OBS, Python 3.12, FaceFusion 3.8.2)는 `setup.sh`가 전부 알아서 설치합니다.
Python은 **uv**로 관리하므로 시스템 파이썬을 오염시키지 않습니다.

---

## 빠른 시작

```bash
git clone https://github.com/jeamxn/facefusion-swap.git
cd facefusion-swap

./setup.sh        # 최초 1회 (5~10분)

# 대체할 가상 얼굴 1장 준비 (AI 생성 얼굴)
curl -L https://thispersondoesnotexist.com/random-person.jpeg -o faces/synthetic.jpg

./run.sh          # 실행
```

`run.sh`가 브라우저에서 <http://127.0.0.1:7860> 을 엽니다.

> **반드시 터미널 앱(Terminal / iTerm)에서 직접 실행하세요.**
> macOS는 카메라 접근을 실행 주체별로 허가합니다. 스크립트·자동화 도구로 간접 실행하면
> `OpenCV: not authorized to capture video` 가 뜨고 카메라 목록이 비어 있게 됩니다.
> 처음 실행할 때 뜨는 카메라 접근 허용 창에서 **허용**을 누르세요.

---

## 사용법

### 1. FaceFusion 웹캠 UI

| 설정 | 값 |
|---|---|
| **SOURCE** | `faces/`의 이미지가 자동으로 로드됨 (`run.sh`가 주입) |
| **WEBCAM DEVICE** | 사용할 카메라 (보통 `0`) |
| **WEBCAM MODE** | **`udp`** ← OBS로 넘기려면 반드시 udp |
| **WEBCAM RESOLUTION** | `640x480` 로 시작 (잘 돌면 `1280x720`) |
| **WEBCAM FPS** | `30` |

**START** 버튼을 누르면 UDP 송출이 시작됩니다.

> `inline` 모드는 브라우저 안에서만 미리보기 되고 OBS로 넘어가지 않습니다. 화질/딜레이 확인용으로만 쓰세요.
> `v4l2`는 리눅스 전용이라 macOS에서는 동작하지 않습니다.

### 2. OBS 설정 (최초 1회)

1. OBS 실행 → **소스** 패널 `+` → **미디어 소스** → 이름 지정 후 확인
2. 속성 창에서
   - **로컬 파일** 체크 **해제**
   - **입력**: `udp://127.0.0.1:27000`
   - **입력 형식**: `mpegts`
   - **파일이 재생되지 않을 때 다시 연결** 체크 (권장)
3. 확인 → 미리보기에 대체된 얼굴이 뜨는지 확인
4. **제어** 패널 → **가상 카메라 시작**
   - 처음 실행 시 macOS가 시스템 확장 승인을 요구합니다.
     `시스템 설정 → 개인정보 보호 및 보안` 에서 허용 후 OBS 재시작

### 3. 회의 앱

Zoom / Google Meet / Teams / Discord 의 카메라 설정에서 **`OBS Virtual Camera`** 를 선택합니다.
회의 앱이 이미 켜져 있었다면 **완전히 종료 후 재실행**해야 목록에 나타납니다.

---

## 성능 튜닝

M4 Pro 기준 대략적인 실측 감각입니다. 칩 등급에 따라 달라집니다.

| 해상도 | 예상 FPS | 체감 |
|---|---|---|
| 320x240 | 30 | 아주 부드러움, 화질 낮음 |
| 640x480 | 25~30 | **권장 기본값** |
| 1280x720 | 15~22 | 화질 좋음, 약간의 딜레이 |
| 1920x1080 | 8~12 | 회의용으로는 비권장 |

느릴 때 순서대로 시도하세요.

1. 해상도를 한 단계 낮춘다 (가장 효과 큼)
2. WEBCAM FPS를 24로 낮춘다
3. 스레드 수 조정 — `FF_THREADS=4 ./run.sh`
4. 다른 앱(브라우저 탭, Docker 등)을 정리해 GPU를 비운다

### 환경변수

| 변수 | 기본값 | 설명 |
|---|---|---|
| `FF_SOURCE` | `faces/` 의 첫 이미지 | 대체할 얼굴 이미지 경로 |
| `FF_THREADS` | `8` | 추론 스레드 수 |
| `FF_EXTRA` | – | FaceFusion에 그대로 넘길 추가 인자 |

```bash
FF_SOURCE=~/Pictures/avatar.png FF_THREADS=4 ./run.sh
FF_EXTRA="--face-swapper-model inswapper_128_fp16" ./run.sh
```

---

## 문제 해결

**카메라 목록이 `none` 이거나 `OpenCV: not authorized to capture video` 가 뜹니다**
터미널에 카메라 권한이 없습니다. `시스템 설정 → 개인정보 보호 및 보안 → 카메라` 에서 사용 중인 터미널 앱(Terminal / iTerm / VS Code)을 허용하고 **터미널을 완전히 종료 후 재실행**하세요.
목록에 터미널 앱이 아예 없다면, 터미널에서 `./run.sh` 를 한 번 실행해 권한 요청을 발생시킨 뒤 다시 확인하면 됩니다.

**OBS 미디어 소스가 검은 화면입니다**
- FaceFusion에서 **START** 를 눌렀는지, MODE가 `udp` 인지 확인
- 포트 점유 확인: `lsof -nP -iUDP:27000`
- OBS 미디어 소스를 우클릭 → 새로고침

**첫 실행에서 START를 눌렀는데 한참 멈춰 있습니다**
얼굴 대체 모델을 내려받는 중입니다(약 2GB, 최초 1회). 터미널에 다운로드 진행률이 표시됩니다.
오프라인 환경에서 미리 전부 받아두려면 `FF_PREFETCH=1 ./setup.sh` 로 설치하세요. 다만 다른 프로세서(나이 변조, 립싱크 등) 모델까지 받아 8GB 이상을 사용합니다.

**`CoreMLExecutionProvider를 찾지 못했습니다` 경고**
CPU로 동작하게 되어 매우 느립니다. Apple Silicon이 맞는지(`uname -m` → `arm64`) 확인하고 `./setup.sh` 를 다시 실행하세요.

**OBS 없이 바로 가상 카메라로 잡히게 할 수는 없나요?**
불가능합니다. macOS에서 가상 카메라를 만들려면 시스템 확장(Camera Extension)이 필요하고, 그 확장은 Apple Developer 서명이 있어야 배포됩니다.
이 저장소는 OBS가 제공하는 확장(`com.obsproject.obs-studio.mac-camera-extension`)을 빌려 쓰는 구조라 OBS 실행이 필수입니다.
파이썬에서 직접 송출하는 `pyvirtualcam` 계열은 구형 DAL 플러그인에 의존하는데, macOS 12.3에서 폐기되어 최신 OBS에는 포함되지 않습니다.
OBS 설정은 최초 1회만 하면 다음 실행부터 그대로 유지되며, OBS는 최소화해두고 쓰면 됩니다.

**설치를 처음부터 다시 하고 싶습니다**
```bash
rm -rf .venv vendor
./setup.sh
```

**모델까지 포함해 완전히 지우고 싶습니다**
모델은 `vendor/facefusion/.assets/models/` 안에 받아지므로, 위의 `rm -rf vendor` 로 함께 지워집니다.
다시 받는 데 시간이 걸리니 의존성만 재설치할 때는 `.venv` 만 지우세요.

---

## 저장소 구조

```
facefusion-swap/
├── setup.sh      # 의존성 설치 + FaceFusion 3.8.2 고정 + uv 환경 구성 + 모델 사전 다운로드
├── run.sh        # CoreML 가속으로 웹캠 UI 실행
├── faces/        # 대체할 얼굴 이미지 (커밋되지 않음)
├── vendor/       # FaceFusion 소스 (setup.sh가 생성, 커밋되지 않음)
└── .venv/        # uv 가상환경 (커밋되지 않음)
```

`faces/` 는 `.gitignore` 되어 있습니다. 얼굴 이미지는 절대 커밋하지 마세요.

---

## 라이선스

이 저장소의 스크립트는 MIT.
FaceFusion 본체는 [OpenRAIL-AS](https://github.com/facefusion/facefusion/blob/master/LICENSE.md) 를 따르며, 사용 제한 조항이 적용됩니다.
