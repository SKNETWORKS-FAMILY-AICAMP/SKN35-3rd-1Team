# Flutter Web 검증 기록

검증일: 2026-10-12 · Flutter 3.47.2 / Dart 3.13.2.

- `flutter analyze`: 이슈 없음.
- `flutter test`: 32개 통과. API 요청 경로·메서드·쿼리·JWT 헤더·챗 요청/출처·빈 204·401·500·잘못된 JSON·응답 지연, 상태 저장과 실패한 변경 처리 검증.
- 1440, 768, 390, 320px에서 발견하기·작가 목록·작품 상세·작가 상세·서재 레이아웃 검사 통과. 앱 폰트를 로드해 검사함.
- 실제 API 모드를 API 없는 로컬 서버에서 실행: `/api/artworks`, `/api/artists`, `/api/movements` 요청과 404 안내·재시도 표시 확인. 목업으로 대체되지 않음.
- 미리보기 및 `ARTLOG_DEMO=false` 실제 API 모드의 release 웹 빌드 성공.
- 브라우저에서 필터, 좋아요·팔로우, 도슨트 예시 질문·출처 창·범위 밖 질문, 감상 메모 저장 및 새로고침 후 유지 확인.
- 390 × 844 모바일 화면에서 홈·작품 카드·서재 확인. 기본 데스크톱 화면의 브라우저 콘솔 경고·오류 없음.
- `frontend/` 밖 기존 변경 사항의 diff는 작업 시작 시점과 동일. 현재 브랜치는 `lsh`이며 커밋·푸시는 수행하지 않음.

API 테스트는 문서 초안에 맞춘 MockClient 검사입니다. **실제 서버와의 통합 성공을 의미하지 않습니다.** 서버 라우터·응답 스키마가 아직 없으며 미확정 항목은 [엔드포인트 점검표](../docs/endpoints.md)에 있습니다.

![데스크톱 홈](home-desktop.jpg)

![모바일 홈](home-mobile.jpg)

![모바일 작품 목록](collection-mobile.jpg)


## Firebase·Vercel 추가 검증 (2026-10-12)

- 최신 `origin/dev` (`9b39e6a`)를 `lsh`로 fast-forward 반영.
- Flutter 정적 분석 이슈 없음, 기존 화면·API와 Firebase 인증 관련 테스트 총 42개 통과.
- 배포 설정의 공개 값 허용 목록·필수 설정·HTTPS API 검증 테스트 3개 통과.
- Firebase SDK를 포함한 로컬 release 빌드 성공.
- Vercel 원격 환경에서 Flutter 3.47.2 설치·lockfile 의존성 설치·웹 빌드·운영 배포 성공. 상태 `READY`, 빌드 약 2분.
- 운영 주소: https://artlog-skn35-1team.vercel.app
- 배포 ID: `dpl_29SURpuiFTZueHkWiuGMEKNP4Xsk`.
- 운영 브라우저에서 작품 화면, Firebase 로그인·회원가입 입력 화면, SDK 초기 로딩 확인. 콘솔 오류·경고 없음.
- Firebase 프로젝트와 웹앱을 생성했고 Vercel의 Production·Preview·Development에 공개 웹 설정 등록.
- **Firebase Authentication 서비스의 첫 ‘시작하기’는 사용자 Google 콘솔 로그인 대기 중.** 아직 실제 회원가입·로그인 성공을 검증하지 않았음. 프론트엔드 인증 연결과 fake-session 테스트 성공을 실제 Firebase 서비스 활성화 성공과 구분함.
- 현재 운영은 작품·도슨트 미리보기 + Firebase 인증 연결. 서버 자료 조회와 기록 동기화는 백엔드 준비 전.

![운영 로그인 화면](firebase-login-production.jpg)
