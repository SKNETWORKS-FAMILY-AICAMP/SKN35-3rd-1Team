# 목업 서재 구성 계획

갱신: 2026-10-15 · dev `6f0b40a` 기준. **초기 React 목업 보존 문서**입니다.

이 폴더에는 `LibraryCalendar.tsx`·`DayArtworks.tsx` 구현이 없습니다. 초기 React 서재는 `src/pages/LibraryPage.tsx`와 localStorage 훅을 사용합니다.

현재 `/library`는 내 피드로 공개 감상·컬렉션·관심 작가·캘린더 탭을 제공합니다. 실제 감상은 서버 저장이고 기본 비공개입니다. 날짜는 서울 기준이며 작품 수와 반복 조회 횟수를 구분합니다. 하루 여러 감상을 허용하고 수정·삭제는 `entry_id`로 처리합니다.

## 현재 Flutter 구현

- [현재 내 피드](../../../lib/pages/feed_page.dart)
- [현재 감상 캘린더](../../../lib/ui/feed_calendar.dart)
- [감상 작성·삭제](../../../lib/ui/diary_feed.dart)
