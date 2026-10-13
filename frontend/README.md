# Docentalk · Flutter Web

AI 도슨트와 작품을 이야기하고 감상을 기록하는 Flutter 웹입니다. 따뜻한 흰색 배경, 선명한 타이포그래피, 불투명한 표면과 작품 중심 편집을 데스크톱·태블릿·모바일에 제공합니다. 반사광·배경 블러·중첩 그림자는 사용하지 않습니다. 페이지 전환은 즉시 이루어져 작품 화면과 읽기 화면이 겹치지 않습니다. 기존 `artlog-mockup.html`은 초기 참고 자료입니다.

서비스 표시 이름은 **Docentalk**입니다. 기존 저장 데이터·빌드·인증 연결을 보존하기 위해 내부 패키지 이름 `artlog_web`, `ARTLOG_DEMO` 환경변수, Firebase 프로젝트와 Vercel 주소는 유지합니다.

## 현재 UI 구성 · 2026-10-14

[루브르 공식 사이트](https://www.louvre.fr/en)의 검은 마스트헤드, 넓은 이미지와 명확한 정보 패널을 참고했습니다. 메인은 작품 3점을 수동 전환하는 전시형 화면, 나머지 화면은 읽기 좋은 밝은 편집 구조입니다. 공통 토큰은 paper `#F8F7F4`, ink `#252823`, muted `#6C7068`, accent `#435247`입니다. 버튼은 8px, 카드·입력은 6~12px의 곡률을 사용하고 그림자·배경 블러·반사광을 제거했습니다.

마이페이지는 공개 감상·취향과 컬렉션, 내 서재는 개인 캘린더·다이어리·저장 대화로 역할을 나눴습니다. 비공개 다이어리는 프로필의 공개 감상에도 표시하지 않습니다. 설정은 `/settings`로 이동했습니다. 피드는 12개씩 불러오며 댓글 수·사용자 팔로우 수 등 서버가 제공하지 않는 수치를 표시하지 않습니다.

모바일은 하단 메뉴로 발견·피드·내 서재·마이페이지에 접근합니다. 서재에서는 날짜·월·탭을 바꿀 때 초안 삭제를 확인합니다. 피드 작성 창도 닫기·뒤로가기에서 초안을 확인하며 기본 공개 범위는 비공개입니다.

최종 Flutter 분석·공백 검사, 전체 테스트 114개, release 웹 빌드를 확인했습니다. [브라우저 검증 화면](verification/editorial/)의 감상은 로컬 미리보기용이며 실제 사용자에게 게시하지 않았습니다. 운영 API·Firebase·TiDB 설정은 이번 디자인 작업에서 변경하지 않았습니다.

## 실행

Flutter stable와 Dart 3.10 이상이 필요합니다. 이번 검증 환경은 Flutter 3.47.2 / Dart 3.13.2입니다. 별도 시스템 Dart가 오래된 경우 `flutter`에 포함된 Dart를 사용하세요.

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

기본 실행은 **미리보기 모드**입니다. 작품 12점과 작가 10명을 포함하고, 좋아요·팔로우·열람 기록은 현재 브라우저에 저장합니다. 도슨트는 준비된 예시 안내를 제공합니다. 서버 연결 없이 목업을 확인할 수 있습니다.

실제 API를 사용하려면:

```bash
flutter run -d chrome --dart-define=ARTLOG_DEMO=false --dart-define=API_BASE_URL=http://localhost:8000
```

`API_BASE_URL`은 서버 루트 또는 `/api`까지의 주소입니다. 비어 있으면 현재 웹사이트와 같은 출처를 사용합니다. Flutter는 `.env`를 자동으로 읽지 않으며 위 값은 빌드 시 결정됩니다. 실제 모드에서 서버 오류가 나면 오류와 재시도를 표시하고 미리보기 데이터로 대체하지 않습니다. API 키나 서버 비밀값을 프론트엔드에 넣지 마세요.

서버 명세는 `docs/api.md`입니다. 운영 배포는 `ARTLOG_DEMO=false`와 `API_BASE_URL=https://skn35-3rd-1team-production.up.railway.app/`로 Railway의 실제 카탈로그를 사용합니다. 좋아요·팔로우·서재·유사 작품과 맞춤 추천, 대화 기록 조회·초기화를 연결했습니다. 도슨트 POST는 승인 문서 검색과 출처 검증을 거쳐 답변을 생성하며, 서버의 AI·검색 설정이 없으면 503 안내를 표시합니다. 인증 전환과 검증 범위는 [엔드포인트 점검표](docs/endpoints.md)를 참고하세요.

## Firebase 로그인 및 Vercel 배포

Firebase는 팀 프로젝트 `skn35-3rd-1team`, Vercel은 `artlog-skn35-1team`을 사용합니다. 이메일/비밀번호 로그인이 활성화되어 있으며 운영 주소는 https://artlog-skn35-1team.vercel.app 입니다. Firebase 웹앱 설정은 Vercel 환경변수에 등록하며 Git에 저장하지 않습니다. 웹 설정은 브라우저용 공개 값이며 서비스 계정·Admin 키와 구분합니다.

```bash
flutter run -d chrome --dart-define-from-file=.dart-defines.local.json
```

로컬 파일은 `firebase.config.example.json`을 복사해 작성합니다. `.dart-defines*.json`은 Git에서 제외되어 있습니다. 설정된 Firebase로 실제 인증을 사용하면서 작품 미리보기를 볼 수 있습니다. 기본 `auto` 모드는 Firebase 웹 설정이 모두 있으면 Firebase를 사용하고, 없으면 기존 로컬 미리보기/API 로그인 동작을 유지합니다.

Vercel에서는 **Root Directory를 `frontend`, Framework Preset을 Other**로 설정합니다. `vercel.json`이 Flutter SDK 준비·빌드·결과 폴더를 지정하므로 기존 React의 npm 빌드를 실행하지 않습니다. 자세한 배포 절차와 서버 담당자 확인 사항은 [Firebase·배포 안내](docs/firebase-vercel.md)에 있습니다.

## 화면과 동작

- 발견하기: 사조·작가 필터, 검색, 정렬, 더 보기, 작품 좋아요. 로그인하면 맞춤 작품·작가 추천과 서버의 추천 이유를 표시합니다.
- 작품 상세: 이미지 확대, 감상 노트·작품 정보·이미지 출처, 비슷한 작품, 작가 팔로우.
- 도슨트: 저장 대화 복원·초기화, 500자 질문과 직전 12개 메시지 전송, 답변·근거 원문·라이선스 표시, 범위 밖 질문 안내, 오류 재시도.
- 작가 이야기: 작가 목록·검색·개별 작품 모음.
- 내 서재: 월별 감상 캘린더, 날짜별 작품 최대 3점 미리보기·전체 보기, 다이어리 공개/비공개, 저장 대화·이어보기.
- 감상 피드: 공개된 감상만 12개씩 불러오며 비공개로 바꾸면 피드에서 제외합니다.
- 마이페이지: 공개한 감상, 내 컬렉션, 좋아요한 그림, 관심 작가, 활동 기록. 개인 다이어리는 내 서재, 감상 설정은 `/settings`로 분리했습니다. 컬렉션 목록을 먼저 보여주며 AI 취향 소개와 채팅은 펼쳐서 사용합니다.
- 피드 작성: 피드 상단에서 오늘의 감상을 작성하고 작품을 연결합니다. 기본은 비공개이며 공개 전환 후 저장하면 피드에 나타납니다. 같은 날짜의 기존 기록은 불러와 수정합니다. 피드의 좋아요·저장은 연결된 작품에 적용합니다.
- 내비게이션: 모바일은 발견·피드·내 서재·마이페이지 하단 메뉴, 데스크톱은 상단 메뉴를 사용합니다.
- Firebase 모드 로그인: 로그인/회원가입 탭, 이메일 로그인·회원가입·비밀번호 재설정과 Google로 계속하기를 제공합니다. 첫 로그인 후 선택형 생년월일·설명 우선순위·대화 스타일 온보딩을 표시하고 마이페이지에서 수정할 수 있습니다. Firebase SDK가 로그인 상태를 복원하며, API 요청마다 ID 토큰을 가져옵니다. 서버 401은 토큰을 갱신해 한 번만 재시도합니다. 이전 목업의 `AUTH_PROVIDER=api` 어댑터는 현재 서버에서 지원하지 않습니다.

실제 모드에서 프로필·다이어리·컬렉션은 인증된 서버 API에 저장합니다. 생년월일은 선택이며 Google에서 나이·성별을 자동 조회하지 않습니다. 도슨트에는 대화 스타일·설명 순서만 반영합니다. 서버 의존성 설치, Alembic `20261014_0008` 적용과 AI·Firebase 설정이 필요합니다. 미리보기는 브라우저에 저장하고 유료 AI를 호출하지 않습니다.

최신 ERD와 프론트의 테이블·API 대응은 [ERD 연결 점검](docs/erd-mapping.md)에 정리했습니다. 반복 감상 횟수와 서로 다른 작품 수, 큐레이터 작품, 문서 원문과 편집 보강 근거를 구분해 표시합니다.

감상 날짜는 서울 기준입니다. 실제 모드의 다이어리는 서버에 저장하며 기본 공개 범위는 비공개입니다. 계정 전환 시 개인 요청의 이전 응답을 무시하고 개인 화면을 초기화합니다. 기존 로컬 메모와 미리보기 기록은 브라우저에 남습니다. 공유 기기에서는 브라우저 사이트 데이터를 삭제해 정리할 수 있습니다. Firebase 모드에서는 계정을 Firebase Authentication으로 관리하며, 기존 서버의 회원가입·토큰 교환 경로는 호출하지 않습니다.

현재 목록 필터·검색·정렬은 불러온 작품 목록을 대상으로 합니다. 현재 서버에는 검색·페이지네이션 API가 없습니다. 작가 상세는 문서의 `artist_id` 필터를 사용합니다. 실제 모드의 유사 작품은 서버 응답 순서를 유지합니다.

## 빌드와 확인

```bash
flutter analyze
flutter test
flutter build web --release
```

빌드 결과는 `build/web/`입니다. 폴더 전체를 정적 웹 서버에 올려 실행합니다. 단일 HTML을 더블클릭하는 방식의 결과물이 아닙니다. 경로는 `/#/gallery`, `/#/artwork/{id}`, `/#/artists`, `/#/artist/{id}`, `/#/library`, `/#/community`, `/#/mypage`, `/#/settings`이며 해시 라우팅으로 새로고침과 직접 진입을 지원합니다. 실제 모드 URL에는 DB의 `id`를 사용하고, 미리보기의 문자열 ID를 서버에 보내지 않습니다.

```bash
flutter build web --release --dart-define=ARTLOG_DEMO=false --dart-define=API_BASE_URL=https://your-api.example
```

API가 다른 출처라면 백엔드에서 웹 출처의 CORS, `Authorization` 헤더와 PUT/DELETE를 허용해야 합니다. HTTPS 웹에서는 HTTPS API를 사용하세요. 하위 경로에 배포할 때는 `--base-href /배포경로/`를 지정합니다. CanvasKit·작품 이미지·폰트는 빌드에 포함합니다.

## 구성

| 경로 | 역할 |
| --- | --- |
| `lib/main.dart` | 앱, 테마, 라우팅 |
| `lib/pages/` | 발견하기·작품·작가·서재 화면 |
| `lib/ui/` | 공통 구성 요소·도슨트 대화 |
| `lib/ui/surfaces.dart`, `lib/ui/app_theme.dart` | 표면·버튼·입력·팝업의 공통 디자인 |
| `lib/api/artlog_api.dart` | HTTP 요청·인증·오류 처리 |
| `lib/models.dart`, `lib/state.dart` | 응답 매핑·상태·로컬 저장 |
| `assets/catalog.json` | 미리보기 전용 데이터 |
| `public/artworks/`, `assets/fonts/` | 작품 이미지·목업 폰트·라이선스 |
| `web/` | Flutter 웹 시작 페이지와 로더 |
| `test/` | 요청 계약·실패 처리·화면 크기별 검증 |
| `docs/endpoints.md` | 실제 서버 계약과 인증 전환 상태 |

## 인수인계

완료 기능, 서버 담당자 후속 작업, 검증 범위와 팀 전달 문구는 [프론트 인수인계](docs/frontend-handoff.md)에 있습니다. 마이페이지·컬렉션·MCP와 운영 적용 조건은 [최신 기능 기록](../docs/mypage-and-collections-2026-10-14.md)을 참고하세요.

## 목업 자료

원본 HTML의 이미지·색상·글꼴을 재사용했습니다. 작품 출처와 이용 조건은 `assets/catalog.json` 및 작품 상세에 있습니다. 폰트는 목업에 포함된 글리프 부분 집합이며, 라이선스 원문은 `assets/fonts/licenses.json`과 앱의 라이선스 화면에 포함했습니다. 실제 서버에 임의의 한글 데이터가 추가되면 해당 글리프의 폰트 확장이 필요할 수 있습니다.

`python3 scripts/prepare_flutter_assets.py /절대경로/artlog-mockup.html`로 Flutter 목업 자료를 다시 추출할 수 있습니다. 기존 React 목업의 `src/`, `package.json`, Vite 관련 파일은 비교·참고용으로 보존했습니다. Flutter 실행에는 Node 설치가 필요하지 않습니다.
