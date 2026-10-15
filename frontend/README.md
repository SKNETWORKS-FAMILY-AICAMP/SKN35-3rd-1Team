# Docentalk · Flutter Web

작품을 탐색하고 AI 도슨트와 대화하며 감상을 기록하는 Flutter 웹 서비스입니다.

- 운영 사이트: https://artlog-skn35-1team.vercel.app
- 문서 갱신: **2026-10-15 · dev `6f0b40a` 코드 기준**, lsh 반영
- 실행 앱: `lib/`의 Flutter 단일 앱입니다. 초기 React·Vite 소스와 npm 의존성·목업 export는 제거했습니다.
- 서비스 이름은 Docentalk입니다. 호환성을 위해 내부 패키지 `artlog_web`, `ARTLOG_DEMO`, Firebase·Vercel 프로젝트 이름은 유지합니다.

## 빠른 실행

배포 스크립트에 고정된 Flutter **3.47.2**를 권장합니다. `pubspec.yaml`의 Dart 범위는 `>=3.10.0 <4.0.0`이며 배포 SDK에는 Dart 3.13.2가 포함됩니다.

```bash
cd frontend
flutter pub get --enforce-lockfile
flutter run -d chrome
```

기본값 `ARTLOG_DEMO=true`, `AUTH_PROVIDER=auto`에서는 로컬 작품 12점·작가 10명의 미리보기를 제공합니다. 좋아요·열람·감상·컬렉션은 브라우저 저장이며 실제 AI 생성·공개 게시로 간주하지 않습니다.

실제 API와 Firebase 인증을 사용하려면 Git 제외 설정 파일을 준비합니다.

```bash
cp firebase.config.example.json .dart-defines.local.json
# 공개 Firebase 웹 설정을 채우고 ARTLOG_DEMO=false 및 API_BASE_URL을 추가합니다.
flutter run -d chrome --dart-define-from-file=.dart-defines.local.json
```

`API_BASE_URL`은 서버 루트 또는 `/api`까지의 주소입니다. 실제 서비스 주소는 `https://skn35-3rd-1team-production.up.railway.app/`입니다. Flutter는 `.env`를 자동으로 읽지 않으며 환경값 변경 후 다시 빌드해야 합니다. 필수 공개 설정과 배포 방법은 [Firebase·Vercel 안내](docs/firebase-vercel.md)를 참고하세요.

## 현재 화면과 기능

경로 앞에 `/#`가 붙는 해시 라우팅을 사용합니다. Firebase 로그인·회원가입은 별도 페이지가 아닌 대화상자로 열립니다.

| 화면·경로 | 현재 동작 |
| --- | --- |
| 발견하기 `/gallery` | 오늘의 그림 3점 수동 전환, 전시형 작품 모음, 작가 소개, 로그인 후 맞춤 작품·작가 추천 |
| 작품 리스트 `/artworks` | 제목·작가 검색, 사조 필터, 그림/작가 탭, 더 보기, 하트 |
| 작가 리스트 `/artworks?view=artists` | 작가 검색·좋아요, 작가 상세 이동. `/artists`는 이 주소로 이동 |
| 작품 상세 `/artwork/{id}` | 이미지 확대·작품 정보·출처, 작가 이미지, 도슨트, 작품별 감상 작성·수정·삭제, 관련 작품 |
| 작가 상세 `/artist/{id}` | 소개·작품 모음·작가 좋아요 |
| 감상 피드 `/community` | 공개 감상 카드, 긴 글 말줄임·펼치기, 작성자 공개 프로필, 본인 글 삭제 |
| 내 피드 `/library` | 계정 소개·AI 취향 소개, 공개 감상, 내 컬렉션, 관심 작가, 감상 캘린더 탭 |
| 다른 감상가 `/user/{public_id}` | 공개 감상, 팔로우·취소, 공개 설정에 따른 팔로워·팔로잉 목록 |
| 내 컬렉션 `/collection/{id}` | 별도 페이지의 작품 정렬, 더 보기, 작품 담기·꺼내기, 제목·소개 편집 |
| 좋아요 모음 `/collection/likes` | 좋아요한 작품을 전시형 그리드로 표시 |
| 자동 모음 `/collection/auto/{key}` | 최근·반복·작가·월별 및 AI 테마 상세, 내 컬렉션으로 저장 |
| 설정 | 헤더의 사이드 패널: 계정, 내 피드 이동, 팔로우 목록 공개 설정, 하단 로그아웃 |

