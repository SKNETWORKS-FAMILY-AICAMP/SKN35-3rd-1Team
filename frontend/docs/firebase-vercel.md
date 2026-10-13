# Firebase Authentication · Vercel

최신 프론트 연결·검증과 Railway 담당자 인계는 [2026-10-13 인수인계](frontend-handoff.md)를 참고하세요. 아래 2026-10-12 배포·서버 검증 기록은 당시 결과입니다.

## 프로젝트

- Firebase: `skn35-3rd-1team`, 웹앱 `Artlog Web`.
- Vercel: `artlog-skn35-1team`, `SEUNGHEE LEE’s projects` 계정.
- 앱은 Flutter Web이며 서버는 FastAPI·TiDB입니다. 최신 dev를 lsh에 병합하고 Firebase 서버 토큰 검증도 구현했습니다.

## Firebase 설정

2026-10-12 팀 Firebase 콘솔에서 Authentication을 초기화하고 이메일/비밀번호 공급자를 활성화했습니다. 다른 프로젝트를 새로 연결하는 경우에도 Authentication의 **시작하기**와 이메일/비밀번호 활성화가 필요합니다. 당시에는 Google·전화·익명 로그인과 Firestore를 사용하지 않았습니다. 2026-10-13 추가 요청으로 Google SDK 로그인·온보딩을 구현했습니다. 최신 상태는 인수인계를 참고합니다. 비밀번호 재설정 메일은 Firebase가 발송합니다.

승인된 도메인은 `localhost`, `skn35-3rd-1team.firebaseapp.com`, `skn35-3rd-1team.web.app`, `artlog-skn35-1team.vercel.app`입니다. 로컬에서 `127.0.0.1`을 사용할 경우 해당 도메인을 추가하거나 `localhost`를 사용합니다. 미리보기마다 달라지는 도메인을 와일드카드로 열지 말고 필요한 도메인만 등록합니다. 서비스 계정 키·Firebase Admin SDK·백엔드 비밀값은 프론트엔드에 넣지 않습니다.

Firebase SDK는 LOCAL persistence로 로그인 상태를 복원합니다. 앱이 ID 토큰·비밀번호를 SharedPreferences에 별도 저장하지 않습니다. 미리보기 좋아요·팔로우·열람·감상 메모는 Firebase UID별로 브라우저에 저장하며 로그아웃할 때 화면의 개인 기록을 초기화합니다. 다른 브라우저와 동기화되지 않습니다.

## 빌드 환경변수

| 변수 | 값 / 역할 |
| --- | --- |
| `AUTH_PROVIDER` | `firebase` |
| `ARTLOG_DEMO` | `false`: Railway 실제 API 사용 |
| `FIREBASE_API_KEY` | Firebase 웹앱 apiKey |
| `FIREBASE_APP_ID` | Firebase 웹 appId |
| `FIREBASE_MESSAGING_SENDER_ID` | 웹앱 messagingSenderId |
| `FIREBASE_PROJECT_ID` | `skn35-3rd-1team` |
| `FIREBASE_AUTH_DOMAIN` | `skn35-3rd-1team.firebaseapp.com` |
| `API_BASE_URL` | `https://skn35-3rd-1team-production.up.railway.app/` |

`firebase.config.example.json`을 참고합니다. 공개 웹앱 설정은 Vercel 환경변수에서 주입하며 생성된 `.dart-defines*.json` 파일은 Git·배포 소스에서 제외합니다. 빌드 스크립트는 위의 허용된 값만 읽으므로 배포 계정 토큰·서비스 계정 키를 번들에 넣지 않습니다. Firebase 모드 필수 값이 없거나 실제 API 모드의 HTTPS 서버 주소가 없으면 빌드를 중단합니다.

## Vercel 배포

Git 저장소를 Vercel에 연결할 경우 Root Directory는 `frontend`, Framework는 Other로 지정합니다. 배포할 Git 분기는 `lsh`로 선택합니다. `vercel.json`에서 install/build/output을 지정해 예전 React 목업 빌드와 구분합니다. GitHub 조직의 Vercel 앱 설치 권한이 없다면 관리자가 별도로 연결해야 합니다.

