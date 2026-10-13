# 아트로그 프론트엔드 인수인계

작성일: 2026-10-13 · 작업 브랜치: `lsh` · 기준 dev: `a7a5fbe`

## 전달할 핵심

Flutter 웹에서 최신 서버 계약에 있는 기능을 연결했습니다. 작품·작가·좋아요·팔로우·서재에 더해 맞춤 추천과 추천 이유, 작품별 대화 복원·초기화, 내 대화 목록을 사용할 수 있습니다. 실제 AI 답변 생성은 백엔드의 `POST /api/artworks/{id}/chat` 구현이 필요합니다.

이번 직접 수정은 `frontend/` 안으로 제한했습니다. Railway 콘솔·서버 환경변수·TiDB 데이터·기존 서버 설정은 변경하지 않았습니다. Google 공급자 설정 결과는 아래 배포 기록에 별도로 기재합니다.

추가 요청에 따라 최신 15테이블 ERD·마이그레이션·API를 대조했습니다. 반복 열람 집계와 작품 수/감상 횟수 구분, 큐레이터 featured 표시, 편집 보강 근거를 반영했습니다. 테이블별 대응과 문서 불일치는 [ERD 연결 점검](erd-mapping.md)을 참고하세요. 온보딩의 나이·성별·설명 스타일 필드는 현재 ERD에 없어 브라우저 저장을 유지합니다.

## 완료한 프론트 동작

| 화면 | 동작 |
| --- | --- |
| 발견하기 | 전체 목록의 제목·영문 제목·작가 검색, 사조/작가 필터, 정렬·더 보기, 좋아요 |
| 로그인 후 발견하기 | 맞춤 작품·작가 추천 API 호출, 서버 순서와 `reason` 표시, 좋아요·팔로우가 바뀌면 추천 갱신 |
| 작품 상세 | 상세 API, 이미지·확대·메타데이터·이용 조건, 유사 작품 3개, 로그인 시 열람 기록. 상세를 연 뒤 로그인해도 열람 기록 전송 |
| 도슨트 | 저장된 대화 복원, 질문 전송·재시도, 대화 초기화 확인 창, 범위 밖 답변 표시, 근거 원문·한국어 자료 유형·라이선스 표시 |
| 내 서재 | 서울 기준 월별 캘린더·날짜별 작품, 좋아요·팔로우 목록, 대화 내역 탭 및 작품별 대화 이어보기 |
| 로그인·온보딩 | Firebase 이메일/Google 가입·로그인, 로그인/회원가입 구분, 비밀번호 재설정, 선택형 감상 프로필, SDK 세션 복원, 요청마다 ID 토큰 사용, 401 시 한 번만 강제 갱신 |
| 오류·모바일 | 401/403/404/422/429/501/503·네트워크·시간 초과 안내, 빈 결과·재시도, 좁은 서재 탭과 작은 이미지 오류 표시 대응 |

## Google 로그인·회원 온보딩

- 로그인/회원가입을 각각 선택하는 탭과 별도 이메일 안내를 제공합니다. Google는 ‘Google로 계속하기’ 한 번으로 기존 사용자는 로그인, 처음 이용하는 사용자는 계정 생성 후 온보딩을 진행합니다.
- Firebase `GoogleAuthProvider`와 웹 `signInWithPopup`을 사용합니다. 팝업 차단·취소, 미승인 도메인, 공급자 미활성화, 다른 가입 방법 충돌에 한국어 안내를 제공합니다. 사용자 비밀번호나 Google OAuth 토큰을 팀 로그인 API에 보내지 않습니다.
- 첫 로그인 후 나이대·성별·선호 설명 스타일 온보딩을 표시합니다. 나이·성별은 선택이며 응답하지 않음·건너뛰기를 제공합니다. 정확한 생년월일은 수집하지 않습니다. Google에서 나이·성별을 자동 조회하지 않습니다.
- 프로필은 `SharedPreferences`에 Firebase UID별로 저장합니다. 서재의 ‘감상 프로필’에서 수정할 수 있습니다. 계정이 바뀌면 기존 폼을 닫으며 다른 계정에 선택값을 가져오지 않습니다.
- **프로필 서버 저장과 맞춤 말투는 아직 미연결입니다.** 백엔드에 프로필 저장 API가 없어 현재 브라우저에만 저장합니다. 화면에도 저장 범위와 설명 스타일 적용 대기를 알립니다. 나이·성별을 임의로 챗 history에 끼워 넣거나 기존 요청 계약을 바꾸지 않았습니다.
- 서버 계약 제안(미구현·호출하지 않음): 인증된 `GET/PATCH /api/me/profile`로 `{age_range: nullable enum, gender: nullable enum, explanation_style: enum}` 저장·조회. UID는 검증 토큰에서만 얻습니다. 허용 값은 `lib/member_profile.dart`를 기준으로 협의하고, 동기화와 실제 도슨트 적용·동의/수정/삭제 정책은 서버 담당자와 확정합니다.
- 성별로 말투를 추정하지 않으며 사용자가 선택한 설명 스타일을 맞춤 도슨트의 기준으로 전달하도록 인계합니다.