`/mypage`는 `/library`, `/mypage?tab=collections`는 `/library?tab=collections`, `/settings`는 `/library`로 이동하는 호환 주소입니다. 현재 내 피드의 탭은 `posts`, `collections`, `artists`, `calendar`입니다. 저장 대화·활동 API 어댑터와 프로필 모델은 남아 있으나 별도 활동 탭·대화 목록 탭·회원정보 온보딩 폼은 현재 화면에 노출되지 않습니다.

## 도슨트 채팅

- `POST /api/artworks/{id}/chat/stream`의 SSE `token`·`replace`를 순차 표시하고 `done`의 최종 답변·출처·거절 상태·컬렉션 제안을 반영합니다.
- 질문 1~500자, 최근 대화 최대 12개, 메시지 내용 최대 4000자를 전달합니다. Easy / Standard / Deep 설명을 선택할 수 있습니다.
- 전송·복원·초기화 중 중복 요청을 막습니다. 서버 텍스트 단위로 화면을 갱신하며 글자별 인위적인 지연을 넣지 않습니다.
- 스트리밍 경로가 404·405·501일 때만 JSON 채팅으로 전환합니다. 시작된 답변이 실패하면 자동 재전송하지 않고 오류와 수동 재시도를 제공합니다.
- 로그인 사용자는 작품별 저장 대화를 복원·초기화할 수 있습니다. 계정 변경·화면 해제 후 늦은 응답은 버립니다.
- 원문 출처·라이선스와 선택적인 `basis_sources` 편집 보강 근거를 구분합니다. 실제 API 모드에는 프론트의 주제별 질문 차단이 없습니다. 범위 판단과 `refused`는 서버가 결정합니다.

스트리밍은 답변을 처음 보기까지의 체감 대기를 줄이며 모델 생성 시간 자체를 보장하지 않습니다. 서버의 품질·지연 측정은 [6차 배포 평가](../docs/test-result.md)를 참고하세요.

## 감상·캘린더·컬렉션

- 실제 모드의 감상은 서버에 저장합니다. 새 글은 기본 비공개이고 공개 전환 후 저장한 글만 다른 감상가에게 표시됩니다.
- 작품별 감상 한 편, 하루 작성 개수 제한 없음. 삭제는 날짜가 아닌 `entry_id`로 요청하고 서버가 소유권을 확인합니다.
- 서울 날짜를 기준으로 월별·날짜별 기록을 표시합니다. 열람 작품 수와 반복 조회 횟수를 구분합니다.
- 직접 저장하는 컬렉션은 계정당 10개·컬렉션당 30점 한도입니다. 기존 초과 데이터는 자동 삭제하지 않습니다.
- 좋아요·열람 작품 3점 이상을 바탕으로 AI 테마를 준비합니다. 목표는 2~4개·각 3~8점이며 실제 개수는 검증된 서버 응답에 따릅니다.
- AI 테마 캐시는 시간이 지났다는 이유만으로 재생성하지 않습니다. 좋아요 변경·새 작품 3점 이상 열람 등 신호가 바뀌면 최소 30분 간격으로 갱신합니다. 일반 컬렉션은 사용자가 저장을 선택할 때 생성됩니다.

## 채팅에서 컬렉션 만들기

