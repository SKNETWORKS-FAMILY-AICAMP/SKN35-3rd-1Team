# pages

URL과 직접 연결되는 화면을 둡니다. 페이지는 컴포넌트와 훅을 조립하는 역할만 합니다.

## 들어갈 파일

| 파일 | 경로 | 내용 | 로그인 |
| --- | --- | --- | --- |
| `GalleryPage.tsx` | `/` | 작가별·사조별 탭과 작품 카드 목록, 맞춤 추천 영역 | |
| `ArtworkDetailPage.tsx` | `/artworks/:artworkId` | 작품 이미지와 정보, 도슨트 챗봇, 비슷한 작품 | |
| `ArtistDetailPage.tsx` | `/artists/:artistId` | 작가 소개, 팔로우, 작가의 작품 목록 | |
| `LibraryPage.tsx` | `/library` | 캘린더, 좋아요한 작품, 팔로우한 작가 | 필요 |
| `LoginPage.tsx` | `/login` | 로그인 | |
| `SignupPage.tsx` | `/signup` | 회원가입 | |

## 규칙

- 작품 상세에 들어오면 열람 기록을 남깁니다 (`useRecordView`). 로그인한 경우에만 호출합니다.
- 도슨트 챗봇은 작품 상세 화면 안에 둡니다. 별도 채팅 페이지로 빼면 "어느 작품에 대한 대화인지"를 다시 전달해야 합니다.
- 페이지에 긴 UI 코드가 쌓이면 `components/`로 옮깁니다.
