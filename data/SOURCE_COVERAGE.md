# 클림트·실레 작품별 미술관 근거 자료표

수집·수정일: 2026-10-13

## 앱 표시 데이터

- 두 작가 소개: 실레 252자, 클림트 257자. 각각 3문장이다. `data/mappings/catalog.json`의 `summary`가 앱 카드에 들어간다.
- 작품 해설 원문은 각 30점, 총 60점을 보존한다. 이 가운데 이미지 권리를 확보하지 못한 3점은 `data/mappings/catalog.json`의 `excluded_artworks`로 배포 카탈로그와 전용 문서에서 제외한다. 앱에는 실레 28점, 클림트 29점, 총 57점이 표시된다.
- 작가 심화 자료: 두 작가 모두 `bio.md`를 약 1,400~1,500자로 확장하고 `technique.md`, `landscape.md`, `context.md`를 추가했다. 카드용 250~300자 소개와 검색용 장문 자료를 구별한다. 각 파일의 공식 기관 근거 URL은 같은 폴더의 `sources.json`에 있다.
- 감상 포인트: 작품마다 별도 내용을 `data/mappings/document_supplements.json`에 기록했다. 전처리 문서에는 `## 감상 포인트` 절로 들어가므로 챗봇 검색 근거로 쓸 수 있다. 현재 앱 작품 상세 응답의 독립 필드로는 아직 노출되지 않는다.
- 원본 소개 `bio.md`와 작품 해설은 팀이 미술관의 개별 수장품 페이지를 참고해 새로 작성한 한국어 문서다. 사용자 ju가 68건을 최종 승인했으며, 제외 3건을 뺀 65건이 전처리 문서로 배포된다. 승인자·본문 해시는 `data/mappings/reviews.json`에 보존한다.

## 출처와 이용 조건

