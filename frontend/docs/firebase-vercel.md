# Firebase 인증과 Vercel 배포

갱신: **2026-10-15 · dev `6f0b40a` 기준**. 현재 Flutter 코드와 확인된 배포 기록을 정리했습니다. 과거 설정·테스트 이력은 [검증 기록](../verification/README.md)에 있습니다.

## 프로젝트와 주소

| 항목 | 현재 대상 |
| --- | --- |
| 서비스 표시 이름 | Docentalk |
| Firebase 프로젝트 | `skn35-3rd-1team` |
| Vercel 프로젝트 | `artlog-skn35-1team` |
| Vercel scope | `seunghee-lees-projects-93a5a524` |
| 운영 웹 | https://artlog-skn35-1team.vercel.app |
| 백엔드 API | https://skn35-3rd-1team-production.up.railway.app/ |

프로젝트 이름과 내부 `artlog_web` 패키지는 기존 연결 호환성을 위해 유지합니다. Railway는 팀 백엔드 담당자가 운영하며 프론트 배포와 별개입니다.

## Firebase 로그인

이메일·비밀번호와 Google 로그인 공급자를 사용합니다. Flutter의 `FirebaseSession`이 이메일 가입/로그인·재설정, 웹 Google 팝업, LOCAL 세션 복원과 ID 토큰 갱신을 처리합니다. Google 첫 이용도 같은 “Google로 계속하기” 버튼을 사용합니다.

현재 UI는 로그인/회원가입 대화상자입니다. 생년월일·성별 입력 온보딩은 현재 노출되지 않으며 Google에서 해당 정보를 자동으로 가져오지 않습니다. 팝업 차단·취소·미승인 도메인·공급자 오류는 한국어로 안내합니다.

운영 도메인 `artlog-skn35-1team.vercel.app`과 Firebase 기본 도메인을 프로젝트의 승인 도메인에서 유지합니다. 로컬 개발은 등록된 `localhost`를 사용합니다. 새 도메인은 실제 사용 주소를 등록하고 미리보기 주소 전체를 와일드카드로 허용하지 않습니다.

## 빌드 환경변수

| 키 | 운영 값 또는 역할 |
| --- | --- |
| `ARTLOG_DEMO` | `false`, 실제 API·서버 저장 |
| `AUTH_PROVIDER` | `firebase` |
| `API_BASE_URL` | 위 Railway HTTPS 주소 |
| `FIREBASE_API_KEY` | Firebase 공개 웹앱 apiKey |
| `FIREBASE_APP_ID` | 공개 웹 appId |
| `FIREBASE_MESSAGING_SENDER_ID` | 공개 senderId |
| `FIREBASE_PROJECT_ID` | `skn35-3rd-1team` |
| `FIREBASE_AUTH_DOMAIN` | `skn35-3rd-1team.firebaseapp.com` |

`write-build-defines.mjs`는 위 허용된 값만 `.dart-defines.vercel.json`에 작성합니다. Firebase 필수 값이 없거나 실제 API 모드 주소가 HTTPS가 아니면 빌드에 실패합니다. 스크립트의 기본 `ARTLOG_DEMO`는 true이므로 운영 값 false를 명시해야 합니다.

공개 웹앱 설정과 서버 관리자 인증 정보는 다릅니다. `VERCEL_TOKEN`, 서비스 계정 JSON, TiDB 비밀번호, OpenAI·Chroma 키를 프론트 설정에 넣지 않습니다. `.dart-defines*.json`, `.env*`, Firebase 디버그 로그는 Git·업로드에서 제외합니다.

### 로컬 설정

```bash
cd frontend
cp firebase.config.example.json .dart-defines.local.json
# 실제 공개 웹 설정, ARTLOG_DEMO=false, API_BASE_URL을 작성합니다.
flutter pub get --enforce-lockfile
flutter run -d chrome --dart-define-from-file=.dart-defines.local.json
flutter build web --release --dart-define-from-file=.dart-defines.local.json
```

환경값은 빌드 시 주입됩니다. Vercel 환경변수만 수정하면 이미 배포된 번들은 바뀌지 않으므로 재배포해야 합니다. `AUTH_PROVIDER=auto`는 Firebase 웹 설정이 모두 있으면 Firebase를 사용하고, 기본 미리보기에는 설정 없이 실행할 수 있습니다.