질문은 1~500자, `history`는 직전 최대 12개이며 각 항목은 최대 4000자로 맞춥니다. 실패한 질문을 재시도할 때 같은 질문을 history에 중복 삽입하지 않습니다. 서버 실패를 미리보기 답변으로 대체하지 않습니다.

계정 변경 시 서재·대화·입력란을 비우고 이전 계정의 늦은 응답을 버립니다. 이전 계정의 요청이 401을 받아도 새 계정의 토큰으로 다시 전송하지 않습니다. 대화 삭제 확인 창을 연 뒤 계정이 바뀌면 삭제하지 않습니다. 이미 서버에 도착한 요청을 취소하거나 서버의 사용자 분리를 대신하는 기능은 아닙니다.

감상 메모는 저장 API가 없어 Firebase UID별로 **현재 브라우저에만** 저장합니다. 다른 기기와 동기화되지 않습니다. 미리보기 대화도 서버에 저장하지 않습니다.

## 백엔드·Railway 담당자 후속 작업

1. **실제 도슨트 답변 생성 연결**
   - 현재 기준 코드의 `backend/app/api/routes/chat.py::ask`는 `not_implemented()`입니다.
   - 검색 담당자의 [검색 인계](../../docs/retrieval-handoff.md)에 따라 `retrieve(db, artwork_id, question)`을 호출하고 답변을 생성해 주세요.
   - 응답 형식은 `{answer, refused, sources}`이며 출처는 `{document_id, title, doc_type, source_name, source_url, license}`입니다. 근거가 부족하면 `refused: true`로 안내합니다. 프론트는 이 형식 그대로 표시합니다.
   - 로그인 사용자의 질문·답변은 `chat_service.save_exchange`로 저장해 주세요. POST 라우트에 DB 세션이 필요합니다. 이 연결이 있어야 새 대화가 복원과 내 대화 목록에 나타납니다. 비로그인 질문은 history로 맥락만 전달하며 개인 대화로 저장하지 않습니다.
2. **운영 Firebase 인증 확인**
   - `FIREBASE_PROJECT_ID=skn35-3rd-1team`, 서버 서비스 계정 인증 정보 및 `AUTH_MODE=firebase`를 확인해 주세요.
   - 서비스 계정은 서버의 `FIREBASE_SERVICE_ACCOUNT_JSON` 또는 서버에 마운트한 파일의 `GOOGLE_APPLICATION_CREDENTIALS`로 설정합니다. 로컬 키 경로가 Railway에서도 존재하는 것은 아닙니다.
   - `AUTH_MODE=dev`이면 모든 Bearer 토큰이 한 개발 사용자로 매핑되어 프론트의 로그인과 관계없이 기록이 합쳐집니다. 프론트에서 해결할 수 없습니다.
   - 이번 프론트 작업에서는 운영 AUTH_MODE를 확인·변경하지 않았습니다. 담당자가 유효한 토큰/변조 토큰과 서로 다른 실제 계정 두 개로 운영 분리를 확인해야 합니다.
