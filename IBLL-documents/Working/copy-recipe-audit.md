# UX 문구와 레시피 검토 기록

검토일: 2026-09-05. 로컬 수정본이며 커밋·푸시·배포하지 않았습니다.

## 목적과 범위

Reffi의 한국어·영어 UX 문구와 기본 레시피를 실제 앱 동작에 맞게 다듬은 기록입니다. 리뷰하는 디자이너·개발자를 위한 작업 문서이며, 새로운 제품 명세나 조리 안전 인증을 정하지 않습니다.

- 기준: Heejae의 PR #22가 머지된 `1df84e091eddfcbdc63a5120191c5bd20cc25334`.
- 최신 main을 fast-forward로 받은 뒤 기존 사용자 레이아웃 변경을 복원했습니다. 영수증 시트·알림 시간 시트 충돌은 최신 동작과 기존 SheetShell 인셋을 함께 보존하는 방향으로 해결했습니다.
- 기존 변경의 백업 `codex-pre-sync-2026-09-04-pr22` stash는 남겨 두었습니다.
- 검토 대상: UI 카탈로그 384개 키, 권한 설명, 레시피 128개의 이름·소개·재료·조리 단계 658쌍.
- 변경: 카탈로그 키 23개 교체 및 기존 키 7개의 한국어 개선, 권한 설명 2종, 레시피 소개 128쌍, 영어 이름 2개, 5개 레시피의 재료 표기, 61개 레시피의 조리 단계 77쌍.
- 데이터 구조, 레시피 ID, 추천 알고리즘, 인분·시간 수치, 사용자 레시피는 변경하지 않았습니다.

## 기준과 참고 자료

제품 규칙의 정본은 `CLAUDE.md`와 `design_system.md`입니다. 최근 커밋의 짧은 행동 라벨, 별도 접근성 설명, 단서 카드와 영상 중심 조리 경로를 유지했습니다. Humanizer로 반복되는 설명 틀과 과장된 보장을 걷어낸 뒤, 한국어 맞춤법·해요체·용어 일관성을 검토했습니다. 레시피의 간결한 설명체는 유지했습니다.