```bash
cd frontend
vercel link --project artlog-skn35-1team --scope seunghee-lees-projects-93a5a524
vercel project inspect --non-interactive
vercel deploy --prod
```

CLI로 `frontend/` 자체를 올릴 때 프로젝트 Root Directory는 `.`를 사용합니다. Git 연동의 저장소 Root Directory와 혼동하지 마세요. 현재 연결 방식은 배포 결과 기록을 참고합니다.

원격 빌드는 Flutter 3.47.2를 사용하며 SDK 캐시는 `.vercel/cache/flutter`에 둡니다. `scripts/vercel-install.sh`가 공식 Flutter 저장소에서 해당 버전을 준비하고 lockfile로 의존성을 설치합니다. Vercel 캐시에서 SDK의 `.git`이 빠지거나 불완전하면 공식 SDK를 다시 받아 메타데이터를 복구하고, 이미 내려받은 `bin/cache` 자료는 유지합니다. PATH에서 발견되는 다른 SDK 대신 이 프로젝트의 SDK를 사용합니다. `scripts/vercel-build.sh`가 허용된 공개 설정을 작성하고 `build/web`을 빌드합니다.

해시 라우팅을 사용해 별도 catch-all rewrite가 필요 없습니다. `/api/*`를 index.html로 돌리지 않아 실제 API 부재를 숨기지 않습니다. 시작 문서와 부트스트랩은 no-cache로 설정합니다.

## API 전환

서버는 `AUTH_MODE=firebase`일 때 Admin SDK로 ID 토큰을 검증하고 UID를 TiDB 사용자에 매핑합니다. JSON 비밀 환경변수 `FIREBASE_SERVICE_ACCOUNT_JSON` 또는 서버 파일 경로 `GOOGLE_APPLICATION_CREDENTIALS`, 프로젝트 ID `skn35-3rd-1team`이 필요합니다. 로컬 `.env`의 파일 경로도 지원합니다. 서버 키는 프론트엔드에 넣지 않습니다.

Railway는 아직 `AUTH_MODE=dev`입니다. Railway 담당자가 dev 병합·배포와 서버 인증 정보 설정을 마친 뒤 `firebase`로 전환합니다. 그 전에는 로그인 사용자의 서버 기록이 개발 사용자 한 명에게 모입니다. 상세 경로와 기능별 준비 상태는 [엔드포인트 점검표](endpoints.md)를 참고하세요.

## 검증

`flutter analyze`, `flutter test`, `node --test scripts/*.test.mjs`, Firebase 설정을 포함한 release 빌드로 확인합니다. 로그인 화면은 모바일 크기와 계정 분리·로그아웃·복원·토큰 갱신을 테스트합니다. 실제 운영 계정의 비밀번호 재설정은 테스트를 위해 실행하지 않습니다.


## 이전 미리보기 배포 기록

2026-10-12 운영 배포 `dpl_2ASeA6t6aXAcTfsYsY3xTLcLZz9E`가 READY 상태입니다. 주소는 https://artlog-skn35-1team.vercel.app 이며 프론트엔드 폴더만 CLI로 업로드했습니다. 최종 빌드는 약 3분 소요됐습니다. Git 자동 배포는 아직 연결하지 않았습니다. 현재 프로젝트 Root Directory는 `.`이며, Git 자동 배포를 설정할 경우에만 `frontend`로 바꾸어야 합니다.

Firebase 이메일/비밀번호 활성화, 웹앱 등록, 운영 도메인 추가와 Vercel의 Production·Preview·Development 환경변수 교체를 완료했습니다. Firebase Auth REST API로 임시 계정 가입 → 비밀번호 로그인 → 계정 조회를 확인했으며, 같은 실행의 `finally` 단계에서 즉시 삭제했습니다. 테스트 비밀번호와 토큰은 파일에 저장하거나 출력하지 않았습니다. 브라우저의 로그인 복원·계정별 기록 분리는 자동 테스트의 가짜 세션으로 검증했으며 실제 계정의 브라우저 복원 성공과 구분합니다.