## Vercel 빌드 구조

`frontend/vercel.json`이 Flutter 설치·빌드·출력을 지정합니다.

- Framework: Other (`framework: null`)
- Install: `bash scripts/vercel-install.sh`
- Build: `bash scripts/vercel-build.sh`
- Output: `build/web`
- SDK: Flutter 3.47.2 고정, lockfile 의존성 설치
- SDK 캐시의 Git 메타데이터가 없으면 공식 Flutter 저장소에서 복구
- 시작 문서·bootstrap·JS·manifest·version은 no-cache 헤더

CLI로 **frontend 폴더 자체**를 업로드하는 현재 방식의 프로젝트 Root Directory는 `.`입니다. 향후 Git 저장소 전체를 연결할 때만 Root Directory를 `frontend`로 지정합니다. 두 방식을 섞으면 폴더를 찾지 못하거나 이전 React 목업을 빌드할 수 있습니다. 기존 프로젝트에는 자동으로 새 링크를 만들지 말고 대상·owner를 먼저 확인합니다.

```bash
cd frontend
vercel project inspect --non-interactive
# artlog-skn35-1team / SEUNGHEE LEE's projects / Root Directory . 확인
vercel deploy --prod --yes
vercel inspect https://artlog-skn35-1team.vercel.app
vercel logs https://artlog-skn35-1team.vercel.app --level error --since 5m --no-follow
```

최신 dev만 배포할 때는 해당 커밋의 `frontend/`를 별도 폴더로 준비하고 검증된 기존 `.vercel/project.json`을 연결 정보로 사용합니다. 로컬 lsh의 추가 변경을 섞지 않습니다. Git push가 곧 Vercel 운영 배포라는 가정은 하지 않습니다.

## 최신 확인된 배포

2026-10-15 배포 ID **`dpl_5sQdELnnHxruyhUyMbjnzbnNnTf7`**, 대상 Production, 상태 **READY**, 소스 dev **`af7cea8`**입니다. 운영 별칭 연결과 실제 작품 277점, 브라우저 오류 없음, Vercel 오류 로그 레코드 없음을 확인했습니다. 최신 dev `6f0b40a`와 프론트 트리는 동일하고 이후 dev 변경은 평가 문서입니다.

이 기록은 당시 확인 결과입니다. 이번 Markdown 갱신으로 새 배포나 설정 변경을 수행하지 않습니다. Firebase 개인 계정별 데이터 격리·MCP 쓰기 전체 성공을 이 배포 확인만으로 주장하지 않습니다.

## 서버 담당자 확인 사항

- Firebase Admin `verify_id_token` 검증과 프로젝트 ID `skn35-3rd-1team`. `AUTH_MODE=dev`에서는 사용자 기록이 개발 계정으로 합쳐질 수 있으므로 운영 Firebase 모드를 확인합니다.
- 서버 인증 정보는 서버의 `FIREBASE_SERVICE_ACCOUNT_JSON` 또는 마운트 파일 `GOOGLE_APPLICATION_CREDENTIALS`로 제공합니다. 로컬 경로가 Railway에도 있다고 가정하지 않습니다.
- DB는 최신 Alembic `20261014_0011`까지 적용해야 합니다. 운영 적용 여부는 서버에서 별도 확인합니다.
- RAG·AI 환경변수와 Chroma 연결, 운영 웹 출처 CORS·Authorization·POST/PUT/DELETE·SSE 스트리밍을 확인합니다.
- 운영 도메인에서 두 승인 테스트 계정으로 대화·감상·컬렉션·팔로우 소유권을 확인합니다. 프론트의 계정 변경 방어와 서버 권한 검사는 별개입니다.

## 검증과 복구

배포 후 로딩 로고·파비콘, 작품/작가·김홍도/정선 이미지, 채팅 최초 텍스트·최종 출처, 로그인·감상·컬렉션 주요 경로를 확인합니다. 이번 컬렉션 회귀 테스트를 실행하고 과거 전체 테스트 수와 구분합니다.

배포 문제가 있으면 Vercel에서 이전 READY 배포를 확인한 뒤 해당 URL/ID로 rollback합니다. 환경변수·서버 DB 변경은 프론트 rollback으로 복구되지 않습니다. 프론트·백엔드 담당자가 각각 변경 범위를 확인해야 합니다.