작품 도슨트 헤더의 **컬렉션 요청**과 내 컬렉션의 **AI와 컬렉션 만들기** 버튼이 같은 도우미를 엽니다. 기존 계정을 이용해 새 모음을 만들거나 열람 기록을 모으고, 선택한 모음에 작품을 담도록 요청할 수 있습니다.

1. “최근 본 작품으로 컬렉션 만들어줘”, “고요한 풍경 컬렉션 만들어줘”처럼 요청합니다.
2. 기존 모음에 담을 때는 드롭다운으로 대상 모음을 선택하고 정확한 작품명을 적습니다. 작품 상세에서 현재 작품을 담는 예시도 제공합니다.
3. `POST /me/collections/chat`는 답변과 읽기 전용 제안을 반환합니다. 모음 제목·작품 목록·대상을 확인합니다.
4. **확인하고 저장**을 눌러야 생성 또는 작품 추가 API가 실행됩니다. 저장 후 별도 컬렉션 페이지를 열 수 있습니다.

새 요청·취소는 이전 제안을 무효화하고 중복 전송·저장을 막습니다. 계정 변경 시 창을 닫고 늦은 응답을 버립니다. 도우미 요청은 각각 독립적이며 대화는 창을 닫으면 사라집니다. 데모에서는 실제 AI를 호출하지 않습니다.

기존 도슨트의 반복 질문 후 제안도 유지합니다. 새 컬렉션을 선택하면 최초 작품 ID를 생성 본문에 함께 보내 한 요청으로 저장합니다. Flutter는 REST를 사용하며 외부 MCP `/mcp/` 호출과 구분합니다. 새 도우미 UI는 이번 lsh 변경으로, 아래 기록된 이전 Vercel 운영 배포에는 아직 포함되지 않습니다.

## 인증과 데이터 경계

Firebase 이메일·비밀번호 가입/로그인, Google 팝업 로그인, 비밀번호 재설정을 사용합니다. SDK가 세션을 복원하고 요청마다 ID 토큰을 Bearer 헤더에 넣습니다. 401이면 토큰을 강제 갱신해 한 번만 재시도하며 계정이 바뀐 요청은 새 계정으로 재전송하지 않습니다.

실제 모드의 사용자 분리는 서버 Firebase 토큰 검증·소유권 검사에 의존합니다. 프론트가 UID를 본문에 넣어 사용자를 지정하지 않습니다. 서비스 계정·TiDB 비밀번호·OpenAI·Chroma 키는 서버 전용입니다. 미리보기 기록은 현재 브라우저에 남으므로 운영 서버 데이터와 구분합니다.

## 디자인·이미지

검은 전시형 발견 화면과 밝은 감상·개인 기록 화면을 사용합니다. 공통 최대 본문 너비는 1280px이며 테마·버튼·팝업 스타일은 `lib/ui/`에서 관리합니다. 기본 서체는 **Chiron Sung HK**이고 Pretendard를 사용하지 않습니다. 일부 한글 글리프는 Flutter의 폰트 fallback이 적용될 수 있습니다.

로고는 `assets/branding/`의 이젤 포함 이미지를 사용합니다. 파비콘·로딩 로고는 `web/`에서 관리합니다. 김홍도·정선의 국립중앙박물관 이미지 중 확인된 원본 URL은 `museum_artwork_images.dart`에서 `web/images/artworks/`의 로컬 파일로 연결하며 알 수 없는 URL은 그대로 둡니다. 출처·이용 조건은 작품 API 정보를 유지합니다.

스크롤에 따른 헤더 축소·메인 패널 변화·콘텐츠 등장·맨 위로 이동을 제공합니다. 좁은 화면과 시스템 동작 줄이기 설정에서는 이동 효과를 줄입니다. 목록은 더 보기 방식이며 자동 무한 스크롤을 사용하지 않습니다.

## 빌드·검증

