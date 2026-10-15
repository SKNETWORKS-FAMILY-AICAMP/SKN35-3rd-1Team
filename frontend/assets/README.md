# Flutter 번들 자산

| 폴더·파일 | 용도 |
| --- | --- |
| `catalog.json` | 데모 작품 12점·작가 10명·사조 6개 |
| `artworks/` | 데모 작품 파일. 이전 `public/artworks/`에서 이동 |
| `branding/` | 이젤 포함 Docentalk 로고·락업 |
| `fonts/` | 현재 Chiron Sung HK와 OFL·앱 라이선스 등록 메타데이터 |

모든 번들 경로는 `pubspec.yaml`에 등록합니다. 이미지 이동 시 `catalog.json`과 이미지 위젯의 자산 인식 경로도 같이 변경합니다. 사용하지 않는 목업 폰트와 React public 파일은 제거했습니다.

운영 박물관 이미지의 정확한 URL 매핑용 파일은 `../web/images/artworks/`에 별도로 있습니다. 작품 출처·라이선스는 API/카탈로그 메타데이터를 유지합니다. 파비콘과 시작 로더는 `../web/`에서 관리합니다.
