# Firebase Authentication · Vercel

## 프로젝트

- Firebase: `skn35-3rd-1team`, 웹앱 `Artlog Web`.
- Vercel: `artlog-skn35-1team`, `SEUNGHEE LEE’s projects` 계정.
- 앱은 Flutter Web이며 이번 코드 변경은 `frontend/`에만 있습니다. 최신 dev 반영은 Git 병합으로 수행합니다.

## Firebase 설정

2026-10-12 팀 Firebase 콘솔에서 Authentication을 초기화하고 이메일/비밀번호 공급자를 활성화했습니다. 다른 프로젝트를 새로 연결하는 경우에도 Authentication의 **시작하기**와 이메일/비밀번호 활성화가 필요합니다. Google·전화·익명 로그인과 Firestore는 사용하지 않습니다. 비밀번호 재설정 메일은 Firebase가 발송합니다.

승인된 도메인은 `localhost`, `skn35-3rd-1team.firebaseapp.com`, `skn35-3rd-1team.web.app`, `artlog-skn35-1team.vercel.app`입니다. 로컬에서 `127.0.0.1`을 사용할 경우 해당 도메인을 추가하거나 `localhost`를 사용합니다. 미리보기마다 달라지는 도메인을 와일드카드로 열지 말고 필요한 도메인만 등록합니다. 서비스 계정 키·Firebase Admin SDK·백엔드 비밀값은 프론트엔드에 넣지 않습니다.

Firebase SDK는 LOCAL persistence로 로그인 상태를 복원합니다. 앱이 ID 토큰·비밀번호를 SharedPreferences에 별도 저장하지 않습니다. 미리보기 좋아요·팔로우·열람·감상 메모는 Firebase UID별로 브라우저에 저장하며 로그아웃할 때 화면의 개인 기록을 초기화합니다. 다른 브라우저와 동기화되지 않습니다.

## 빌드 환경변수

| 변수 | 값 / 역할 |
| --- | --- |
| `AUTH_PROVIDER` | `firebase` |
| `ARTLOG_DEMO` | 현재 `true`: 서버 API가 준비될 때까지 작품 미리보기 |
| `FIREBASE_API_KEY` | Firebase 웹앱 apiKey |
| `FIREBASE_APP_ID` | Firebase 웹 appId |
| `FIREBASE_MESSAGING_SENDER_ID` | 웹앱 messagingSenderId |
| `FIREBASE_PROJECT_ID` | `skn35-3rd-1team` |
| `FIREBASE_AUTH_DOMAIN` | `skn35-3rd-1team.firebaseapp.com` |
| `API_BASE_URL` | 실제 API 모드 전환 시 HTTPS 서버 주소 |

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

백엔드가 Firebase ID 토큰을 검증하고 UID를 내부 사용자에 매핑해야 합니다. 이메일 로그인에 성공했다고 기존 FastAPI JWT와 호환되는 것은 아닙니다. 서버 담당자에게 [엔드포인트 점검표](endpoints.md)의 Firebase 인증 항목을 전달하세요. 서버 구현은 이번 작업 범위에 포함하지 않았습니다.

## 검증

`flutter analyze`, `flutter test`, `node --test scripts/*.test.mjs`, Firebase 설정을 포함한 release 빌드로 확인합니다. 로그인 화면은 모바일 크기와 계정 분리·로그아웃·복원·토큰 갱신을 테스트합니다. 실제 운영 계정의 비밀번호 재설정은 테스트를 위해 실행하지 않습니다.


## 현재 배포 결과

2026-10-12 운영 배포 `dpl_2ASeA6t6aXAcTfsYsY3xTLcLZz9E`가 READY 상태입니다. 주소는 https://artlog-skn35-1team.vercel.app 이며 프론트엔드 폴더만 CLI로 업로드했습니다. 최종 빌드는 약 3분 소요됐습니다. Git 자동 배포는 아직 연결하지 않았습니다. 현재 프로젝트 Root Directory는 `.`이며, Git 자동 배포를 설정할 경우에만 `frontend`로 바꾸어야 합니다.

Firebase 이메일/비밀번호 활성화, 웹앱 등록, 운영 도메인 추가와 Vercel의 Production·Preview·Development 환경변수 교체를 완료했습니다. Firebase Auth REST API로 임시 계정 가입 → 비밀번호 로그인 → 계정 조회를 확인했으며, 같은 실행의 `finally` 단계에서 즉시 삭제했습니다. 테스트 비밀번호와 토큰은 파일에 저장하거나 출력하지 않았습니다. 브라우저의 로그인 복원·계정별 기록 분리는 자동 테스트의 가짜 세션으로 검증했으며 실제 계정의 브라우저 복원 성공과 구분합니다.

운영 번들의 프로젝트 ID·웹앱 ID가 팀 설정과 일치하며, 운영 브라우저에서 존재하지 않는 계정의 로그인 요청 후 한국어 오류 안내가 표시되는 것을 확인했습니다. 해당 브라우저 검사에서 콘솔 오류·경고는 없었습니다. 실제 사용자 계정의 비밀번호나 재설정 메일은 검증에 사용하지 않았습니다.
