# Flutter Web 검증 기록

검증일: 2026-10-12 · Flutter 3.47.2 / Dart 3.13.2.

- `flutter analyze`: 이슈 없음.
- `flutter test`: 32개 통과. API 요청 경로·메서드·쿼리·JWT 헤더·챗 요청/출처·빈 204·401·500·잘못된 JSON·응답 지연, 상태 저장과 실패한 변경 처리 검증.
- 1440, 768, 390, 320px에서 발견하기·작가 목록·작품 상세·작가 상세·서재 레이아웃 검사 통과. 앱 폰트를 로드해 검사함.
- 실제 API 모드를 API 없는 로컬 서버에서 실행: `/api/artworks`, `/api/artists`, `/api/movements` 요청과 404 안내·재시도 표시 확인. 목업으로 대체되지 않음.
- 미리보기 및 `ARTLOG_DEMO=false` 실제 API 모드의 release 웹 빌드 성공.
- 브라우저에서 필터, 좋아요·팔로우, 도슨트 예시 질문·출처 창·범위 밖 질문, 감상 메모 저장 및 새로고침 후 유지 확인.
- 390 × 844 모바일 화면에서 홈·작품 카드·서재 확인. 기본 데스크톱 화면의 브라우저 콘솔 경고·오류 없음.
- 초기 Flutter 화면 검증 단계에서 `frontend/` 밖 파일은 수정하지 않음. 이후 Firebase·배포 작업의 Git 반영 내역은 아래 기록을 참고.

API 테스트는 문서 초안에 맞춘 MockClient 검사입니다. **실제 서버와의 통합 성공을 의미하지 않습니다.** 서버 라우터·응답 스키마가 아직 없으며 미확정 항목은 [엔드포인트 점검표](../docs/endpoints.md)에 있습니다.

![데스크톱 홈](home-desktop.jpg)

![모바일 홈](home-mobile.jpg)

![모바일 작품 목록](collection-mobile.jpg)


## Firebase·Vercel 추가 검증 (2026-10-12)

- `origin/dev`의 `9b39e6a`를 fast-forward 반영한 뒤, 작업 중 추가된 최신 `e604d10`까지 `lsh`에 병합. dev에서 가져온 파일 외 직접 수정은 `frontend/`로 제한.
- Flutter 정적 분석 이슈 없음, 기존 화면·API와 Firebase 인증 관련 테스트 총 42개 통과.
- 배포 설정의 공개 값 허용 목록·필수 설정·HTTPS API 및 SDK 캐시 복구 테스트 4개 통과.
- Firebase SDK를 포함한 로컬 release 빌드 성공.
- Vercel 원격 환경에서 Flutter 3.47.2 설치·lockfile 의존성 설치·웹 빌드·운영 배포 성공. SDK 캐시의 불완전한 Git 메타데이터 복구 후 재배포 성공. 상태 `READY`, 최종 빌드 약 3분.
- 운영 주소: https://artlog-skn35-1team.vercel.app
- 최종 배포 ID: `dpl_2ASeA6t6aXAcTfsYsY3xTLcLZz9E`.
- 운영 `main.dart.js`의 프로젝트 ID·웹앱 ID가 팀 Firebase 설정과 일치함을 확인. HTTP 200.
- 운영 브라우저에서 작품 화면, Firebase 로그인·회원가입 입력 화면, SDK 초기 로딩 확인. 콘솔 오류·경고 없음.
- 갱신된 운영 화면에서 존재하지 않는 계정으로 로그인하면 Firebase 응답 뒤 `이메일 또는 비밀번호를 확인해 주세요.` 안내 표시. 로그인 성공으로 처리되지 않으며 콘솔 오류·경고 없음.
- 팀 Firebase `skn35-3rd-1team`의 이메일/비밀번호 공급자 활성화, `Artlog Web` 등록, 운영 도메인 승인 완료. Vercel의 Production·Preview·Development 환경변수도 이 프로젝트로 교체.
- 실제 Firebase Auth REST API의 임시 계정 가입 → 비밀번호 로그인 → 계정 조회 성공. 테스트 계정은 같은 실행의 `finally`에서 즉시 삭제했으며 비밀번호·토큰을 저장하거나 출력하지 않음.
- 브라우저에서 실제 계정 로그인 후 새로고침하는 전체 흐름은 별도로 검증하지 않았음. 로그인 복원·계정별 기록 분리·401 갱신은 가짜 세션 자동 테스트로 검증.
- 현재 운영은 작품·도슨트 미리보기 + Firebase 인증 연결. 서버 자료 조회와 기록 동기화는 백엔드 준비 전.

![운영 로그인 화면](firebase-login-production.jpg)