3. **RAG 서버 비밀값·검색 설정 확인**
   - `OPENAI_API_KEY`, Chroma Cloud의 `CHROMA_API_KEY`·`CHROMA_TENANT`·`CHROMA_DATABASE`, 컬렉션 설정은 [검색 인계](../../docs/retrieval-handoff.md)가 기준입니다.
   - 이 값과 TiDB 비밀번호·서비스 계정 키는 Vercel 프론트 번들에 넣지 않습니다.
4. **운영 통합 검증**
   - 두 계정의 좋아요·팔로우·열람·대화가 분리되는지 확인합니다.
   - 로그인 후 질문 → 답변과 실제 출처·라이선스 → 새로고침 후 대화 복원 → 서재 대화 목록 → 초기화 후 목록 반영을 확인합니다.
   - 질문 history가 맥락으로 쓰이고 저장은 복원용인지, 동일 작품을 다시 본 날의 캘린더 집계가 맞는지 확인합니다.
5. **감상 프로필 API 및 설명 스타일 연결**
   - 위 제안 계약을 확정한 뒤 프로필의 서버 저장·조회와 도슨트 설명 스타일 반영을 구현해 주세요. 현재는 브라우저 저장뿐이며 프론트에서 서버 요청을 추가하지 않았습니다.

## 연결·배포 정보

