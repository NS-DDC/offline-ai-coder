# Offline Personal AI Coding Agent (Portable)

완전 오프라인, 완전 포터블 개인 AI 코딩 에이전트. 한 폴더에 모델 + 런타임 + 에이전트가 모두 들어있어 USB나 외장 디스크에 담아 어떤 PC로든 옮길 수 있습니다.

## 구성

| 컴포넌트 | 역할 |
|---|---|
| `bin/ollama.exe` | 포터블 LLM 런타임 (설치 불필요) |
| `models/` | 미리 다운로드된 모델 (Qwen2.5-Coder 32B/14B/7B + 임베딩) |
| `.venv/` | Aider 코딩 에이전트 Python venv (타겟 PC에서 생성) |
| `agent.ps1` / `agent.bat` | 실행기 |

## 워크플로우

```
[1. 빌드 PC]                          [2. 타겟 PC]
  build.ps1                              install.ps1
    ↓                                       ↓
  bin/ollama.exe 추출                    bin/ollama.exe 확인
  models/* 모델 다운로드     ─copy─→     .venv 생성 + Aider 설치
                                          ↓
                                       agent.bat
```

## 1단계: 빌드 (소스 PC, 한 번만)

PowerShell에서:

```powershell
cd E:\app_dir\coder
Set-ExecutionPolicy -Scope Process Bypass -Force
.\build.ps1
```

수행 작업:
- `bin/`에 포터블 Ollama 추출 (설치 X)
- `models/`에 Qwen2.5-Coder 32B/14B/7B + nomic-embed-text 다운로드 (~35GB)

완료 후 `E:\app_dir\coder` 폴더 전체를 USB/외장디스크/네트워크로 타겟 PC에 복사.

## 2단계: 설치 (타겟 PC, RTX 3090)

복사한 폴더에서:

```powershell
cd <복사된_경로>\coder
Set-ExecutionPolicy -Scope Process Bypass -Force
.\install.ps1
```

수행 작업:
- 포터블 Ollama 동작 확인
- 모델 로드 확인 (`ollama list`)
- 64-bit Python 3.10~3.12 자동 감지. 없으면 번들된 `installers/python-3.12.7-amd64.exe`로 자동 설치 (UAC 동의창에서 "예" 클릭 필요)
- Python venv 생성 + Aider pip install (인터넷 1회 필요 — Aider 패키지 다운로드용)
- 32B 모델로 추론 테스트

> **참고**: Aider 0.86.x은 Python 3.10~3.12만 지원합니다 (3.13 미지원). 번들된 Python 3.12.7 설치 프로그램이 자동으로 실행됩니다.

## 3단계: 사용

작업할 프로젝트로 이동 후:

```cmd
agent.bat                        :: 32B (최고 품질, RTX 3090 권장)
agent.bat --fast                 :: 14B
agent.bat --tiny                 :: 7B (가장 빠름)
agent.bat src\main.py            :: 특정 파일 작업
agent.bat --model ollama_chat/<other>
```

PATH 등록하면 어디서나 `agent`:

```powershell
$p = [Environment]::GetEnvironmentVariable("Path","User")
[Environment]::SetEnvironmentVariable("Path", "$p;<폴더경로>", "User")
```

## Aider 명령어 (에이전트 내부)

| 명령 | 설명 |
|---|---|
| `/add <file>` | 컨텍스트에 파일 추가 |
| `/drop <file>` | 컨텍스트에서 제거 |
| `/ls` | 컨텍스트 목록 |
| `/diff` | 변경 사항 diff |
| `/undo` | 마지막 커밋 되돌리기 |
| `/run <cmd>` | 셸 명령 실행 (결과를 컨텍스트에 자동 추가) |
| `/test <cmd>` | 테스트 실행 + 실패 시 자동 수정 루프 |
| `/commit` | 수동 커밋 |
| `/clear` | 컨텍스트 초기화 |
| `/help` | 전체 명령 |
| `/exit` | 종료 |

## 사용 예시

```
$ cd my-fastapi-project
$ agent
> 이 프로젝트 전체에 타입 힌트 추가하고 mypy 통과시켜줘
> /add tests/test_users.py
> 테스트 통과하도록 services/user.py 수정
> /test pytest -xvs
```

## VSCode 연동 (옵션)

CLI 외에 IDE도 쓰고 싶을 때. 같은 Ollama 인스턴스 공유:

1. VSCode 확장: **Continue** (`Continue.continue`)
2. `~/.continue/config.json`:
   ```json
   {
     "models": [{
       "title": "Qwen2.5-Coder 32B (Local)",
       "provider": "ollama",
       "model": "qwen2.5-coder:32b",
       "apiBase": "http://localhost:11434"
     }],
     "tabAutocompleteModel": {
       "title": "Qwen Coder 7B (autocomplete)",
       "provider": "ollama",
       "model": "qwen2.5-coder:7b",
       "apiBase": "http://localhost:11434"
     },
     "embeddingsProvider": {
       "provider": "ollama",
       "model": "nomic-embed-text",
       "apiBase": "http://localhost:11434"
     }
   }
   ```

## 트러블슈팅

**"ollama not responding"**
- `agent.bat` 실행 시 자동 재시작 시도. 수동: `taskkill /F /IM ollama.exe` 후 다시.

**OOM 또는 매우 느림 (타겟 PC가 RTX 3090 아닐 때)**
- VRAM 부족. `--fast`(14B) 또는 `--tiny`(7B) 사용.

**한국어 응답이 영어로 나옴**
- 기본값으로 `.aider.conf.yml`에 `chat-language: korean` 설정되어 있음. 영어로 바꾸려면 해당 줄 삭제 또는 `english`로 변경.

**완전 오프라인 확인**
- 서비스 시작 후 인터넷 차단 — Aider/Ollama 모두 localhost만 사용함.
- 텔레메트리는 `.aider.conf.yml`에서 `analytics: false`로 비활성화됨.

**모델 추가**
```cmd
bin\ollama.exe pull deepseek-coder-v2:16b
agent.bat --model ollama_chat/deepseek-coder-v2:16b
```

## 폴더 구조 (배포 후)

```
coder/
  bin/
    ollama.exe          (포터블 런타임, ~600MB)
  models/               (~35GB)
    manifests/
    blobs/
  installers/
    ollama-windows-amd64.zip       (~2GB, 포터블 런타임 zip)
    python-3.12.7-amd64.exe        (~18MB, 오프라인 Python 설치용)
  .venv/                (타겟에서 생성, ~80MB)
  .aider.conf.yml
  build.ps1             (소스 PC용)
  install.ps1           (타겟 PC용)
  uninstall.ps1
  agent.ps1
  agent.bat
  README.md
```

## 제거

```powershell
.\uninstall.ps1
```

또는 폴더 자체 삭제. 시스템에 설치된 것이 없으므로 흔적이 남지 않습니다 (Python winget으로 설치된 경우 별도 제거).

## 라이선스

- 본 스크립트: MIT
- Qwen2.5-Coder: Apache 2.0 (상업 사용 가능)
- Ollama: MIT
- Aider: Apache 2.0
- nomic-embed-text: Apache 2.0