- 문구는 짧기만 한 것보다 사용자가 할 행동과 그 결과가 분명해야 합니다. [Apple Writing](https://developer.apple.com/design/human-interface-guidelines/writing), [Material communication guidance](https://codelabs.developers.google.com/codelabs/material-communication-guidance)
- 오류에는 복구 방법을, 권한에는 실제 사용 목적을 적었습니다. [GOV.UK Error message](https://design-system.service.gov.uk/components/error-message/), [Apple Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)
- 조리 단계는 동작, 불 세기, 시간과 익힘 기준을 구분했습니다. 분량과 실제 조리 시험이 없는 상태의 한계는 아래에 별도로 남겼습니다. [Virginia Tech Recipe Writing](https://www.pubs.ext.vt.edu/content/pubs_ext_vt_edu/en/FST/FST-155/FST-155.html)
- 고기·생선의 익힘 온도는 미국 소비자용 공식 안내를 참고했습니다. 이는 한국의 모든 식품·조리 환경에 대한 법적 기준을 의미하지 않습니다. [FoodSafety.gov 온도표](https://www.foodsafety.gov/food-safety-charts/safe-minimum-internal-temperatures)
- 생닭 세척 제거와 교차오염 예방: [CDC Chicken](https://www.cdc.gov/food-safety/foods/chicken.html)
- 달걀 완전 가열과 저가열 소스의 살균 달걀 사용: [FDA Egg Safety](https://www.fda.gov/food/buy-store-serve-safe-food/what-you-need-know-about-egg-safety)
- 조개 선별·가열과 해산물 익힘: [FDA Seafood](https://www.fda.gov/food/buy-store-serve-safe-food/selecting-and-serving-fresh-and-frozen-seafood-safely)
- 팽이버섯 충분한 가열: [FDA Enoki Advisory](https://www.fda.gov/food/alerts-advisories-safety-information/fda-advises-restaurants-and-retailers-not-serve-or-sell-and-consumers-not-eat-product-labeled-sun)

## 적용한 판단

1. 자동으로 냉장고에 들어간다고 보이던 영수증 안내를 스캔 → 확인 → 추가의 실제 순서로 고쳤습니다. 카메라 권한 설명도 같은 뜻으로 맞췄습니다.
2. 소비기한은 확정값이 아닌 추정값임을 알리고, 포장 확인과 수정 경로를 안내했습니다.
3. '낭비 없음' 보장과 근거 없는 칭찬 대신 현재 화면이 집계하는 최근 30일 기록을 설명했습니다.
4. 추천 구제 조건은 사용 재료 수 ≥ 부족한 재료 수이므로, '더 많이'라는 잘못된 표현을 바로잡았습니다. 여기서 수는 분량이 아닌 재료 종류 수입니다.
5. 레시피 소개는 반복되는 국가명과 '…의 요리' 틀 대신 실제 재료·맛·조리법을 먼저 적었습니다. 데이터에 없는 파스타·콩·소스 등은 추가하지 않았습니다.
6. 생닭 씻기, 달걀을 덜 익힌 채 마무리하기, 생고기에 국물만 붓기, 맑은 육즙만으로 익힘 판단하기를 수정했습니다. 냉장 양념 재우기, 조개 선별, 오븐 예열, 충분히 삶은 고사리 사용도 명확히 했습니다.
7. 국물이나 팬에 이미 들어간 온도계 기준은 해당 재료의 중심 온도를 뜻합니다. 시간만 지났다고 익힘이 보장되는 표현을 피했습니다.

## UX 문구 변경 목록

줄바꿈은 표에서 `<br>`로 표시합니다. 영어가 카탈로그 키이며 한국어는 별도 검토했습니다.

| 이전 영어 | 수정 영어 | 수정 한국어 |
| --- | --- | --- |
| %@ won't last long.<br>Cook it today. | Use %@ soon.<br>Find a recipe to try. | 곧 써야 할 재료: %@.<br>만들 요리를 찾아보세요. |
| 3–4 | 3-4 | 3~4인 |
| Add a few ingredients, then start cooking. | Add ingredients to find something to cook. | 재료를 추가하면 만들 수 있는 요리를 찾아드려요. |
| Add what you buy.<br>We'll count down the expiry dates. | Add what you buy.<br>Keep track of use-by dates. | 산 재료를 추가하고<br>소비기한을 확인해요. |
| Allow notifications for Reffi in Settings to get expiry alerts. | Allow notifications for Reffi in Settings to get use-by alerts. | 설정에서 Reffi 알림을 허용하면 소비기한 임박 알림을 받을 수 있어요. |
| Check ingredient spellings or restock to see more tickets. | Check ingredient names or add more ingredients. | 재료 이름을 확인하거나 재료를 더 추가해 보세요. |
| Clears more than it asks you to buy. | Uses at least as many ingredients as you need to buy. | 사야 할 재료 수만큼은 냉장고 재료를 써요. |
| Days without waste<br>add up to a report | See what you ate<br>and what you tossed | 먹은 재료와 버린 재료를<br>한눈에 |
| Eat it today, waste nothing | Eat it today, waste less | 오늘 먹고, 덜 버려요 |
| Eat the most urgent ingredients first, top to bottom. | Start with the ingredients that need using first. | 먼저 써야 할 재료부터 요리에 활용해요. |
| Expiry alerts | Use-by alerts | 임박 알림 |
| No waste yet. Nicely done. | Nothing tossed in the past 30 days. | 최근 30일 동안 버린 재료가 없어요. |
| Nothing recognized | No items found | 찾은 재료가 없어요 |
| Pick as many as you like.<br>Recipes will follow. | Pick the kinds of food you like.<br>We'll use them for recommendations. | 좋아하는 요리를 골라 주세요.<br>추천에 반영할게요. |
| Restock sized for %@ | Shopping for: %@ | 장보기 기준: %@ |
| Sealed items keep their long dates until opened.<br>Checked ones switch to the after-opening use-by date. | Check the items you've opened.<br>Their use-by dates will update. | 개봉한 재료를 체크해 주세요.<br>개봉 후 소비기한으로 바뀌어요. |
| Snap the receipt.<br>Groceries land in your fridge. | Scan your receipt.<br>Check the items, then add them. | 영수증을 찍고<br>담을 재료를 확인해요. |
| Tuned for %@ | Your choices: %@ | 고른 취향: %@ |
| Turn %@ and %@ into your own recipe.<br>Add it in Profile. | Have a recipe for %@ and %@?<br>Add it in Profile. | %1$@, %2$@로 해 먹는 요리가 있나요?<br>프로필에 레시피를 추가해 보세요. |
| Turn %@ into your own recipe.<br>Add it in Profile. | Have a recipe for %@?<br>Add it in Profile. | %@로 해 먹는 요리가 있나요?<br>프로필에 레시피를 추가해 보세요. |
| Use a clearer photo. | Try a clearer photo of the whole receipt. | 영수증 전체가 선명하게 나온 사진으로 다시 시도해 주세요. |
| Use-by dates are filled from the ingredient dictionary.<br>Adjust anytime in Fridge. | Use-by dates are estimates.<br>Check the packaging and adjust them in Fridge. | 소비기한은 추정값이에요.<br>포장에 적힌 기한을 확인하고 냉장고에서 수정해 주세요. |
| We'll size your restock amounts to match. | We'll use this as a guide for shopping quantities. | 장보기 수량을 정할 때 참고할게요. |

### 영어는 유지하고 한국어만 수정한 항목

| 영어 키 | 이전 한국어 | 수정 한국어 |
| --- | --- | --- |
| Add it as typed, or try another name. | 친 그대로 담거나, 다른 이름으로 찾아보세요. | 입력한 이름으로 담거나 다른 이름으로 찾아보세요. |
| Adds the name exactly as typed. | 친 그대로 목록에 담아요. | 입력한 이름 그대로 목록에 담아요. |
| Each week shows what you ate and what you tossed. | 매주 먹은 것과 버린 것을 보여드려요. | 매주 먹은 재료와 버린 재료를 확인해요. |
| Freshest first | 신선한순 | 신선한 순 |
| Recently added | 최근 등록순 | 최근 등록 순 |
| Removes it without history.<br>Stats and the shopping list won't count it. | 기록 없이 삭제돼요.<br>통계와 쇼핑리스트에 반영되지 않아요. | 기록 없이 삭제돼요.<br>통계와 살 것 목록에 반영되지 않아요. |
| Saves %lld expiring today | 오늘 만료 %lld개 구출 | 오늘까지인 재료 %lld개 구출 |

온보딩에 카탈로그에 없던 “Watch your no-waste streak grow, day by day.”가 직접 쓰이고 있어 기존 주간 집계 설명 키로 연결했습니다. `scripts/check-strings.py`가 `body:` 인자도 검사하도록 보완했습니다. 권한 설명은 `InfoPlist.xcstrings`, `project.yml`, 생성된 `Info.plist`를 맞췄습니다.

## 레시피별 수정 결과

모든 행의 소개가 변경됐습니다. 마지막 열은 변경한 조리 단계 번호이며, 빈 칸은 소개만 또는 이름·재료 표기만 바뀐 경우입니다. 한영 단계 순서와 개수는 유지했습니다.

| 레시피 ID / 이름 | 영어 소개 | 한국어 소개 | 수정 단계 |
| --- | --- | --- | --- |
| kimchi-jjigae<br>김치찌개 | Well-aged kimchi, pork and tofu simmered into a tangy Korean stew. | 잘 익은 김치에 돼지고기와 두부를 넣고 푹 끓인 찌개. |  |
| doenjang-jjigae<br>된장찌개 | Tofu and vegetables simmered in a savory soybean paste broth. | 된장을 풀어 두부와 채소를 넣고 구수하게 끓인 찌개. |  |
| beef-bulgogi<br>소불고기 | Thin slices of beef cooked with onion in a sweet soy marinade. | 얇은 소고기를 달큰한 간장 양념에 재워 양파와 볶은 불고기. | 2 |
| jeyuk-bokkeum<br>제육볶음 | Sliced pork and onion stir-fried in a spicy gochujang sauce. | 돼지고기와 양파를 고추장 양념에 매콤하게 볶은 밥반찬. | 2, 5 |
| gyeran-mari<br>계란말이 | Layers of egg rolled around finely chopped carrot and green onion. | 잘게 썬 당근과 파를 넣어 겹겹이 말아 부친 계란말이. | 5 |
| japchae<br>잡채 | Chewy glass noodles tossed with beef, spinach and other vegetables. | 쫄깃한 당면에 소고기와 시금치, 채소를 넣고 버무린 잡채. |  |
| bibimbap<br>비빔밥 | Rice topped with seasoned vegetables, beef and egg, ready to mix with gochujang. | 밥 위에 나물, 소고기, 계란을 얹어 고추장에 비벼 먹는 한 그릇. | 3, 4 |
| kimchi-fried-rice<br>김치볶음밥 | Sour kimchi and Spam stir-fried with rice, topped with an egg. | 신 김치와 스팸을 밥과 함께 볶고 계란을 올린 볶음밥. |  |
| kongnamul-guk<br>콩나물국 | Bean sprouts in a clear anchovy broth with garlic and green onion. | 멸치 육수에 콩나물과 마늘, 대파를 넣어 맑게 끓인 국. |  |
| miyeok-guk<br>미역국 | Seaweed and beef simmered together in a savory Korean soup. | 미역과 소고기를 참기름에 볶아 푹 끓인 국. |  |
| galbi-jjim<br>갈비찜 | Beef short ribs slowly braised in sweet soy sauce with radish and carrot. | 소갈비를 무, 당근과 함께 달큰한 간장 양념에 푹 조린 갈비찜. | 1 |
| dak-bokkeum-tang<br>닭볶음탕 | Chicken and potatoes braised in a spicy gochujang broth. | 닭과 감자를 매콤한 고추장 국물에 자작하게 끓인 닭볶음탕. | 1, 4 |
| tteokbokki<br>떡볶이 | Chewy rice cakes and fish cakes simmered in a sweet, spicy sauce. | 떡과 어묵을 매콤달콤한 고추장 양념에 끓인 떡볶이. |  |
| kimchi-jeon<br>김치전 | Chopped kimchi in a thin pancake with crisp edges. | 잘게 썬 김치를 반죽에 섞어 가장자리가 바삭하게 부친 전. |  |
| oi-muchim<br>오이무침 | Cucumber tossed with gochugaru and vinegar for a sharp, crunchy side. | 오이를 고춧가루와 식초 양념에 아삭하고 새콤하게 무친 반찬. |  |
| sigeumchi-namul<br>시금치나물 | Blanched spinach gently dressed with garlic and sesame oil. | 데친 시금치를 마늘과 참기름에 조물조물 무친 나물. |  |
| gamja-jorim<br>감자조림 | Bite-size potatoes braised in sweet soy sauce until glossy. | 한입 크기 감자를 달큰한 간장 양념에 윤기 나게 조린 반찬. |  |
| eomuk-bokkeum<br>어묵볶음 | Fish cakes stir-fried with onion and carrot in a light soy glaze. | 어묵을 양파, 당근과 함께 간장 양념에 볶은 밑반찬. |  |
| sundubu-jjigae<br>순두부찌개 | Silken tofu and pork in a spicy broth, finished with an egg. | 순두부와 돼지고기를 얼큰하게 끓이고 계란을 넣은 찌개. | 2, 5 |
| gimbap<br>김밥 | Rice, egg and vegetables rolled in seaweed and sliced into rounds. | 밥과 계란, 채소를 김에 단단히 말아 한입 크기로 썬 김밥. |  |
| samgyeopsal-gui<br>삼겹살구이와 쌈 | Grilled pork belly wrapped in lettuce and perilla leaves with ssamjang. | 노릇하게 구운 삼겹살을 상추, 깻잎에 쌈장과 함께 싸 먹는 구이. |  |
| dak-juk<br>닭죽 | Rice simmered in chicken broth until soft, with shredded chicken and carrot. | 닭 육수에 쌀과 당근을 푹 끓이고 닭살을 넣어 부드럽게 쑨 죽. | 1 |
| gyudon<br>규동 | Thinly sliced beef and onion in sweet soy broth over hot rice. | 얇은 소고기와 양파를 달큰하게 조려 따뜻한 밥에 얹은 일본식 덮밥. | 4 |
| oyakodon<br>오야코동 | Chicken and egg gently simmered with onion and served over rice. | 닭고기와 계란을 양파와 함께 조려 밥 위에 얹은 일본식 덮밥. | 2, 5 |
| miso-soup<br>미소시루 | Tofu and wakame warmed in dashi with miso paste. | 가쓰오 육수에 미소 된장을 풀고 두부와 미역을 넣은 국. |  |
| yakisoba<br>야키소바 | Wheat noodles stir-fried with pork and cabbage in a tangy sauce. | 돼지고기와 양배추를 넣고 새콤달콤한 소스에 볶은 일본식 면요리. |  |
| japanese-curry-rice<br>카레라이스 | A mild, thick curry with meat, potato and carrot, served over rice. | 고기, 감자, 당근을 넣어 걸쭉하게 끓이고 밥에 곁들이는 카레. |  |
| chawanmushi<br>일본식 계란찜 (자완무시) | Savory steamed egg custard with shrimp and shiitake mushrooms. | 육수에 푼 계란에 새우와 표고버섯을 넣어 부드럽게 찐 자완무시. | 4 |
| grilled-salmon-teishoku<br>연어구이 정식 | Salted salmon grilled and served with rice, grated radish and lemon. | 소금 간해 구운 연어에 밥, 간 무, 레몬을 곁들인 정식. | 4 |
| egg-fried-rice<br>계란볶음밥 | Rice and scrambled egg tossed over high heat with green onion. | 밥과 계란을 대파와 함께 센 불에 빠르게 볶은 볶음밥. |  |
| mapo-tofu<br>마파두부 | Tofu and ground pork simmered in a spicy doubanjiang sauce. | 두부와 다진 돼지고기를 매콤한 두반장 소스에 끓인 마파두부. | 4 |
| bok-choy-stir-fry<br>청경채 마늘볶음 | Bok choy quickly stir-fried with garlic and oyster sauce. | 청경채를 마늘, 굴소스와 함께 센 불에 재빨리 볶은 채소 요리. |  |
| kkanpung-chicken<br>깐풍기풍 닭요리 | Crisp fried chicken tossed in a sweet, garlicky chili sauce. | 바삭하게 튀긴 닭을 마늘과 고추가 들어간 새콤달콤한 소스에 버무린 요리. | 2 |
| tomato-egg-stir-fry<br>토마토 계란볶음 | Soft scrambled eggs folded into juicy cooked tomatoes. | 촉촉하게 익힌 토마토에 부드러운 스크램블에그를 넣고 볶은 요리. |  |
| chicken-chow-mein<br>닭고기 볶음면 | Wheat noodles tossed with chicken and vegetables in soy and oyster sauce. | 닭고기와 채소를 넣고 간장, 굴소스에 볶은 중화풍 볶음면. | 2, 5 |
| pad-thai<br>팟타이 | Thai rice noodles with shrimp, tamarind sauce and crushed peanuts. | 새우와 쌀국수를 타마린드 소스에 볶아 땅콩을 올린 태국식 볶음면. | 5 |
| thai-green-curry<br>그린커리 | Chicken and vegetables simmered in coconut milk and green curry paste. | 닭고기와 채소를 코코넛 밀크, 그린커리 페이스트에 끓인 태국식 커리. | 4 |
| banh-mi-sandwich<br>반미풍 샌드위치 | A baguette filled with pork, pickled vegetables and fresh herbs. | 바게트에 돼지고기와 절인 채소, 허브를 채운 반미풍 샌드위치. |  |
| nasi-goreng<br>나시고렝 | Indonesian fried rice seasoned with sweet soy sauce and topped with an egg. | 달콤한 간장에 밥을 볶고 계란을 올린 인도네시아식 볶음밥. | 2 |
| quick-beef-pho<br>소고기 쌀국수 | Rice noodles in an aromatic broth with thinly sliced beef and green onion. | 향신료를 넣은 국물에 쌀국수와 얇은 소고기를 익혀 담고 파를 올린 국수. | 5, 6 |
| tomato-pasta<br>토마토 파스타 | Pasta tossed in tomato sauce simmered with garlic and olive oil. | 토마토를 마늘, 올리브유와 함께 졸인 소스에 버무린 파스타. |  |
| carbonara-style-pasta<br>까르보나라풍 파스타 | Pasta coated in egg and cheese sauce with crisp bacon. | 바삭한 베이컨을 넣고 계란과 치즈 소스에 버무린 파스타. | 3 |
| aglio-e-olio<br>알리오 올리오 | Pasta tossed with garlic, olive oil and chili. | 마늘과 올리브유, 고추로 맛을 낸 파스타. |  |
| margherita-toast<br>마르게리타풍 토스트 | Toast topped with tomato and melted mozzarella, with basil if you like. | 토마토와 모차렐라를 올려 치즈를 녹이고 취향껏 바질을 더한 토스트. |  |
| minestrone<br>미네스트로네 | A chunky Italian soup with potato, zucchini and other vegetables. | 감자, 주키니, 채소를 넣어 건더기가 든든한 이탈리아식 수프. |  |
| mushroom-risotto<br>버섯 리조또 | Rice slowly stirred with stock and mushrooms until creamy. | 쌀에 육수를 조금씩 부으며 버섯과 함께 부드럽게 익힌 리조또. |  |
| caprese-salad<br>카프레제 | Sliced tomato, mozzarella and basil with olive oil and a little vinegar. | 토마토, 모차렐라, 바질에 올리브유와 식초를 곁들인 샐러드. |  |
| lasagna-style-bake<br>라자냐풍 베이크 | Layers of pasta, meat sauce and cheese baked until bubbling. | 파스타, 미트소스, 치즈를 겹겹이 쌓아 오븐에 구운 요리. | 1, 6 |
| scrambled-eggs<br>스크램블에그 | Eggs gently stirred in butter until soft and just set. | 계란을 버터에 천천히 저어 부드럽게 익힌 스크램블에그. | 5 |
| cheese-omelette<br>치즈 오믈렛 | An omelette folded around melted cheese. | 계란을 부쳐 녹인 치즈를 넣고 반으로 접은 오믈렛. | 5 |
| pancakes<br>팬케이크 | Thick, fluffy pancakes served with honey or syrup. | 도톰하게 부친 팬케이크에 꿀이나 시럽을 곁들인 한 접시. |  |
| french-toast<br>프렌치토스트 | Bread soaked in egg and milk, then pan-fried until golden. | 빵을 계란과 우유에 적셔 노릇하게 구운 프렌치토스트. | 4 |
| grilled-cheese<br>그릴드 치즈 샌드위치 | Buttered bread grilled until crisp with melted cheese in the middle. | 버터 바른 빵 사이에 치즈를 넣고 겉을 바삭하게 구운 샌드위치. |  |
| blt-sandwich<br>BLT 샌드위치 | Crisp bacon, lettuce and tomato layered on bread with mayonnaise. | 바삭한 베이컨과 상추, 토마토에 마요네즈를 곁들인 샌드위치. |  |
| chicken-salad<br>치킨 샐러드 | Sliced chicken over crisp vegetables with a lemon and mustard dressing. | 아삭한 채소에 구운 닭가슴살을 올리고 레몬 머스터드 드레싱을 곁들인 샐러드. | 1 |
| mashed-potatoes<br>매쉬드 포테이토 | Boiled potatoes mashed smooth with butter and warm milk. | 삶은 감자에 버터와 따뜻한 우유를 넣어 곱게 으깬 요리. |  |
| burger-patty<br>수제 버거 패티 | Ground beef mixed with onion and egg, shaped into patties and pan-fried. | 다진 소고기에 양파와 계란을 섞어 빚고 팬에 구운 패티. | 5 |
| mac-and-cheese<br>맥앤치즈 | Macaroni folded into a creamy cheese sauce made with butter and milk. | 버터와 우유로 만든 치즈 소스에 마카로니를 버무린 요리. |  |
| quesadilla<br>퀘사디아 | A tortilla filled with cheese and vegetables, folded and toasted in a pan. | 토르티야에 치즈와 채소를 채워 접고 팬에 구운 퀘사디아. |  |
| beef-tacos<br>소고기 타코 | Small tortillas filled with seasoned ground beef and fresh vegetables. | 작은 토르티야에 양념한 다진 소고기와 채소를 채운 타코. | 2 |
| burrito-bowl<br>부리토볼 | Rice topped with chicken, corn and vegetables, finished with lime. | 밥 위에 닭고기, 옥수수, 채소를 올리고 라임을 곁들인 부리토볼. | 1 |
| salsa-and-nachos<br>살사와 나초 | Fresh tomato salsa served with crisp, pan-toasted tortilla wedges. | 생 토마토 살사에 팬에서 바삭하게 구운 토르티야 조각을 곁들인 요리. | 2 |
| chicken-fajitas<br>치킨 파히타 | Sizzling chicken and peppers to wrap in warm tortillas. | 닭고기와 파프리카를 구워 따뜻한 토르티야에 싸 먹는 파히타. | 2 |
| ratatouille<br>라따뚜이 | Eggplant, zucchini and other vegetables slowly stewed with tomato. | 가지, 주키니, 채소를 토마토와 함께 뭉근히 익힌 라따뚜이. |  |
| cream-of-mushroom-soup<br>버섯 크림수프 | Mushrooms simmered with milk and cream in a thick, buttery soup. | 볶은 버섯에 우유와 크림을 넣어 걸쭉하게 끓인 수프. |  |
| potato-gratin<br>감자 그라탕 | Thinly sliced potatoes baked in cream with a browned cheese topping. | 얇은 감자에 크림과 치즈를 넣어 윗면이 노릇하게 구운 그라탕. | 1, 4 |
| crepes<br>크레페 | Thin pancakes made by swirling a light batter across the pan. | 묽은 반죽을 팬에 얇게 돌려 펴 부친 크레페. |  |
| french-onion-soup<br>프렌치 어니언 수프 | Slowly browned onions in broth, topped with toasted bread and melted cheese. | 양파를 오래 볶아 끓인 국물에 빵과 녹인 치즈를 얹은 수프. |  |
| nicoise-style-salad<br>니수아즈풍 샐러드 | Tuna, boiled egg and potato over greens with a mustard dressing. | 채소 위에 참치, 삶은 계란, 감자를 올리고 머스터드로 맛낸 샐러드. |  |
| schnitzel-style-cutlet<br>슈니첼풍 포크 커틀릿 | Pork loin pounded thin, coated in breadcrumbs and fried until crisp. | 돼지 등심을 얇게 두드려 빵가루를 입히고 바삭하게 튀긴 커틀릿. | 4 |
| butter-chicken-style-curry<br>버터치킨풍 커리 | Chicken simmered in a spiced tomato sauce with butter and cream. | 닭고기를 향신료, 버터, 크림이 들어간 토마토 소스에 끓인 커리. | 4 |
| chickpea-curry<br>병아리콩 커리 | Chickpeas simmered with tomato, onion and warm spices. | 병아리콩을 토마토, 양파, 향신료와 함께 끓인 커리. |  |
| hummus-with-flatbread<br>후무스와 플랫브레드 | Chickpeas blended with tahini, lemon and garlic, served with flatbread. | 병아리콩을 타히니, 레몬, 마늘과 갈아 플랫브레드에 곁들인 후무스. |  |
| shakshuka<br>샥슈카 | Eggs gently cooked in a spiced tomato and pepper sauce. | 향신료를 넣은 토마토, 파프리카 소스에 계란을 익힌 샥슈카. | 4 |
| tandoori-style-chicken<br>탄두리풍 치킨구이 | Chicken marinated in yogurt and spices, then roasted until browned. | 닭고기를 요거트와 향신료에 재워 노릇하게 구운 탄두리풍 치킨. | 3, 4 |
| salmon-steak<br>연어 스테이크 | Salmon fillet seared skin-side down and basted with lemon butter. | 연어를 껍질부터 바삭하게 구워 레몬 버터를 끼얹은 요리. | 4 |
| garlic-butter-shrimp<br>갈릭버터새우 | Shrimp sauteed in garlic butter with a squeeze of lemon. | 새우를 마늘 버터에 볶아 레몬즙을 뿌린 요리. |  |
| pan-seared-steak<br>팬시어드 스테이크 | Pan-seared steak basted with garlic butter and rested before slicing. | 팬에 구운 스테이크에 마늘 버터를 끼얹고 잠시 두었다 써는 요리. | 1, 5 |
| vegetable-soup<br>야채수프 | Potato, carrot and other vegetables simmered in a clear broth. | 감자, 당근, 채소를 넣어 맑게 끓인 수프. |  |
| vegetable-frittata<br>야채 프리타타 | Vegetables and cheese baked into a thick, open-faced omelette. | 채소와 치즈를 계란에 넣어 도톰하게 익힌 프리타타. | 1, 4 |
| jjajang-bap<br>짜장밥 | Rice topped with pork and vegetables in a thick chunjang sauce. | 돼지고기와 채소를 춘장에 볶아 걸쭉하게 끓이고 밥에 얹은 짜장밥. |  |
| gyeran-jjim<br>뚝배기 계란찜 | Eggs steamed in an earthenware pot with salted shrimp and green onion. | 새우젓으로 간한 계란을 뚝배기에 부풀려 익히고 파를 올린 계란찜. | 5 |
| myeongran-pasta<br>명란 파스타 | Pasta in a butter and cream sauce seasoned with salted pollock roe. | 명란으로 간한 버터 크림 소스에 버무린 파스타. |  |
| mechurial-jangjorim<br>메추리알 장조림 | Quail eggs and beef slowly braised in sweet soy sauce. | 메추리알과 소고기를 달큰한 간장 양념에 조린 장조림. | 1, 6 |
| ori-jumulleok<br>오리주물럭 | Duck marinated in gochujang and stir-fried with onion and green onion. | 오리고기를 고추장 양념에 재워 양파, 대파와 함께 볶은 주물럭. | 3, 5 |
| mandu-guk<br>만둣국 | Dumplings simmered in clear broth, finished with egg and seaweed. | 만두를 맑은 국물에 끓이고 계란과 김을 올린 만둣국. | 4 |
| rabokki<br>라볶이 | Rice cakes and instant noodles cooked together in a spicy sauce. | 떡과 라면 사리를 매콤한 양념에 함께 끓인 라볶이. |  |
| corn-cheese<br>콘치즈 | Sweetcorn mixed with mayonnaise and topped with melted mozzarella. | 옥수수를 마요네즈에 버무리고 모차렐라를 올려 녹인 콘치즈. |  |
| matsal-gyeran-mari<br>맛살계란말이 | A rolled omelette with crab sticks running through the center. | 가운데에 게맛살을 넣고 돌돌 말아 부친 계란말이. | 6 |
| sausage-yachae-bokkeum<br>소시지야채볶음 | Small sausages and vegetables stir-fried in a sweet ketchup sauce. | 소시지와 채소를 달콤한 케첩 양념에 볶은 반찬. |  |
| yubu-chobap<br>유부초밥 | Sweet fried tofu pockets filled with tangy seasoned rice. | 달콤한 조미유부에 새콤하게 간한 밥을 채운 유부초밥. |  |
| saesongi-butter-gui<br>새송이버섯 버터구이 | King oyster mushrooms seared in butter with garlic and soy sauce. | 새송이버섯을 버터에 굽고 마늘과 간장으로 맛을 낸 요리. |  |
| paengi-beoseot-jeon<br>팽이버섯전 | Small bundles of enoki mushrooms coated in flour and egg, then pan-fried. | 팽이버섯을 작은 묶음으로 나눠 밀가루와 계란물을 입혀 부친 전. | 5 |
| yangsongi-soup<br>양송이수프 | Button mushrooms blended with milk into a smooth, buttery soup. | 양송이버섯을 버터에 볶아 우유와 곱게 갈고 끓인 수프. |  |
| goguma-mattang<br>고구마맛탕 | Fried sweet potato chunks coated in a glossy sugar syrup. | 튀긴 고구마를 설탕 시럽에 버무려 윤기 나게 만든 맛탕. |  |
| danhobak-juk<br>단호박죽 | Steamed kabocha pumpkin mashed and simmered into a smooth porridge. | 찐 단호박을 곱게 으깨 뭉근하게 끓인 부드러운 죽. |  |
| yeongeun-jorim<br>연근조림 | Lotus root slices braised in sweet soy sauce until glossy. | 연근을 얇게 썰어 달큰한 간장 양념에 윤기 나게 조린 반찬. |  |
| baechu-jeon<br>배추전 | Whole napa cabbage leaves dipped in thin batter and pan-fried flat. | 배춧잎에 묽은 반죽을 입혀 납작하게 부친 배추전. |  |
| buchu-jeon<br>부추전 | A savory pancake packed with garlic chives and crisp around the edges. | 부추를 듬뿍 넣어 가장자리가 바삭하게 부친 전. |  |
| sukju-namul<br>숙주나물무침 | Blanched mung bean sprouts tossed with sesame oil and garlic. | 데친 숙주를 참기름과 마늘에 조물조물 무친 나물. |  |
| yeolmu-bibim-guksu<br>열무비빔국수 | Cold noodles tossed with young radish and a tangy gochujang sauce. | 차가운 국수에 열무와 새콤달콤한 고추장 양념을 넣어 비빈 요리. | 3, 4 |
| minari-muchim<br>미나리무침 | Water parsley lightly blanched and tossed in a tangy gochujang dressing. | 미나리를 살짝 데쳐 새콤한 초고추장에 무친 반찬. |  |
| ojingeo-bokkeum<br>오징어볶음 | Squid and vegetables quickly stir-fried in a spicy gochujang sauce. | 오징어와 채소를 매콤한 고추장 양념에 센 불로 볶은 요리. |  |
| bajirak-tang<br>바지락탕 | Clams simmered with radish and garlic in a clear, briny broth. | 바지락에 무와 마늘을 넣어 맑고 시원하게 끓인 탕. | 2, 4 |
| honghap-tang<br>홍합탕 | Mussels simmered with garlic, green onion and chili in a clear broth. | 홍합을 마늘, 대파, 고추와 함께 맑게 끓인 탕. | 4 |
| godeungeo-gui<br>고등어소금구이 | Salted mackerel pan-fried until the skin crisps, with lemon on the side. | 소금 간한 고등어를 껍질이 바삭하게 구워 레몬을 곁들인 생선구이. | 5 |
| kkongchi-kimchi-jorim<br>꽁치김치조림 | Canned saury and ripe kimchi braised together in a spicy broth. | 꽁치 통조림과 잘 익은 김치를 매콤하게 조린 요리. |  |
| kodari-jorim<br>코다리조림 | Half-dried pollock and radish braised in a spicy soy sauce. | 꾸덕한 코다리와 무를 매콤한 간장 양념에 조린 요리. | 5 |
| broccoli-garlic-stir-fry<br>브로콜리 마늘볶음 | Broccoli tossed with golden garlic and oyster sauce over high heat. | 데친 브로콜리를 노릇한 마늘, 굴소스와 함께 센 불에 볶은 요리. |  |
| meat-sauce-pasta<br>미트소스 파스타 | Pasta tossed in a thick beef and tomato sauce, finished with parmesan. | 다진 소고기와 토마토소스에 파스타를 버무리고 파마산을 올린 요리. | 4 |
| pesto-pasta<br>페스토 파스타 | Pasta tossed with basil pesto off the heat to keep its fresh green color. | 바질 페스토를 불에서 내려 버무려 초록빛을 살린 파스타. | 2 |
| asparagus-bacon-mari<br>아스파라거스 베이컨말이 | Asparagus wrapped in bacon and pan-fried until crisp. | 아스파라거스를 베이컨으로 감아 바삭하게 구운 요리. |  |
| cauliflower-gui<br>콜리플라워 오븐구이 | Cauliflower roasted until the edges brown, then sprinkled with parmesan. | 콜리플라워를 가장자리가 노릇하게 구워 파마산을 뿌린 요리. | 1 |
| chicken-tomato-stew<br>치킨 토마토스튜 | Chicken and mushrooms gently simmered with canned tomatoes. | 닭고기와 버섯을 토마토 통조림에 넣고 뭉근하게 끓인 스튜. | 5 |
| strawberry-yogurt-bowl<br>딸기 요거트볼 | Yogurt topped with fresh strawberries, honey and crunchy granola. | 요거트에 생딸기와 꿀을 얹고 먹기 직전 그래놀라를 더한 한 그릇. |  |
| apple-walnut-salad<br>사과 호두 샐러드 | Apple and toasted walnuts over lettuce with a honey yogurt dressing. | 상추에 사과와 구운 호두를 올리고 꿀 요거트 드레싱을 곁들인 샐러드. | 3 |
| banana-pancake<br>바나나 팬케이크 | Pancakes with mashed banana in the batter and sliced banana on top. | 으깬 바나나를 반죽에 섞어 부치고 바나나 조각을 올린 팬케이크. |  |
| pb-banana-toast<br>땅콩버터 바나나토스트 | Warm toast spread with peanut butter and topped with banana and honey. | 따뜻한 토스트에 땅콩버터를 바르고 바나나와 꿀을 올린 요리. |  |
| kong-guksu<br>콩국수 | Cold noodles in plain soy milk, topped with cucumber and sesame seeds. | 차가운 무가당 두유에 국수를 말고 오이와 통깨를 올린 간단 콩국수. | 2 |
| fruit-salad<br>과일 샐러드 | Apple, banana and orange gently tossed with yogurt and honey. | 사과, 바나나, 오렌지를 요거트와 꿀에 가볍게 버무린 샐러드. |  |
| neutari-bokkeum<br>느타리버섯볶음 | Hand-torn oyster mushrooms stir-fried with carrot and finished with sesame oil. | 느타리버섯을 손으로 찢어 당근과 볶고 참기름으로 마무리한 반찬. |  |
| ueong-jorim<br>우엉조림 | Thin strips of burdock root braised in sweet soy sauce until glossy. | 가늘게 썬 우엉을 달콤한 간장 양념에 윤기 나게 조린 밑반찬. | 1 |
| gosari-namul<br>고사리나물 | Cooked fernbrake stir-fried with garlic and finished with sesame oil. | 삶은 고사리를 마늘과 볶고 참기름으로 마무리한 나물. | 1 |
| maneuljjong-bokkeum<br>마늘종 새우볶음 | Garlic scapes and shrimp stir-fried in a sweet soy glaze. | 마늘종과 새우를 달콤한 간장 양념에 볶은 밑반찬. |  |
| gul-jeon<br>굴전 | Oysters coated in flour and egg, pan-fried and served with a soy dipping sauce. | 굴에 밀가루와 계란옷을 입혀 부치고 초간장을 곁들인 전. | 4 |
| galchi-jorim<br>갈치조림 | Hairtail and radish braised in a spicy soy broth. | 갈치와 무를 칼칼한 고춧가루 간장 양념에 조린 생선 요리. | 5 |
| kkotge-tang<br>꽃게탕 | Crab, radish and zucchini simmered in a spicy soybean paste broth. | 꽃게, 무, 애호박을 된장 국물에 얼큰하게 끓인 탕. | 5 |
| gwanja-butter-gui<br>관자 버터구이 | Scallops seared until golden and basted with garlic butter. | 관자를 노릇하게 구워 마늘 버터를 끼얹은 요리. | 4 |

영어 이름은 열무국수의 재료에 없는 '김치'와 연어 필렛에 붙은 '스테이크 컷' 오해를 바로잡았습니다. 볶음밥의 밥은 단순히 오래된 밥이 아니라 조리 후 식혀 냉장 보관한 밥으로, 고사리는 충분히 삶은 것으로, 카르보나라는 살균 처리한 달걀로 명시했습니다.

## 검증과 남은 한계

- 문구 수정본의 기존 Swift Testing 562개와 핵심 UI 테스트 4개가 통과했습니다. 별도 XCTest 19개도 통과했습니다. UI 검증 경로는 온보딩 완료, 한국어 라이브 전환, 영상 CTA 유지, 조리 단계 체크 후 시트 왕복입니다. 결과: `/tmp/reffi-copy-final-20260905.xcresult`.
- 검사 당시 카탈로그 384개 키 / 소스 리터럴 339개 / 등록 누락 0개였고, 한영 포맷 인자도 전수 일치했습니다. `body:` 추출 회귀 검사와 `git diff --check`도 통과했습니다.
- 마무리 중 별도 Analytics 작업의 소스 변경과 새 카탈로그 키 2개가 같은 폴더에 들어왔습니다. 해당 기능 변경은 이 검토의 산출물이 아니며 보존했습니다. 현재 문자열 검사는 386개 키 / 341개 리터럴 / 누락 0개입니다.
- 추가한 단계 언어 정합성 테스트를 실행하는 중 새 `Analytics.swift`가 생성 프로젝트에 아직 포함되지 않아 한 차례 빌드가 실패했습니다. 앱 소스를 수정하지 않고 `xcodegen generate`로 프로젝트를 재생성한 뒤 통합 상태에서 Swift Testing 563개와 XCTest 19개, 총 582개 유닛 테스트가 통과했습니다. 결과: `/tmp/reffi-copy-integrated-unit-20260905.xcresult`. 별도 Analytics 소스의 sendable 캡처 경고 1건은 이 작업에서 수정하지 않았습니다.
- iPhone 17 시뮬레이터에서 한국어 온보딩 3장과 영어 영수증 시작 시트를 캡처해 제목·본문·버튼의 줄바꿈과 잘림을 확인했습니다. 두 화면에서 잘림은 없었습니다. 스크린샷: `/tmp/reffi-copy-onboarding-ko.png`, `/tmp/reffi-copy-receipt-en.png`. 모든 화면·글자 크기의 시각 검증을 뜻하지는 않습니다.

- 이 작업은 문구·데이터 검토이지 128개 메뉴의 실제 조리 시험이 아닙니다. 맛, 조리 시간, 식재료 두께별 익힘을 실측하지 않았습니다.
- 시드에는 분량·인분이 없습니다. 영상을 1차 조리 경로로 삼는 현재 설계는 유지했으며, 분량을 임의로 만들지 않았습니다. 완결된 독립 레시피로 제공하려면 별도 분량 데이터와 조리 검증이 필요합니다.
- 내부 cuisine 분류에서 `nasi-goreng → thai`, `schnitzel-style-cutlet → french`가 남아 있습니다. 소개의 국가 단정은 없앴지만, 취향 선택과 추천에 연결되는 분류 체계는 이번 문구 수정에서 바꾸지 않았습니다. 실제 지역 분류와 현재 취향 옵션을 맞추는 후속 결정이 필요합니다.
- 이미 시작한 조리 세션은 시작 시점의 단계 문구를 저장하므로 이전 문구가 남을 수 있습니다. 새로 시작하는 세션에는 수정된 시드가 사용됩니다.
- 번역 누락·단계 수·길이 검사가 통과해도 사실성·조리 안전성이 자동으로 증명되지는 않습니다.