- 웹: https://artlog-skn35-1team.vercel.app
- 팀 API: https://skn35-3rd-1team-production.up.railway.app/
- Vercel 빌드 값: `API_BASE_URL` 위 API 주소, `ARTLOG_DEMO=false`, `AUTH_PROVIDER=firebase`.
- 공개 Firebase 웹 설정은 기존 Vercel 환경변수 사용. 사용자 승인 후 `skn35-3rd-1team`의 Google 공급자를 활성화·저장했고 콘솔의 ‘사용 설정됨’을 확인했습니다. 공개 앱 이름은 ‘아트로그’, 지원 이메일은 승인된 프로젝트 계정입니다. 기존 이메일 공급자도 활성 상태입니다.
- Vercel에 저장소를 연결하면 Root Directory는 `frontend`. 현재 CLI가 frontend 폴더만 업로드하므로 프로젝트 Root Directory는 `.`입니다. `frontend/vercel.json`의 Flutter 설치·빌드 스크립트가 적용됩니다.
- 2026-10-13 ERD 반영 최종 Vercel 운영 배포 `dpl_498qJbZrfSaBdFEXcdgqsWYapfpW`가 READY이며 기존 운영 도메인에 연결되었습니다. 원격 release 웹 빌드에서 `catalog=API, auth=firebase`를 확인했습니다.
- Git 자동 배포는 아직 연결하지 않았습니다. GitHub에 푸시하는 것과 Vercel 운영 배포는 별개입니다.

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define-from-file=.dart-defines.local.json
flutter analyze
flutter test
node --test scripts/*.test.mjs
vercel project inspect --non-interactive
vercel deploy --prod --yes --non-interactive --scope seunghee-lees-projects-93a5a524
```

`.dart-defines.local.json`은 `firebase.config.example.json`을 참고해 작성하는 Git 제외 로컬 파일입니다. 서버 비밀값을 넣지 않습니다. 새로 설치한 환경에서는 Vercel 로그인·기존 프로젝트 연결이 먼저 필요하며 위 inspect에서 프로젝트가 맞는지 확인합니다.

## 검증 결과와 범위

- Flutter 분석: 이슈 없음. ERD 반영 후 전체 Flutter 테스트 **81개 통과**. 배포 스크립트 **4개 통과**(스크립트 변경 없음).
- 기존 다섯 화면: 1440/768/390/320px 레이아웃 검사. 새 대화 내역·추천 이유·근거 라이선스: 1280/320px 검사.
- 대화 복원 → 후속 질문, 실패 질문 재시도, 초기화 실패 시 기존 대화 유지, 계정 변경 중 늦은 답변/복원/좋아요, 삭제 확인 중 계정 변경을 테스트했습니다.
- 새 개인 기능은 MockClient·가짜 Firebase 세션으로 검증했습니다. 실제 사용자 비밀번호나 운영 개인 기록은 테스트에 사용하지 않았습니다. 실제 운영 Firebase 로그인과 서버 저장 전체 흐름을 검증했다는 뜻은 아닙니다.
- Google 공급자 호출·팝업 오류 안내, 계정별 프로필 저장·건너뛰기·계정 변경과 320/390/1280px 온보딩을 자동 검사했습니다. 운영 Safari 비공개 창에서 Google 버튼 → Google 계정 인증 페이지까지 확인하고 계정 입력 없이 닫았습니다. 실제 Google 로그인 성공·사용자별 TiDB 저장까지 검증한 것은 아닙니다. Codex 내장 브라우저에서는 팝업을 확인할 수 없어 Safari에서 확인했습니다.
- 2026-10-13 실제 팀 API: `/api/health` 200, OpenAPI에 새 대화 경로 확인, `/api/artworks/236/similar` 200·3개 확인. 카탈로그 사조 4개·작가 8명·작품 219점, 비로그인 도슨트 POST는 501을 확인했습니다. 실제 운영 배포 검증은 [검증 기록](../verification/README.md)을 참고합니다.

## 주요 파일

- `lib/auth/firebase_session.dart`: 이메일/Google SDK 로그인과 오류 안내.
- `lib/member_profile.dart`, `lib/ui/member_profile_dialog.dart`: 계정별 선택형 온보딩·수정 UI.
- `test/onboarding_test.dart`: Google 공급자 호출, 오류, 온보딩 저장·건너뛰기·계정 변경 및 320/390/1280px 검증.
- `lib/api/artlog_api.dart`: API 계약, 토큰 갱신과 계정 변경 시 재시도 차단.
- `lib/docent_conversation.dart`: 작품별 대화 복원·전송·재시도·초기화와 비동기 응답 관리.
- `lib/ui/docent_chat.dart`: 도슨트 UI·출처·라이선스·초기화 확인.
- `lib/ui/personal_recommendations.dart`: 맞춤 추천과 이유 표시.
- `lib/ui/saved_chats.dart`: 내 대화 목록과 작품 상세 이동.
- `lib/state.dart`, `lib/pages/library_page.dart`: 사용자 기록과 계정 변경 처리.
- `test/connected_features_test.dart`: 새 연동 기능과 계정 변경 회귀 테스트.

## 팀 채팅 전달 문구

프론트 최신 dev와 ERD 기준으로 추천 작품·추천 작가와 추천 이유, 작품별 대화 복원·초기화, 서재의 대화 내역까지 연결했습니다. 반복 열람 횟수와 서로 다른 작품 수를 구분하고 큐레이터 featured 표시도 반영했습니다. 질문은 서버 기준 500자/history 12개로 맞췄고, 출처 원문·라이선스와 선택형 편집 보강 근거도 표시합니다. 계정 변경 중 이전 응답이 섞이거나 새 계정으로 재시도되는 경우를 막았고 Flutter 81개·배포 스크립트 4개 테스트 통과했습니다.

Google 로그인과 로그인/회원가입 구분, 나이대·성별·설명 스타일을 선택하는 온보딩도 추가했습니다. Firebase Google 공급자 활성화·운영 배포를 마쳤고 실제 Google 인증창 진입까지 확인했습니다. 프로필은 현재 UID별 브라우저 저장이며 서버 저장과 맞춤 말투는 프로필 API 계약 후 연결이 필요합니다. 남은 서버 작업은 실제 도슨트 POST의 검색/답변 생성 연결과 로그인 사용자 `save_exchange` 저장입니다. Railway 담당자께서는 Firebase 프로젝트 ID·서버 인증 정보·AUTH_MODE=firebase와 RAG 환경변수를 확인 부탁드립니다. 실제 Google 로그인 성공, 운영 두 계정 분리와 질문→저장→복원→초기화까지 통합 확인이 필요합니다. 감상 메모는 API가 없어 현재 브라우저에만 저장됩니다. 상세 인계는 frontend/docs/frontend-handoff.md에 정리했습니다.
