# types

API 요청·응답에 쓰는 TypeScript 타입을 둡니다. 백엔드 `app/schemas/`와 필드 이름을 똑같이 맞춥니다.

## 들어갈 파일

- `auth.ts`: 사용자, 토큰
- `catalog.ts`: 사조, 작가 카드·상세, 작품 카드·상세
- `chat.ts`: 메시지, 질문 요청, 답변 응답, 출처 항목
- `library.ts`: 캘린더 날짜 항목, 하루 상세
- `recommendation.ts`: 추천 작품, 추천 작가

## 규칙

- 필드 이름은 백엔드 응답 그대로 씁니다 (`image_url`, `source_url`). 프론트에서 이름을 바꾸면 양쪽 문서가 어긋납니다.
- 값이 없을 수 있는 필드는 타입에 표시합니다. 작품의 `movement`, `image_url`, 문서의 `source_url`이 해당합니다.
- 백엔드 스키마가 바뀌면 같은 PR에서 여기 타입도 고칩니다.
