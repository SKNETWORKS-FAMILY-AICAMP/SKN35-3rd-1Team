# public · 목업 정적 자료

갱신: 2026-10-15 · dev `6f0b40a` 기준.

`public/artworks/`에는 초기 목업의 작품 이미지 12점이 있습니다. Flutter `pubspec.yaml`에도 등록돼 미리보기 모드에서 번들 이미지로 사용합니다. 따라서 “작품 이미지는 여기에 두지 않는다”는 이전 안내는 현재 구조에 맞지 않습니다.

| 경로 | 용도 |
| --- | --- |
| `public/artworks/` | 초기 React 목업과 Flutter 데모 작품 이미지 |
| `public/fonts/` | 이전 목업 폰트 스타일·라이선스. Vercel 업로드 제외 |
| `public/favicon.svg` | 이전 목업 파비콘 |
| `../assets/branding/` | 현재 Flutter 이젤 로고·락업 |
| `../assets/fonts/` | 현재 Flutter Chiron Sung HK 폰트·라이선스 |
| `../web/` | 현재 Flutter 시작 페이지·로더·manifest·파비콘 |
| `../web/images/artworks/` | 확인된 박물관 URL에 대응하는 정적 작품 파일 |

운영 작품은 기본적으로 API의 `image_url`·출처·이용 조건을 사용합니다. 김홍도·정선 등 확인된 URL은 `../lib/ui/museum_artwork_images.dart`의 정확한 매핑으로 정적 파일을 표시합니다. 이름이 비슷한 다른 작품 이미지로 대체하지 않습니다.

Vercel의 결과물은 `build/web/`이며 `public/` 자체가 운영 output directory는 아닙니다. 전체 실행·배포는 [프론트 README](../README.md)를 참고하세요.