```bash
flutter analyze
flutter test
flutter build web --release --dart-define-from-file=.dart-defines.local.json
```

이번 검증은 Flutter 분석 이슈 없음·회귀 10개 통과·미리보기와 API/Firebase release 빌드 성공입니다. 결과는 `build/web/`이며 폴더 전체를 정적 서버에서 제공합니다. 이번 변경에서 `test/`에 컬렉션 상태·저장 확인·계정 변경·320/1280px UI·도슨트 제안·자산 이동 회귀 테스트를 추가했습니다. 과거 81/133/153개 통과 기록은 당시 결과이며 이번 새 테스트와 합산하지 않습니다. 배포 스크립트 테스트 파일은 별도로 없습니다.

다른 출처의 API는 백엔드에서 운영 웹 도메인, `Authorization`, POST/PUT/DELETE의 CORS를 허용해야 합니다. HTTPS 웹에는 HTTPS API를 연결합니다. 하위 경로 배포는 `--base-href`와 `/images/artworks/` 절대 경로를 함께 검토합니다.

## 폴더 구조

```text
frontend/
├── lib/              앱·모델·상태
│   ├── api/          REST·SSE·토큰·오류
│   ├── auth/         Firebase 인증
│   ├── conversations/ 도슨트·컬렉션 대화 상태
│   ├── pages/        화면·라우팅 대상
│   └── ui/           공통 디자인·채팅·캘린더·설정
├── assets/           카탈로그·artworks·fonts·branding
├── web/              시작 파일·파비콘·박물관 이미지
├── scripts/          Flutter Vercel 설치·빌드·공개 설정 생성
├── test/             컬렉션·채팅·계정·반응형·자산 회귀
├── docs/             API·ERD·배포·인수인계
└── verification/     과거 검증·화면 기록
```

[소스 역할](lib/README.md) · [자산 관리](assets/README.md). `package.json` 없이도 `.mjs` 빌드 설정 스크립트는 Vercel의 Node로 실행됩니다. Flutter 개발 실행에는 Node가 필요하지 않습니다.

## 주요 파일과 문서

| 경로 | 역할 |
| --- | --- |
| `lib/main.dart`, `lib/config.dart` | 시작·라우팅·빌드 설정 |
| `lib/pages/`, `lib/ui/` | 화면·공통 UI·로그인·설정 패널 |
| `lib/state.dart`, `lib/state_mypage.dart`, `lib/state_social.dart` | 상태·요청 재사용·계정 변경·개인 기록 |
| `lib/api/artlog_api.dart`, `lib/conversations/` | API·토큰·SSE·대화 상태 |
| `lib/models.dart`, `lib/diary.dart`, `lib/mypage.dart`, `lib/social.dart` | 응답 모델 |
| `assets/`, `assets/artworks/`, `web/` | 번들 데이터·폰트·브랜딩·정적 파일 |
| `scripts/vercel-install.sh`, `scripts/vercel-build.sh` | 고정 Flutter SDK 준비·Vercel 빌드 |
| [엔드포인트](docs/endpoints.md) | 현재 프론트 호출 계약과 화면 노출 구분 |
| [ERD 대응](docs/erd-mapping.md) | 22개 모델 테이블·마이그레이션·사용자 분리 |
| [배포 안내](docs/firebase-vercel.md) | 공개 환경변수·CLI/Git 루트·배포 확인 |
| [인수인계](docs/frontend-handoff.md) | 현재 구현·검증 범위·남은 작업 |
| [검증 이력](verification/README.md) | 날짜별 검증·과거 화면 |

현재 운영 배포는 2026-10-15의 dev `af7cea8`, 배포 ID `dpl_5sQdELnnHxruyhUyMbjnzbnNnTf7`입니다. 최신 dev `6f0b40a`와 프론트엔드 트리가 동일하며 이후 dev 변경은 평가 자료입니다. Git push와 Vercel 배포는 별도 작업입니다.
