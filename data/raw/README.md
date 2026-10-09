# raw

수집한 원본 문서를 작가별 폴더에 둡니다. 원본은 고치지 않고, 정제 결과는 `processed/`에 따로 만듭니다.

## 폴더 배치

```text
raw/
├── vincent-van-gogh/
│   ├── bio.md                     작가 생애 원문
│   ├── the-starry-night.md        작품 해설 원문
│   └── sources.json               파일별 원문 주소, 출처 이름, 이용 조건, 수집일
├── paul-gauguin/
└── _comparisons/
    └── gogh-gauguin.md            작가 비교 문서
```

## 규칙

- 폴더 이름은 작가 slug와 같게 합니다. 전처리 스크립트가 폴더 이름으로 작가를 식별합니다.
- 파일을 추가할 때 `sources.json`에 출처를 함께 적습니다. 나중에 모아서 적으려 하면 빠집니다.
- 비교 문서는 두 작가 어느 쪽 폴더에도 속하지 않으므로 `_comparisons/`에 둡니다.
- 원본의 오탈자나 각주도 여기서는 그대로 둡니다. 정제는 전처리 스크립트가 합니다.