작품별 정확한 출처 URL과 소장처는 아래 표 및 각 작가의 `sources.json`에 있다. 비교에 사용한 다른 작품의 소장처 URL은 `related_source_urls`, 관련 작품 ID는 `related_artwork_slugs`에 기록했고 전처리 문서의 근거 메타데이터로 전달한다. 작가 소개의 출처는 레오폴트 미술관의 [실레 소개](https://www.leopoldmuseum.org/en/collection/egon-schiele)와 [클림트 소개](https://www.leopoldmuseum.org/en/collection/gustav-klimt)다.

- [벨베데레 법적 고지](https://www.belvedere.at/en/legal-notice): 웹사이트의 글과 이미지 등은 저작권 보호 대상이며, 허락 없는 복제·출판·기타 이용을 금지한다. 출처를 밝힌 링크 공유는 허용한다고 안내한다. 텍스트·데이터 마이닝과 AI 학습에 대한 이용 유보도 명시한다.
- [레오폴트 온라인 컬렉션 법적 고지](https://onlinecollection.leopoldmuseum.org/en/legal-notice/): 게시된 글과 이미지는 저작권 보호 대상이고, 복제·출판을 금지한다고 안내한다. 사후 70년이 지난 작가의 작품 이미지는 사적 목적으로 다운로드할 수 있지만, 출판·복제 허가는 별도라고 명시한다. [이미지 권리 안내](https://www.leopoldmuseum.org/en/collection/image-rights)에서도 사진 이용 신청을 안내한다.
- 이 저장소의 한국어 설명은 팀이 작성한 문장이라는 뜻이며, 위 기관의 원문이나 사진을 앱에 재게시할 권리를 얻었다는 뜻은 아니다. 출처 URL은 참고 근거다. 이미지 사용은 작품별 `image_url`·`image_license`를 별도로 확인해야 한다. 권리 검토 전인 이미지는 `null`로 남겨 두었다.

전처리 검증 결과: 사조 6개, 작가 10명, 작품 276점, 문서 426건으로 정상 생성됐다. 실레 28작품·32문서와 클림트 29작품·33문서가 배포되며, 57점 모두 이미지 URL이 있다. 54건은 Public Domain이고, 3건은 상세 화면의 이미지 이용 문구와 원본 링크에 사진 저작자 및 CC 라이선스를 표시한다. 《작은 도시 III》, 《책이 있는 정물: 화가의 책상》, 《붉은 스케치북》의 수집 원문과 검수 이력은 보존하지만 앱·전처리 산출물·DB에서는 제외한다.

## 구스타프 클림트 (수집 30점 · 앱 표시 29점)

| 번호 | 작품 | 연도 | 해설 파일 | 근거 기관 |
| ---: | --- | --- | --- | --- |
| 1 | 숲의 바닥 | 1881/82 | [열기](data/raw/gustav-klimt/forest-floor-klimt.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/31087-forest-floor/) |
| 2 | 남성 누드 습작 | 1883 | [열기](data/raw/gustav-klimt/male-nude-klimt.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/4742/mannlicher-akt) |
| 3 | 종교 음악의 알레고리 | 1884 | [열기](data/raw/gustav-klimt/allegory-of-sacred-music.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/471/allegorie-der-kirchlichen-musik-entwurf) |
| 4 | 카를로스를 연기하는 요제프 레빈스키 | 1895 | [열기](data/raw/gustav-klimt/josef-lewinsky-as-carlos.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/6234/josef-lewinsky-als-carlos-in-clavigo) |
| 5 | 황혼: 벽난로 옆의 여인 | 1897/1898 | [열기](data/raw/gustav-klimt/dusk-lady-at-fireplace.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/4185/dammerung-dame-am-kamin) |
| 6 | 소냐 크닙스의 초상 | 1897/1898 | [열기](data/raw/gustav-klimt/portrait-of-sonja-knips.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/3197/sonja-knips) |
| 7 | 비가 온 뒤 | 1898 | [열기](data/raw/gustav-klimt/after-the-rain-klimt.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/6087/nach-dem-regen) |
| 8 | 저녁의 과수원 | 1898 | [열기](data/raw/gustav-klimt/orchard-in-the-evening.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/33818-orchard-in-the-evening/) |
| 9 | 붉은 스케치북 (앱 제외) | 1898 | [열기](data/raw/gustav-klimt/red-sketchbook-klimt.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/9997/rotes-skizzenbuch) |
| 10 | 연못가의 아침 | 1899 | [열기](data/raw/gustav-klimt/a-morning-by-the-pond.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/2148-a-morning-by-the-pond/) |
| 11 | 임종한 노인 | 1900 | [열기](data/raw/gustav-klimt/old-man-on-deathbed.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/9957/alter-mann-auf-dem-totenbett) |
| 12 | 아터제 호수 위에서 | 1900 | [열기](data/raw/gustav-klimt/on-lake-attersee.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/4328-on-lake-attersee/) |
| 13 | 베토벤 프리즈 | 1901-1902 | [열기](data/raw/gustav-klimt/beethoven-frieze.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/4737/beethovenfries) |
| 14 | 유디트 I | 1901 | [열기](data/raw/gustav-klimt/judith-i.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/3492/judith) |
| 15 | 큰 포플러 II: 몰려오는 폭풍 | 1902/03 | [열기](data/raw/gustav-klimt/the-large-poplar-ii.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/2149-the-large-poplar-ii-gathering-storm/) |
| 16 | 물뱀 I | 1904 (minor amendments in 1907) | [열기](data/raw/gustav-klimt/water-serpents-i.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/3828/freundinnen-wasserschlangen-i) |
| 17 | 해바라기가 있는 시골 정원 | 1906 | [열기](data/raw/gustav-klimt/cottage-garden-with-sunflowers.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/2483/bauerngarten-mit-sonnenblumen) |
| 18 | 프리차 리들러의 초상 | 1906 | [열기](data/raw/gustav-klimt/portrait-of-fritza-riedler.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/2177/fritza-riedler) |
| 19 | 꽃핀 양귀비 | 1907 | [열기](data/raw/gustav-klimt/flowering-poppies.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/3917/bluhender-mohn) |
| 20 | 해바라기 | 1907-1908 | [열기](data/raw/gustav-klimt/sunflower-klimt.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/21865/sonnenblume) |
| 21 | 키스 | c. 1907–1909 | [열기](data/raw/gustav-klimt/the-kiss.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/6678/der-kuss-liebespaar) |
| 22 | 두 아이와 어머니 | 1909/1910 | [열기](data/raw/gustav-klimt/mother-with-two-children-klimt.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/27315/mutter-mit-zwei-kindern-familie) |
| 23 | 죽음과 삶 | 1910/11, reworked in 1912/13 and 1915/16 | [열기](data/raw/gustav-klimt/death-and-life.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/629-death-and-life/) |
| 24 | 아터제의 카머 성 III | c. 1911/1912 | [열기](data/raw/gustav-klimt/schloss-kammer-at-attersee-iii.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/3112/schloss-kammer-am-attersee-iii) |
| 25 | 상오스트리아의 농가 | 1911 | [열기](data/raw/gustav-klimt/upper-austrian-farmhouse.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/380/oberosterreichisches-bauernhaus) |
| 26 | 카머 성으로 가는 길 | 1912 | [열기](data/raw/gustav-klimt/avenue-to-schloss-kammer.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/8691/allee-zum-schloss-kammer) |
| 27 | 아말리에 추커칸들의 초상 | 1913/14 (possibly also still in 1917) (unfinished) | [열기](data/raw/gustav-klimt/portrait-of-amalie-zuckerkandl.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/7488/amalie-zuckerkandl) |
| 28 | 아담과 이브 | 1916 - 1918 | [열기](data/raw/gustav-klimt/adam-and-eve-klimt.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/3196/adam-und-eva) |
| 29 | 흰옷을 입은 여인 | 1917/1918 | [열기](data/raw/gustav-klimt/lady-in-white-klimt.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/3080/dame-in-wei) |
| 30 | 요한나 슈타우데의 초상 | 1917/1918 | [열기](data/raw/gustav-klimt/portrait-of-johanna-staude.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/4302/johanna-staude) |

## 에곤 실레 (수집 30점 · 앱 표시 28점)

| 번호 | 작품 | 연도 | 해설 파일 | 근거 기관 |
| ---: | --- | --- | --- | --- |
| 1 | 죽은 어머니 I | 1910 | [열기](data/raw/egon-schiele/dead-mother-i.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/549-dead-mother-i/) |
| 2 | 앉아 있는 남성 누드 자화상 | 1910 | [열기](data/raw/egon-schiele/seated-male-nude-self-portrait.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/539-seated-male-nude-self-portrait/) |
| 3 | 죽은 도시 III | 1911 | [열기](data/raw/egon-schiele/dead-city-iii.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/534-dead-city-iii-city-on-the-blue-river-iii/) |
| 4 | 까마귀가 있는 풍경 | 1911 | [열기](data/raw/egon-schiele/landscape-with-ravens.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/46-landscape-with-ravens/) |
| 5 | 서정시인 | 1911 | [열기](data/raw/egon-schiele/lyricist-schiele.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/524-lyricist/) |
| 6 | 자기를 보는 사람들 II | 1911 | [열기](data/raw/egon-schiele/self-seers-ii.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/525-self-seers-ii-death-and-man/) |
| 7 | 흔들리는 공기 속의 가을 나무 | 1912 | [열기](data/raw/egon-schiele/autumn-tree-in-stirred-air.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/523-autumn-tree-in-stirred-air-winter-tree/) |
| 8 | 갈바리아 | 1912 | [열기](data/raw/egon-schiele/calvary-schiele.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/554-calvary/) |
| 9 | 애무: 추기경과 수녀 | 1912 | [열기](data/raw/egon-schiele/caress-cardinal-and-nun.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/529-caress-cardinal-and-nun/) |
| 10 | 어머니와 아이 | 1912 | [열기](data/raw/egon-schiele/mother-and-child-schiele.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/651-mother-and-child/) |
| 11 | 애도하는 여인 | 1912 | [열기](data/raw/egon-schiele/mourning-woman.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/535-mourning-woman/) |
| 12 | 발리 노이칠의 초상 | 1912 | [열기](data/raw/egon-schiele/portrait-of-wally.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/527-portrait-of-wally-neuzil/) |
| 13 | 꽈리 열매가 있는 자화상 | 1912 | [열기](data/raw/egon-schiele/self-portrait-with-chinese-lantern-plant.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/528-self-portrait-with-chinese-lantern-plant/) |
| 14 | 고개를 숙인 자화상 | 1912 | [열기](data/raw/egon-schiele/self-portrait-with-lowered-head.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/536-self-portrait-with-lowered-head/) |
| 15 | 은둔자들 | 1912 | [열기](data/raw/egon-schiele/the-hermits-schiele.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/540-hermits/) |
| 16 | 지는 해 | 1913 | [열기](data/raw/egon-schiele/setting-sun-schiele.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/624-setting-sun/) |
| 17 | 작은 도시 III (앱 제외) | 1913 | [열기](data/raw/egon-schiele/small-town-iii.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/1-the-small-town-iii/) |
| 18 | 도나우강의 슈타인 II | 1913 | [열기](data/raw/egon-schiele/stein-on-the-danube-ii.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/553-stein-on-the-danube-ii/) |
| 19 | 눈먼 어머니 | 1914 | [열기](data/raw/egon-schiele/blind-mother-schiele.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/2-blind-mother/) |
| 20 | 바닷가의 집들 | 1914 | [열기](data/raw/egon-schiele/houses-by-the-sea.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/526-houses-by-the-sea-row-of-houses/) |
| 21 | 블타바강의 크루마우 | 1914 | [열기](data/raw/egon-schiele/krumau-on-the-vltava.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/654-krumau-on-the-vltava-the-small-town-iv/) |
| 22 | 책이 있는 정물: 화가의 책상 (앱 제외) | 1914–16 | [열기](data/raw/egon-schiele/still-life-with-books.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/532-still-life-with-books-the-artists-desk/) |
| 23 | 집들의 초승달 II | 1915 | [열기](data/raw/egon-schiele/crescent-of-houses-ii.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/530-crescent-of-houses-ii-island-town/) |
| 24 | 죽음과 소녀 | 1915 | [열기](data/raw/egon-schiele/death-and-the-maiden-schiele.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/1968/tod-und-madchen) |
| 25 | 강가의 집 벽 | 1915 | [열기](data/raw/egon-schiele/house-wall-on-the-river.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/542-house-wall-on-the-river/) |
| 26 | 널지붕을 얹은 집 | 1915 | [열기](data/raw/egon-schiele/house-with-shingle-roof.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/543-house-with-shingle-roof-old-house-ii/) |
| 27 | 두 아이와 어머니 II | 1915 | [열기](data/raw/egon-schiele/mother-with-two-children-ii.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/531-mother-with-two-children-ii/) |
| 28 | 변용: 눈먼 사람들 II | 1915 | [열기](data/raw/egon-schiele/transfiguration-the-blind-ii.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/541-transfiguration-the-blind-ii/) |
| 29 | 누워 있는 여인 | 1917 | [열기](data/raw/egon-schiele/reclining-woman-schiele.md) | [레오폴트 미술관](https://onlinecollection.leopoldmuseum.org/en/object/625-reclining-woman/) |
| 30 | 가족 | 1918 | [열기](data/raw/egon-schiele/the-family-schiele.md) | [벨베데레 미술관](https://sammlung.belvedere.at/objects/3071/kauerndes-menschenpaar-die-familie) |
