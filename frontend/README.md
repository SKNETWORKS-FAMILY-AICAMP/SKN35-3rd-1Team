# 아트로그 · Flutter Web

공유받은 `artlog-mockup.html`을 Flutter 위젯으로 구현했습니다. 오프화이트 배경, 녹색 포인트, 명조 제목과 작품 이미지를 사용하며 데스크톱·태블릿·모바일에 대응합니다.

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

**현재 저장소에는 API 라우터 구현과 확정된 응답 스키마가 없습니다.** 경로·메서드는 서버 초안 문서와 대조하고 요청 테스트를 작성했습니다. 실제 서버와의 통합 검증은 아직 할 수 없으며, 로그인·캘린더 등 임시 응답 가정은 [엔드포인트 점검표](docs/endpoints.md)에 명시했습니다.

## 화면과 동작

- 발견하기: 사조·작가 필터, 검색, 정렬, 더 보기, 작품 좋아요.
- 작품 상세: 이미지 확대, 감상 노트·작품 정보·이미지 출처, 비슷한 작품, 작가 팔로우.
- 도슨트: 이전 대화 전송, 답변·근거 출처 표시, 범위 밖 질문 안내, 오류 재시도.
- 작가 이야기: 작가 목록·검색·개별 작품 모음.
- 내 서재: 월별 감상 캘린더, 날짜별 작품, 좋아요·팔로우 목록, 감상 메모.
- 실제 모드 로그인: JWT를 메모리에서만 보관하고 인증이 필요한 동작을 로그인으로 보호합니다. 새로고침하면 다시 로그인합니다. 401 응답 시 로그인 상태를 초기화합니다.

감상 날짜는 서울 기준입니다. 감상 메모는 서버 API가 없어 **이 브라우저에만 저장**합니다. 미리보기와 계정별로 저장 공간을 나누지만 로그아웃해도 해당 브라우저의 메모는 남습니다. 공유 기기에서는 브라우저 사이트 데이터를 삭제해 정리할 수 있습니다. 회원가입·토큰 갱신 API는 명세 확정 전이므로 연결하지 않았습니다.

현재 목록 필터·검색·정렬은 불러온 작품 목록을 대상으로 합니다. 서버의 페이지네이션·검색 규격이 확정되면 이 부분을 서버 질의로 전환해야 합니다. 작가 상세는 문서의 `artist_id` 필터를 사용합니다. 실제 모드의 유사 작품은 서버 응답 순서를 유지합니다.

## 빌드와 확인

```bash
flutter analyze
flutter test
flutter build web --release
```

빌드 결과는 `build/web/`입니다. 폴더 전체를 정적 웹 서버에 올려 실행합니다. 단일 HTML을 더블클릭하는 방식의 결과물이 아닙니다. 경로는 `/#/gallery`, `/#/artwork/{id}`, `/#/artists`, `/#/artist/{id}`, `/#/library`이며 해시 라우팅으로 새로고침과 직접 진입을 지원합니다. 실제 모드 URL에는 DB의 `id`를 사용하고, 미리보기의 문자열 ID를 서버에 보내지 않습니다.

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
| `lib/api/artlog_api.dart` | HTTP 요청·인증·오류 처리 |
| `lib/models.dart`, `lib/state.dart` | 응답 매핑·상태·로컬 저장 |
| `assets/catalog.json` | 미리보기 전용 데이터 |
| `public/artworks/`, `assets/fonts/` | 작품 이미지·목업 폰트·라이선스 |
| `web/` | Flutter 웹 시작 페이지와 로더 |
| `test/` | 요청 계약·실패 처리·화면 크기별 검증 |
| `docs/endpoints.md` | 서버 문서 대조 결과와 미확정 항목 |

## 목업 자료

원본 HTML의 이미지·색상·글꼴을 재사용했습니다. 작품 출처와 이용 조건은 `assets/catalog.json` 및 작품 상세에 있습니다. 폰트는 목업에 포함된 글리프 부분 집합이며, 라이선스 원문은 `assets/fonts/licenses.json`과 앱의 라이선스 화면에 포함했습니다. 실제 서버에 임의의 한글 데이터가 추가되면 해당 글리프의 폰트 확장이 필요할 수 있습니다.

`python3 scripts/prepare_flutter_assets.py /절대경로/artlog-mockup.html`로 Flutter 목업 자료를 다시 추출할 수 있습니다. 기존 React 목업의 `src/`, `package.json`, Vite 관련 파일은 비교·참고용으로 보존했습니다. Flutter 실행에는 Node 설치가 필요하지 않습니다.
