# library components

내 서재 화면을 구성하는 컴포넌트를 둡니다.

## 들어갈 파일

- `LibraryCalendar.tsx`: 월별 달력. 날짜마다 그날 본 작품 수 표시
- `DayArtworks.tsx`: 날짜를 눌렀을 때 그날 본 작품 목록
- `MonthSummary.tsx`: "이번 달 n개의 작품을 봤어요" 요약

## 규칙

- 달력은 한 달 단위로 조회합니다. 월을 바꿀 때마다 `GET /api/me/library/calendar?month=YYYY-MM`을 호출합니다.
- 날짜는 서버가 한국 시간 기준으로 계산해 준 값을 그대로 씁니다. 프론트에서 시간대 변환을 하지 않습니다.