운영 번들의 프로젝트 ID·웹앱 ID가 팀 설정과 일치하며, 운영 브라우저에서 존재하지 않는 계정의 로그인 요청 후 한국어 오류 안내가 표시되는 것을 확인했습니다. 해당 브라우저 검사에서 콘솔 오류·경고는 없었습니다. 실제 사용자 계정의 비밀번호나 재설정 메일은 검증에 사용하지 않았습니다.


## 이전 실제 API·Firebase 서버 검증 (2026-10-12)

Vercel Production·Preview·Development의 `API_BASE_URL`을 Railway 주소로, `ARTLOG_DEMO`를 `false`로 변경했습니다. 실제 카탈로그는 사조 4개·작가 8명·작품 219점입니다. 도슨트·유사 작품·맞춤 추천은 아직 서버가 501을 반환합니다. 도슨트는 준비 중 안내를, 유사 작품은 조회 실패 안내를 표시합니다.

승인받아 Firebase 서비스 계정 키를 발급하고 로컬의 Git 제외 `.secrets/firebase-admin.json`에 파일 권한 600으로 보관했습니다. `.env`도 Git 제외 및 권한 600이며 TiDB 설정과 로컬 서버 키 경로만 들어 있습니다. 관리자 키·TiDB 비밀번호·ID 토큰을 Git 또는 Vercel 번들에 넣지 않았습니다.

실제 Firebase 임시 계정 두 개를 가입·비밀번호 로그인해 유효 시간 3600초의 ID 토큰을 발급했습니다. 로컬 FastAPI를 `AUTH_MODE=firebase`로 실행하고 실제 Admin SDK 및 실제 TiDB를 사용해 다음을 확인했습니다.

- 각 토큰의 프로젝트와 UID 검증, 서로 다른 TiDB 사용자 두 행 생성, 반복 요청 시 기존 사용자 재사용.
- A 계정의 좋아요·팔로우·열람·캘린더·날짜별 서재 저장 및 조회. B 계정에는 A 기록이 표시되지 않음.
- 변조한 토큰과 토큰 없는 보호 경로 요청은 401.
- 검증 실행의 `finally`에서 임시 Firebase 계정 및 해당 UID의 TiDB 사용자·활동 행을 모두 삭제 완료.

비밀번호·토큰은 메모리에서만 사용하고 출력·파일 저장하지 않았습니다. 실제 운영 Railway의 인증 전환은 담당자가 dev 병합·배포 후 진행해야 하며 위 결과는 새 서버 코드를 로컬에서 실제 외부 서비스에 연결한 검증입니다.

자동 검증: 백엔드 153개, Flutter 43개, 배포 스크립트 4개 통과. Flutter 분석과 변경한 Python 파일의 Ruff 검사도 통과했습니다.


운영 Vercel 배포 `dpl_9w8mf8ZQtZo4Vhqnh3YyXWAKBBMP`가 READY이며 `https://artlog-skn35-1team.vercel.app`에 연결되었습니다. 빌드 로그에서 `catalog=API, auth=firebase`를 확인했습니다. 공개 작품 이미지의 중간 리디렉션에 CORS 헤더가 없어 CanvasKit 로딩이 실패하는 경우 Flutter의 HTML 이미지 표시 fallback을 사용합니다. Git 자동 배포는 아직 연결하지 않았습니다.

### Railway 담당자 인계

Railway는 팀의 별도 담당자가 운영합니다. 이번 작업에서 해당 콘솔 설정이나 `AUTH_MODE`를 변경하지 않았습니다. 담당자는 lsh의 서버 변경을 dev로 병합·배포한 뒤 `FIREBASE_PROJECT_ID=skn35-3rd-1team`, 서버용 서비스 계정 인증 정보, `AUTH_MODE=firebase`를 설정해야 합니다. 새 키는 로컬 `.secrets/firebase-admin.json`에만 있으며 담당자에게는 비밀값을 안전하게 전달하는 팀 방식으로 공유합니다. 키 원문을 GitHub·일반 채팅·Vercel에 붙이지 않습니다.

운영 브라우저에서 실제 카탈로그 219점·숫자 ID의 작품 상세와 작품 이미지 표시를 확인했습니다. 도슨트 질문은 서버의 501 응답에 준비 중 안내를 표시합니다. 검증 화면은 [실제 API 작품 상세](../verification/api-artwork-production.jpg)에 있습니다.
