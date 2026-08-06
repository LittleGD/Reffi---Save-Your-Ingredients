import SwiftUI

// MARK: - 원형(archetype)

/// 요리 아이콘의 **원형** — 80개 레시피를 하나씩 그리지 않기 위한 축(§13.7).
/// 재료 글리프가 "시금치"가 아니라 `leaf` 원형이듯, 요리도 **담기는 그릇 + 덩어리 형태**로 묶는다.
/// 60pt 섬네일에서 먼저 읽히는 건 색이 아니라 **실루엣**이라, 원형끼리는 전부 외곽이 다르다
/// (깊은 냄비 / 얕은 대접 / 납작한 접시 / 사각 오븐 그릇 / 반달 / 원판 / 층).
enum DishArchetype: String, CaseIterable {
    case stewPot        // 찌개·탕·조림 — 귀 둘 달린 깊은 냄비 + 국물면 + 김
    case soupBowl       // 국·수프·죽 — 넓고 얕은 대접 + 국물면 + 뜬 고명
    case riceBowl       // 덮밥 — 공기에 봉긋한 밥 + 위를 덮은 토핑
    case noodleBowl     // 면요리 — 깊은 면기 + 면 봉우리 + 젓가락 리프트
    case pastaPlate     // 파스타 — 넓은 접시 + 돌돌 감긴 면 네스트
    case skillet        // 볶음 — 손잡이 달린 팬 + 내용물 원반
    case platedMound    // 볶음밥·리조또·매쉬 — 접시 위 알갱이 산
    case grillPlate     // 구이·스테이크·커틀릿 — 접시 + 구운 덩어리 + 사이드
    case discStack      // 전·팬케이크·크레페·프리타타 — 원판(1~3장)
    case rollSlices     // 김밥·계란말이 — 원형 단면 조각 셋
    case sandwichStack  // 샌드위치·토스트 — 층진 단면
    case foldedWrap     // 타코·퀘사디아·파히타 — 반달 또띠아
    case curryPlate     // 커리 — 접시 두 존(밥 + 소스)
    case sideBowl       // 샐러드·나물·딥 — 낮고 넓은 볼
    case bakeDish       // 그라탕·라자냐·베이크 — 사각 오븐 그릇

    /// 갤러리·시트 라벨용 한글 이름.
    var koreanLabel: String {
        switch self {
        case .stewPot:       "냄비(찌개·탕)"
        case .soupBowl:      "대접(국·수프)"
        case .riceBowl:      "덮밥 공기"
        case .noodleBowl:    "면기"
        case .pastaPlate:    "파스타 접시"
        case .skillet:       "볶음 팬"
        case .platedMound:   "밥 산 접시"
        case .grillPlate:    "구이 접시"
        case .discStack:     "원판(전·팬케이크)"
        case .rollSlices:    "롤 단면"
        case .sandwichStack: "샌드위치 층"
        case .foldedWrap:    "반달 또띠아"
        case .curryPlate:    "커리 두 존"
        case .sideBowl:      "낮은 볼(샐러드·딥)"
        case .bakeDish:      "오븐 그릇"
        }
    }
}

/// 그릇 재질 톤 — 원형과 독립된 변주 축. 같은 `soupBowl`이라도 미소시루(옻칠 나무)와
/// 프렌치 어니언 수프(오븐 유약 그릇)가 다른 요리로 읽히게 한다.
enum DishVessel: String {
    case clay        // 뚝배기(붉은 토기)
    case porcelain   // 백자
    case indigo      // 도기 블루
    case wood        // 옻칠·나무
    case iron        // 무쇠 팬
    case glaze       // 오븐 그릇(크림 유약)
}

/// 고명 마크의 **모양** — 같은 원형·같은 국물색이라도 위에 뭐가 떠 있는지로 요리가 갈린다
/// (김치찌개=두부 큐브, 순두부찌개=노른자, 떡볶이=떡 스틱, 마파두부=두부 큐브).
enum DishMarkShape: Hashable {
    case cube    // 두부·감자·야채 큐브
    case ring    // 대파·쪽파 링(가운데가 비었다)
    case baton   // 떡·어묵·콩나물 스틱
    case disc    // 당근·레몬·버섯 얇은 원판
    case dot     // 깨·알갱이·씨앗
    case leafy   // 잎 조각(고수·바질·미역·상추)
    case yolk    // 노른자·수란
    case strip   // 고기·닭·새우 조각(각진 스트립)
    case wedge   // 나초·플랫브레드 삼각 조각
}

struct DishMark: Hashable {
    var shape: DishMarkShape
    var color: Color
}

/// 원형 하나를 특정 요리로 만드는 **변주값**.
/// 축은 셋: ① `fill`(주 내용물 — 국물·소스·면·반죽) ② `accent`(원형마다 해석이 다른 보조 면)
/// ③ `mark`/`mark2`(고명 두 종). `vessel`·`layers`는 형태를 미세 조정하는 보조 축이다.
/// `Hashable` — 테스트가 "완전히 같은 변주 둘"(옆에 놓으면 같은 요리로 읽힌다)을 집합으로 잡아낸다.
struct DishLook: Hashable {
    var archetype: DishArchetype
    /// 주 내용물 색 — 원형이 가장 크게 칠하는 면(국물·소스·면·밥·반죽·구운 덩어리).
    var fill: Color
    /// 보조 면 — **원형마다 뜻이 다르다**:
    /// 면기=국물(nil이면 국물 없는 볶음면), 덮밥=토핑, 커리=밥, 구이=사이드, 샌드위치·랩=속,
    /// 롤=속(밥), 원판=시럽·소스, 낮은 볼=곁들이 삼각 조각(nil이면 잎 더미), 오븐 그릇=아래 층.
    var accent: Color?
    var vessel: DishVessel = .porcelain
    var mark: DishMark?
    var mark2: DishMark?
    /// 층·장 수 — `discStack`(원판 장수), `rollSlices`(단면 조각 수), `sandwichStack`(속 층 수)만 쓴다.
    var layers: Int = 1
}

// MARK: - 팔레트

/// 요리 팔레트 — 재료 글리프(`PaperSilhouette.C`)와 같은 규칙: **OKLCH 정본, hex 금지, 고정색**.
/// 적응형 토큰을 쓰면 다크에서 실루엣이 뒤집힌다(잘라 붙인 종이는 조명이 바뀌어도 색이 안 바뀐다).
enum DishPalette {
    // 그릇
    // 뚝배기 — 실물은 더 어둡지만, 국물색이 살아야 찌개가 갈린다. L을 더 내리면 냄비가
    // 검은 상자가 되고 그 안의 붉은 국물·된장색이 전부 같은 어둠으로 뭉개진다.
    static let clayBase   = ReffiColor.oklch(0.50, 0.038, 44)
    static let clayDark   = ReffiColor.oklch(0.40, 0.034, 42)
    static let clayLight  = ReffiColor.oklch(0.60, 0.040, 48)
    // 백자 — 그림자 톤(`porcDark`)에 **따뜻한 기(C 0.02 · H 82)를 남긴다**. 무채색으로 내리면
    // 접시 테두리가 차가운 회색 링이 되어 크림 배경 위에서 때처럼 보인다.
    static let porcBase   = ReffiColor.oklch(0.93, 0.010, 88)
    static let porcDark   = ReffiColor.oklch(0.855, 0.020, 82)
    static let porcLight  = ReffiColor.oklch(0.975, 0.006, 90)
    static let indigoBase = ReffiColor.oklch(0.70, 0.062, 246)
    static let indigoDark = ReffiColor.oklch(0.59, 0.065, 244)
    static let indigoLight = ReffiColor.oklch(0.80, 0.048, 248)
    static let woodBase   = ReffiColor.oklch(0.55, 0.055, 48)
    static let woodDark   = ReffiColor.oklch(0.44, 0.050, 46)
    static let woodLight  = ReffiColor.oklch(0.66, 0.050, 54)
    static let ironBase   = ReffiColor.oklch(0.44, 0.010, 250)
    static let ironDark   = ReffiColor.oklch(0.34, 0.010, 250)
    static let ironLight  = ReffiColor.oklch(0.55, 0.008, 250)
    static let glazeBase  = ReffiColor.oklch(0.88, 0.035, 84)
    static let glazeDark  = ReffiColor.oklch(0.76, 0.045, 78)
    static let glazeLight = ReffiColor.oklch(0.95, 0.022, 88)
    /// 김(수증기) — 배경 크림 위에서도 보이도록 흰빛에 살짝 파란 기.
    static let steam      = ReffiColor.oklch(0.965, 0.006, 250, 0.72)
    /// 파 링·마늘 링의 속(빈 가운데) — 고명이 도넛처럼 읽히게.
    static let markHole   = ReffiColor.oklch(0.955, 0.012, 96)

    // 국물·탕
    static let kimchiBroth = ReffiColor.oklch(0.545, 0.175, 32)
    static let sundubu     = ReffiColor.oklch(0.615, 0.170, 38)
    static let doenjang    = ReffiColor.oklch(0.635, 0.075, 88)
    static let miso        = ReffiColor.oklch(0.575, 0.100, 62)
    static let clearBroth  = ReffiColor.oklch(0.885, 0.045, 96)
    // 미역국 국물은 **맑은 소고기 육수**다. 미역 색(L 0.33)에 맞춰 국물까지 어둡게 하면
    // 미역 고명이 국물에 파묻혀 사라진다 — 고명과 바탕은 항상 L을 벌려 둔다.
    static let seaweedBroth = ReffiColor.oklch(0.640, 0.040, 68)
    static let soyBraise   = ReffiColor.oklch(0.395, 0.058, 56)
    static let porridge    = ReffiColor.oklch(0.930, 0.016, 92)
    static let custard     = ReffiColor.oklch(0.875, 0.085, 96)
    static let creamSoup   = ReffiColor.oklch(0.895, 0.032, 84)
    static let tomatoSoup  = ReffiColor.oklch(0.600, 0.160, 34)
    static let onionSoup   = ReffiColor.oklch(0.470, 0.070, 62)
    static let vegSoup     = ReffiColor.oklch(0.685, 0.120, 52)
    static let phoBroth    = ReffiColor.oklch(0.780, 0.065, 76)

    // 소스·볶음
    static let gochujang   = ReffiColor.oklch(0.530, 0.190, 30)
    static let mapo        = ReffiColor.oklch(0.505, 0.165, 36)
    static let bulgogi     = ReffiColor.oklch(0.480, 0.080, 52)
    static let soySweet    = ReffiColor.oklch(0.575, 0.110, 54)
    static let sweetSour   = ReffiColor.oklch(0.660, 0.140, 62)
    static let bokchoy     = ReffiColor.oklch(0.575, 0.130, 146)
    static let shakshuka   = ReffiColor.oklch(0.565, 0.165, 34)
    static let butterGold  = ReffiColor.oklch(0.845, 0.110, 88)
    static let tomatoStir  = ReffiColor.oklch(0.625, 0.175, 32)

    // 밥·알갱이
    static let riceWhite   = ReffiColor.oklch(0.965, 0.007, 96)
    static let friedRed    = ReffiColor.oklch(0.680, 0.130, 42)
    static let friedYellow = ReffiColor.oklch(0.880, 0.085, 92)
    static let nasiBrown   = ReffiColor.oklch(0.605, 0.080, 62)
    static let risotto     = ReffiColor.oklch(0.865, 0.050, 88)
    static let mashCream   = ReffiColor.oklch(0.925, 0.032, 92)

    // 면
    static let wheatNoodle = ReffiColor.oklch(0.860, 0.100, 86)
    static let riceNoodle  = ReffiColor.oklch(0.945, 0.014, 94)
    static let glassNoodle = ReffiColor.oklch(0.560, 0.055, 66)
    static let yakisoba    = ReffiColor.oklch(0.615, 0.095, 58)
    static let padThai     = ReffiColor.oklch(0.740, 0.125, 56)
    static let chowMein    = ReffiColor.oklch(0.680, 0.085, 68)
    static let pastaRed    = ReffiColor.oklch(0.585, 0.170, 34)
    static let pastaCream  = ReffiColor.oklch(0.890, 0.055, 92)
    static let pastaOil    = ReffiColor.oklch(0.855, 0.090, 92)

    // 커리
    static let curryBrown  = ReffiColor.oklch(0.505, 0.100, 62)
    static let greenCurry  = ReffiColor.oklch(0.665, 0.120, 148)
    static let butterCurry = ReffiColor.oklch(0.625, 0.150, 48)
    static let chickpeaCurry = ReffiColor.oklch(0.680, 0.130, 74)

    // 구이·고기
    static let steakBrown  = ReffiColor.oklch(0.435, 0.090, 42)
    static let searDark    = ReffiColor.oklch(0.320, 0.055, 40)
    static let porkBelly   = ReffiColor.oklch(0.720, 0.100, 30)
    static let porkFat     = ReffiColor.oklch(0.925, 0.022, 60)
    static let salmonPink  = ReffiColor.oklch(0.700, 0.150, 44)
    static let tandoori    = ReffiColor.oklch(0.545, 0.170, 36)
    static let cutletGold  = ReffiColor.oklch(0.725, 0.110, 72)
    static let pattyBrown  = ReffiColor.oklch(0.415, 0.080, 46)
    static let beefRare    = ReffiColor.oklch(0.585, 0.130, 26)
    static let beefBrown   = ReffiColor.oklch(0.460, 0.100, 34)
    static let baconRed    = ReffiColor.oklch(0.585, 0.150, 22)
    static let chickenTan  = ReffiColor.oklch(0.760, 0.075, 66)
    static let friedGold   = ReffiColor.oklch(0.735, 0.115, 70)
    static let shrimpPink  = ReffiColor.oklch(0.725, 0.150, 38)

    // 반죽·빵·원판
    static let jeonRed     = ReffiColor.oklch(0.700, 0.125, 50)
    static let pancakeGold = ReffiColor.oklch(0.800, 0.100, 78)
    static let crepePale   = ReffiColor.oklch(0.885, 0.055, 86)
    static let omelette    = ReffiColor.oklch(0.845, 0.150, 92)
    static let frittata    = ReffiColor.oklch(0.825, 0.140, 90)
    static let toastGold   = ReffiColor.oklch(0.790, 0.080, 76)
    static let toastCream  = ReffiColor.oklch(0.855, 0.055, 82)
    static let baguette    = ReffiColor.oklch(0.775, 0.075, 72)
    static let frenchToast = ReffiColor.oklch(0.760, 0.100, 74)
    static let tortillaFlour = ReffiColor.oklch(0.880, 0.045, 86)
    static let tortillaCorn = ReffiColor.oklch(0.815, 0.105, 84)
    static let syrup       = ReffiColor.oklch(0.520, 0.090, 58)

    // 오븐
    static let lasagnaRed  = ReffiColor.oklch(0.560, 0.160, 32)
    // 오븐 그릇(`glaze`, L 0.88 크림) 위에 얹히는 색이라 L을 더 내려야 내용물이 그릇과 갈린다.
    static let gratinCream = ReffiColor.oklch(0.825, 0.095, 84)
    static let macCheese   = ReffiColor.oklch(0.780, 0.155, 86)
    static let ratatouille = ReffiColor.oklch(0.595, 0.140, 40)

    // 샐러드·딥
    static let saladGreen  = ReffiColor.oklch(0.680, 0.135, 140)
    static let spinach     = ReffiColor.oklch(0.470, 0.100, 148)
    static let cucumberMix = ReffiColor.oklch(0.615, 0.150, 36)
    static let caprese     = ReffiColor.oklch(0.940, 0.014, 92)
    static let hummus      = ReffiColor.oklch(0.825, 0.060, 84)
    static let salsa       = ReffiColor.oklch(0.570, 0.170, 30)
    static let nicoise     = ReffiColor.oklch(0.640, 0.120, 142)
    static let nachoGold   = ReffiColor.oklch(0.815, 0.115, 82)
    static let flatbread   = ReffiColor.oklch(0.855, 0.055, 82)

    // 고명 전용
    static let tofuWhite   = ReffiColor.oklch(0.955, 0.014, 96)
    static let scallion    = ReffiColor.oklch(0.630, 0.145, 145)
    static let chive       = ReffiColor.oklch(0.585, 0.130, 148)
    static let carrot      = ReffiColor.oklch(0.700, 0.160, 56)
    static let eggYolk     = ReffiColor.oklch(0.805, 0.160, 82)
    static let eggWhite    = ReffiColor.oklch(0.960, 0.010, 96)
    static let seaweedDark = ReffiColor.oklch(0.330, 0.055, 156)
    static let chiliRed    = ReffiColor.oklch(0.550, 0.190, 32)
    static let cheeseGold  = ReffiColor.oklch(0.830, 0.130, 92)
    static let mozzarella  = ReffiColor.oklch(0.955, 0.010, 96)
    static let mushroomTan = ReffiColor.oklch(0.700, 0.045, 66)
    static let lemonYellow = ReffiColor.oklch(0.870, 0.140, 98)
    static let limeGreen   = ReffiColor.oklch(0.800, 0.130, 130)
    static let lettuce     = ReffiColor.oklch(0.740, 0.140, 138)
    static let basil       = ReffiColor.oklch(0.545, 0.125, 146)
    static let cilantro    = ReffiColor.oklch(0.660, 0.135, 142)
    static let parsley     = ReffiColor.oklch(0.575, 0.130, 144)
    static let rosemary    = ReffiColor.oklch(0.500, 0.075, 152)
    static let tomatoRed   = ReffiColor.oklch(0.620, 0.180, 32)
    static let sesame      = ReffiColor.oklch(0.915, 0.025, 90)
    static let potatoGold  = ReffiColor.oklch(0.840, 0.080, 88)
    static let onionCream  = ReffiColor.oklch(0.905, 0.020, 76)
    static let garlicCream = ReffiColor.oklch(0.930, 0.018, 88)
    static let riceCake    = ReffiColor.oklch(0.950, 0.012, 94)
    static let fishCake    = ReffiColor.oklch(0.880, 0.035, 78)
    static let sprout      = ReffiColor.oklch(0.905, 0.055, 100)
    static let zucchini    = ReffiColor.oklch(0.700, 0.110, 138)
    static let eggplant    = ReffiColor.oklch(0.400, 0.090, 318)
    static let beanBrown   = ReffiColor.oklch(0.480, 0.075, 48)
    static let chickpea    = ReffiColor.oklch(0.845, 0.060, 88)
    static let pepperGreen = ReffiColor.oklch(0.610, 0.130, 142)
    static let pepperRed   = ReffiColor.oklch(0.600, 0.175, 34)
    static let cabbagePale = ReffiColor.oklch(0.895, 0.050, 130)
    static let asparagus   = ReffiColor.oklch(0.635, 0.120, 140)
    static let berryRed    = ReffiColor.oklch(0.560, 0.170, 20)
    static let oliveInk    = ReffiColor.oklch(0.360, 0.045, 110)
    static let pepperInk   = ReffiColor.oklch(0.340, 0.020, 80)
    static let crumbGold   = ReffiColor.oklch(0.780, 0.080, 76)
    static let mitsuba     = ReffiColor.oklch(0.600, 0.120, 145)
    static let butterCube  = ReffiColor.oklch(0.880, 0.105, 96)
}

// MARK: - 매핑

/// 레시피 → 요리 아이콘 변주 매핑. **레시피 JSON은 스키마를 바꾸지 않는다**(프로젝트 규칙:
/// 데이터는 번들에서 오고, 표현은 코드가 정한다) — 그래서 매핑은 여기 코드 테이블에 산다.
///
/// 시드 80개는 `table`이 id로 직접 지정하고, 그 밖(사용자 커스텀·AI 생성·미래 시드)은
/// `fallback`이 **이름 키워드 → 원형**, **cuisine → 색조**로 추론한다. 빈 아이콘은 나오지 않는다.
enum DishGlyphCatalog {

    static func look(for recipe: Recipe) -> DishLook {
        look(id: recipe.id, name: recipe.name.en, koreanName: recipe.name.ko, cuisine: recipe.cuisine)
    }

    /// 순수 함수 진입점 — 테스트가 임의 이름·cuisine으로 폴백을 직접 고정한다.
    static func look(id: String, name: String, koreanName: String? = nil,
                     cuisine: String?) -> DishLook {
        if let hit = table[id] { return hit }
        return fallback(name: name, koreanName: koreanName, cuisine: cuisine, id: id)
    }

    // MARK: 확신도별 진입점 (히어로 아이콘 폴백 체인 — `Recipe.heroIcon`)

    /// 시드 매핑 표 적중만 — 손으로 배정한 80종의 **정본** 변주. 표 밖(커스텀·AI)이면 nil.
    /// 추론까지 포함한 `look(for:)`과 달리 "이 요리를 우리가 그려 뒀는가"에만 답한다 —
    /// 그려 둔 요리 그림이 따로 있는 이름(김밥)을 짐작으로 덮지 않으려면 이 구분이 필요하다.
    static func curatedLook(id: String) -> DishLook? { table[id] }

    /// 이름이 요리를 **지목할 때만** 나오는 추론 결과 — cuisine 기본값만으로 만든 짐작은 nil로 돌려보낸다
    /// ("한식이니 찌개"는 이름이 침묵할 때의 추측이라, 없는 요리를 단정하느니 호출부가 재료로 내려가는 편이 낫다).
    /// 값이 나올 땐 `look(for:)`와 **같은 결과**다 — 같은 레시피가 표면마다 다른 그림이 되지 않게.
    static func nameMatchedLook(for recipe: Recipe) -> DishLook? {
        guard keywordArchetype(name: recipe.name.en, koreanName: recipe.name.ko) != nil else { return nil }
        return look(for: recipe)
    }

    // MARK: 시드 80개

    /// `L`/`M`은 표를 한 줄에 담기 위한 축약 생성자 — 80줄이 눈으로 비교되게(변주 축이 열로 정렬).
    private static func L(_ a: DishArchetype, _ fill: Color, _ accent: Color? = nil,
                          _ vessel: DishVessel = .porcelain,
                          _ m1: DishMark? = nil, _ m2: DishMark? = nil,
                          layers: Int = 1) -> DishLook {
        DishLook(archetype: a, fill: fill, accent: accent, vessel: vessel,
                 mark: m1, mark2: m2, layers: layers)
    }
    private static func M(_ s: DishMarkShape, _ c: Color) -> DishMark { DishMark(shape: s, color: c) }

    static let table: [String: DishLook] = {
        let P = DishPalette.self
        return [
            // 한식 — 찌개·탕·조림은 뚝배기(clay), 국은 백자 대접
            "kimchi-jjigae":     L(.stewPot, P.kimchiBroth, nil, .clay, M(.cube, P.tofuWhite), M(.ring, P.scallion)),
            "doenjang-jjigae":   L(.stewPot, P.doenjang, nil, .clay, M(.cube, P.tofuWhite), M(.disc, P.zucchini)),
            "sundubu-jjigae":    L(.stewPot, P.sundubu, nil, .clay, M(.yolk, P.eggYolk), M(.ring, P.scallion)),
            "galbi-jjim":        L(.stewPot, P.soyBraise, nil, .clay, M(.strip, P.beefBrown), M(.disc, P.carrot)),
            "dak-bokkeum-tang":  L(.stewPot, P.gochujang, nil, .clay, M(.cube, P.potatoGold), M(.strip, P.chickenTan)),
            "gamja-jorim":       L(.stewPot, P.soyBraise, nil, .clay, M(.cube, P.potatoGold), M(.dot, P.sesame)),
            "kongnamul-guk":     L(.soupBowl, P.clearBroth, nil, .porcelain, M(.baton, P.sprout), M(.ring, P.scallion)),
            "miyeok-guk":        L(.soupBowl, P.seaweedBroth, nil, .porcelain, M(.leafy, P.seaweedDark), M(.strip, P.beefBrown)),
            // 죽은 바탕이 거의 흰색이라 깨(크림)는 안 보인다 — 닭살 조각·파로 대비를 만든다.
            "dak-juk":           L(.soupBowl, P.porridge, nil, .porcelain, M(.strip, P.chickenTan), M(.ring, P.scallion)),
            "beef-bulgogi":      L(.skillet, P.bulgogi, nil, .iron, M(.strip, P.beefBrown), M(.ring, P.scallion)),
            "jeyuk-bokkeum":     L(.skillet, P.gochujang, nil, .iron, M(.strip, P.porkBelly), M(.ring, P.scallion)),
            "tteokbokki":        L(.skillet, P.gochujang, nil, .iron, M(.baton, P.riceCake), M(.ring, P.scallion)),
            "eomuk-bokkeum":     L(.skillet, P.soySweet, nil, .iron, M(.baton, P.fishCake), M(.strip, P.pepperGreen)),
            "gyeran-mari":       L(.rollSlices, P.omelette, P.eggYolk, .porcelain, M(.ring, P.scallion), M(.dot, P.carrot), layers: 3),
            "gimbap":            L(.rollSlices, P.seaweedDark, P.riceWhite, .porcelain, M(.strip, P.carrot), M(.strip, P.eggYolk), layers: 3),
            "japchae":           L(.noodleBowl, P.glassNoodle, nil, .porcelain, M(.strip, P.carrot), M(.leafy, P.spinach)),
            "bibimbap":          L(.riceBowl, P.riceWhite, P.saladGreen, .wood, M(.strip, P.carrot), M(.yolk, P.eggYolk)),
            "kimchi-fried-rice": L(.platedMound, P.friedRed, nil, .porcelain, M(.dot, P.chiliRed), M(.ring, P.scallion)),
            "kimchi-jeon":       L(.discStack, P.jeonRed, nil, .porcelain, M(.dot, P.chiliRed), M(.ring, P.scallion), layers: 2),
            "oi-muchim":         L(.sideBowl, P.cucumberMix, nil, .porcelain, M(.disc, P.zucchini), M(.dot, P.sesame)),
            "sigeumchi-namul":   L(.sideBowl, P.spinach, nil, .porcelain, M(.dot, P.sesame), nil),
            "samgyeopsal-gui":   L(.grillPlate, P.porkBelly, P.lettuce, .porcelain, M(.strip, P.porkFat), M(.disc, P.garlicCream)),

            // 일식
            "gyudon":            L(.riceBowl, P.riceWhite, P.bulgogi, .indigo, M(.ring, P.scallion), M(.strip, P.onionCream)),
            "oyakodon":          L(.riceBowl, P.riceWhite, P.custard, .indigo, M(.strip, P.chickenTan), M(.ring, P.scallion)),
            "miso-soup":         L(.soupBowl, P.miso, nil, .wood, M(.cube, P.tofuWhite), M(.ring, P.scallion)),
            "yakisoba":          L(.noodleBowl, P.yakisoba, nil, .porcelain, M(.strip, P.cabbagePale), M(.disc, P.carrot)),
            "japanese-curry-rice": L(.curryPlate, P.curryBrown, P.riceWhite, .porcelain, M(.cube, P.potatoGold), M(.disc, P.carrot)),
            "chawanmushi":       L(.soupBowl, P.custard, nil, .indigo, M(.disc, P.mushroomTan), M(.leafy, P.mitsuba)),
            "grilled-salmon-teishoku": L(.grillPlate, P.salmonPink, P.riceWhite, .porcelain, M(.disc, P.lemonYellow), M(.leafy, P.lettuce)),

            // 중식
            "egg-fried-rice":    L(.platedMound, P.friedYellow, nil, .porcelain, M(.dot, P.eggYolk), M(.ring, P.scallion)),
            "mapo-tofu":         L(.skillet, P.mapo, nil, .iron, M(.cube, P.tofuWhite), M(.ring, P.scallion)),
            "bok-choy-stir-fry": L(.skillet, P.bokchoy, nil, .iron, M(.leafy, P.cabbagePale), M(.disc, P.garlicCream)),
            "kkanpung-chicken":  L(.skillet, P.sweetSour, nil, .iron, M(.strip, P.friedGold), M(.disc, P.chiliRed)),
            "tomato-egg-stir-fry": L(.skillet, P.tomatoStir, nil, .iron, M(.strip, P.eggYolk), M(.ring, P.scallion)),
            "chicken-chow-mein": L(.noodleBowl, P.chowMein, nil, .porcelain, M(.strip, P.chickenTan), M(.leafy, P.cabbagePale)),

            // 동남아
            "pad-thai":          L(.noodleBowl, P.padThai, nil, .porcelain, M(.strip, P.shrimpPink), M(.disc, P.limeGreen)),
            "thai-green-curry":  L(.curryPlate, P.greenCurry, P.riceWhite, .porcelain, M(.strip, P.chickenTan), M(.leafy, P.basil)),
            "banh-mi-sandwich":  L(.sandwichStack, P.baguette, P.porkBelly, .porcelain, M(.strip, P.carrot), M(.leafy, P.cilantro)),
            "nasi-goreng":       L(.platedMound, P.nasiBrown, nil, .porcelain, M(.yolk, P.eggYolk), M(.disc, P.chiliRed)),
            "quick-beef-pho":    L(.noodleBowl, P.riceNoodle, P.phoBroth, .porcelain, M(.strip, P.beefRare), M(.leafy, P.cilantro)),

            // 이탈리안
            "tomato-pasta":      L(.pastaPlate, P.pastaRed, nil, .porcelain, M(.leafy, P.basil), nil),
            "carbonara-style-pasta": L(.pastaPlate, P.pastaCream, nil, .porcelain, M(.strip, P.baconRed), M(.dot, P.pepperInk)),
            "aglio-e-olio":      L(.pastaPlate, P.pastaOil, nil, .porcelain, M(.disc, P.garlicCream), M(.dot, P.chiliRed)),
            "margherita-toast":  L(.sandwichStack, P.toastGold, P.tomatoRed, .porcelain, M(.disc, P.mozzarella), M(.leafy, P.basil)),
            "minestrone":        L(.soupBowl, P.tomatoSoup, nil, .porcelain, M(.cube, P.zucchini), M(.baton, P.pastaCream)),
            "mushroom-risotto":  L(.platedMound, P.risotto, nil, .porcelain, M(.disc, P.mushroomTan), M(.leafy, P.parsley)),
            "caprese-salad":     L(.sideBowl, P.caprese, nil, .porcelain, M(.disc, P.tomatoRed), M(.leafy, P.basil)),
            "lasagna-style-bake": L(.bakeDish, P.lasagnaRed, P.pastaCream, .glaze, M(.leafy, P.basil), nil),
            "vegetable-frittata": L(.discStack, P.frittata, nil, .porcelain, M(.disc, P.tomatoRed), M(.leafy, P.spinach), layers: 1),

            // 아메리칸
            "scrambled-eggs":    L(.skillet, P.omelette, nil, .iron, M(.cube, P.eggWhite), M(.ring, P.chive)),
            "cheese-omelette":   L(.discStack, P.omelette, P.cheeseGold, .porcelain, M(.leafy, P.chive), nil, layers: 1),
            "pancakes":          L(.discStack, P.pancakeGold, P.syrup, .porcelain, M(.cube, P.butterCube), nil, layers: 3),
            "french-toast":      L(.sandwichStack, P.frenchToast, P.syrup, .porcelain, M(.dot, P.berryRed), M(.cube, P.butterCube)),
            "grilled-cheese":    L(.sandwichStack, P.toastGold, P.cheeseGold, .porcelain, M(.disc, P.cheeseGold), nil),
            "blt-sandwich":      L(.sandwichStack, P.toastCream, P.lettuce, .porcelain, M(.strip, P.baconRed), M(.disc, P.tomatoRed)),
            "chicken-salad":     L(.sideBowl, P.saladGreen, nil, .porcelain, M(.strip, P.chickenTan), M(.disc, P.tomatoRed)),
            "mashed-potatoes":   L(.platedMound, P.mashCream, nil, .porcelain, M(.cube, P.butterCube), M(.ring, P.chive)),
            "burger-patty":      L(.grillPlate, P.pattyBrown, P.lettuce, .porcelain, M(.disc, P.tomatoRed), M(.disc, P.onionCream)),
            "mac-and-cheese":    L(.bakeDish, P.macCheese, P.pastaCream, .glaze, M(.dot, P.crumbGold), nil),
            "pan-seared-steak":  L(.grillPlate, P.steakBrown, P.butterGold, .porcelain, M(.strip, P.searDark), M(.leafy, P.rosemary)),

            // 멕시칸
            "quesadilla":        L(.foldedWrap, P.tortillaFlour, P.cheeseGold, .porcelain, M(.disc, P.tomatoRed), nil),
            "beef-tacos":        L(.foldedWrap, P.tortillaCorn, P.beefBrown, .porcelain, M(.leafy, P.lettuce), M(.disc, P.tomatoRed)),
            "burrito-bowl":      L(.riceBowl, P.riceWhite, P.beanBrown, .porcelain, M(.cube, P.tomatoRed), M(.leafy, P.lettuce)),
            "salsa-and-nachos":  L(.sideBowl, P.salsa, P.nachoGold, .porcelain, M(.leafy, P.cilantro), nil),
            "chicken-fajitas":   L(.foldedWrap, P.tortillaFlour, P.chickenTan, .porcelain, M(.strip, P.pepperRed), M(.strip, P.pepperGreen)),

            // 프렌치
            "ratatouille":       L(.bakeDish, P.ratatouille, P.zucchini, .glaze, M(.disc, P.eggplant), M(.disc, P.zucchini)),
            "cream-of-mushroom-soup": L(.soupBowl, P.creamSoup, nil, .porcelain, M(.disc, P.mushroomTan), M(.leafy, P.parsley)),
            "potato-gratin":     L(.bakeDish, P.gratinCream, P.potatoGold, .glaze, M(.disc, P.potatoGold), nil),
            "crepes":            L(.discStack, P.crepePale, P.syrup, .porcelain, M(.dot, P.berryRed), nil, layers: 2),
            "french-onion-soup": L(.soupBowl, P.onionSoup, nil, .glaze, M(.disc, P.toastGold), M(.disc, P.cheeseGold)),
            "nicoise-style-salad": L(.sideBowl, P.nicoise, nil, .porcelain, M(.yolk, P.eggYolk), M(.dot, P.oliveInk)),

            // 인도·중동·기타
            "schnitzel-style-cutlet": L(.grillPlate, P.cutletGold, P.lettuce, .porcelain, M(.disc, P.lemonYellow), nil),
            "butter-chicken-style-curry": L(.curryPlate, P.butterCurry, P.riceWhite, .porcelain, M(.strip, P.chickenTan), M(.leafy, P.cilantro)),
            "chickpea-curry":    L(.curryPlate, P.chickpeaCurry, P.riceWhite, .porcelain, M(.dot, P.chickpea), M(.leafy, P.cilantro)),
            "hummus-with-flatbread": L(.sideBowl, P.hummus, P.flatbread, .porcelain, M(.dot, P.chickpea), M(.leafy, P.parsley)),
            "shakshuka":         L(.skillet, P.shakshuka, nil, .iron, M(.yolk, P.eggYolk), M(.leafy, P.parsley)),
            "tandoori-style-chicken": L(.grillPlate, P.tandoori, P.lettuce, .porcelain, M(.disc, P.lemonYellow), M(.disc, P.onionCream)),
            "salmon-steak":      L(.grillPlate, P.salmonPink, P.asparagus, .porcelain, M(.disc, P.lemonYellow), nil),
            "garlic-butter-shrimp": L(.skillet, P.butterGold, nil, .iron, M(.strip, P.shrimpPink), M(.disc, P.garlicCream)),
            "vegetable-soup":    L(.soupBowl, P.vegSoup, nil, .porcelain, M(.cube, P.carrot), M(.disc, P.zucchini)),
        ]
    }()

    // MARK: 폴백 (커스텀·AI·미래 시드)

    /// 이름 키워드 → 원형. **한글·영문을 같이 본다**(커스텀 레시피는 로케일 표기가 en 슬롯에 들어온다).
    /// 위에서부터 먼저 걸리는 규칙이 이긴다 — 더 구체적인 키워드를 앞에 둔다
    /// ("김치볶음밥"이 "볶음"보다 먼저 "볶음밥"에 걸려야 한다).
    private static let keywordRules: [(needles: [String], archetype: DishArchetype)] = [
        // 짧은 키워드를 **품고 있는 합성어**를 맨 앞에 둔다 — "그라탕"의 `탕`, "탕수육"의 `탕`이
        // 찌개 규칙에 먼저 걸리면 오븐 요리·볶음이 통째로 국물 요리가 된다.
        (["그라탕", "gratin", "라자냐", "lasagna", "베이크", "bake", "casserole"], .bakeDish),
        (["탕수육", "탕수", "sweet and sour"], .skillet),
        (["볶음밥", "fried rice", "리조또", "리소토", "risotto", "필라프", "pilaf", "매쉬", "mashed"], .platedMound),
        (["덮밥", "비빔밥", "bibimbap", "donburi", "규동", "rice bowl", "burrito bowl", "포케", "poke"], .riceBowl),
        (["파스타", "pasta", "스파게티", "spaghetti", "펜네", "penne", "링귀니", "linguine"], .pastaPlate),
        (["볶음면", "라면", "면", "국수", "noodle", "ramen", "pho", "udon", "soba", "chow mein", "yakisoba", "pad thai"], .noodleBowl),
        (["찌개", "전골", "탕", "조림", "찜", "stew", "jjigae", "braised", "hot pot", "simmered"], .stewPot),
        (["수프", "스프", "국", "죽", "soup", "porridge", "chowder", "bisque", "broth", "congee"], .soupBowl),
        (["커리", "카레", "curry", "masala", "달", "dal"], .curryPlate),
        (["샌드위치", "토스트", "sandwich", "toast", "버거", "burger", "sub", "반미", "banh mi", "베이글", "bagel"], .sandwichStack),
        (["타코", "부리토", "랩", "또띠아", "taco", "burrito", "wrap", "quesadilla", "fajita", "tortilla"], .foldedWrap),
        (["김밥", "말이", "롤", "gimbap", "kimbap", "roll", "sushi", "초밥"], .rollSlices),
        (["팬케이크", "크레페", "전", "부침", "pancake", "crepe", "jeon", "frittata", "omelette", "omelet", "waffle", "와플"], .discStack),
        (["샐러드", "무침", "나물", "salad", "hummus", "dip", "salsa", "슬로", "slaw", "pickle", "겉절이"], .sideBowl),
        (["구이", "스테이크", "커틀릿", "돈까스", "grill", "steak", "cutlet", "schnitzel", "seared", "roast", "bbq", "탄두리", "tandoori"], .grillPlate),
        (["볶음", "불고기", "bulgogi", "제육", "stir-fry", "stir fry", "stir-fried", "stir fried", "saute", "sauté", "skillet", "pan-fried", "scrambled", "shakshuka"], .skillet),
        // ── 아래 셋은 **맨 끝**이 자리다: 위의 구체 규칙(볶음밥·rice bowl·salad·soup 계열)이 먼저
        //    선점한 뒤 남는 이름만 받는 그물이라, 앞으로 끌어올리면 "Salad Bowl"이 덮밥이 된다.
        (["오므라이스", "omurice"], .platedMound),  // 밥 산 위에 계란을 이불처럼 덮어 접시에 담는 플레이팅이라 공기(riceBowl)가 아니라 platedMound다.
        ([" rice"], .riceBowl),  // "Cheese and Spinach Rice"류 영문 밥 요리를 잡는 그물. 앞 공백이 "price"·"licorice" 오탐을 막고, "Rice ~"로 시작하는 이름은 대부분 위의 porridge·salad·omelette 계열 규칙이 먼저 채간다.
        ([" bowl"], .riceBowl),  // "Buddha Bowl"류를 잡는 그물. "Salad Bowl"은 위 샐러드 규칙이 먼저 선점한다.
    ]

    /// cuisine → 폴백 기본 원형·색조. 키워드가 하나도 안 걸릴 때 쓴다.
    /// (L, C, H)는 OKLCH — 아래에서 id 해시로 색상(H)을 흔들어 서로 다른 색이 나오게 한다.
    private static func cuisineDefault(_ cuisine: String?) -> (DishArchetype, Double, Double, Double) {
        switch cuisine?.lowercased() {
        case "korean":         (.stewPot, 0.56, 0.16, 34)
        case "japanese":       (.riceBowl, 0.66, 0.09, 62)
        case "chinese":        (.skillet, 0.56, 0.12, 48)
        case "italian":        (.pastaPlate, 0.60, 0.15, 36)
        case "french":         (.soupBowl, 0.78, 0.06, 78)
        case "mexican":        (.foldedWrap, 0.80, 0.09, 82)
        case "indian", "thai": (.curryPlate, 0.62, 0.14, 66)
        case "vietnamese":     (.noodleBowl, 0.90, 0.03, 92)
        case "middle-eastern": (.sideBowl, 0.78, 0.08, 80)
        case "american":       (.grillPlate, 0.50, 0.09, 46)
        default:               (.soupBowl, 0.70, 0.10, 70)
        }
    }

    /// 프로세스 간에 안정적인 해시(FNV-1a) — `String.hashValue`는 실행마다 시드가 바뀌어
    /// 같은 레시피가 런치마다 다른 색이 된다(스크린샷 회귀가 불가능해진다).
    static func stableHash(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x0000_0100_0000_01b3 }
        return h
    }

    /// 나라 이름은 키워드 매칭에서 **먼저 지운다** — "중국식 가지볶음"의 "중국"이 `국`(수프)에,
    /// "태국식 볶음면"의 "태국"이 같은 규칙에 걸려 요리가 통째로 엉뚱한 원형으로 간다.
    /// 나라는 `cuisine` 필드가 이미 들고 있으므로 이름에서 지워도 정보가 사라지지 않는다.
    private static let countryNoise = ["중국", "한국", "태국", "미국", "영국", "일본", "프랑스"]

    /// 이름 키워드가 집어낸 원형 — 아무 규칙도 안 걸리면 nil(호출부가 cuisine 기본으로 내려간다).
    /// 폴백과 분리해 둔 이유는 **"이름이 요리를 지목했는가"** 자체가 히어로 체인의 분기점이기 때문이다.
    static func keywordArchetype(name: String, koreanName: String?) -> DishArchetype? {
        var hay = ([name, koreanName].compactMap { $0 }).joined(separator: " ").lowercased()
        for noise in countryNoise { hay = hay.replacingOccurrences(of: noise, with: " ") }
        return keywordRules.first { $0.needles.contains { hay.contains($0) } }?.archetype
    }

    /// 매핑이 없는 레시피의 아이콘. **절대 빈 결과를 내지 않는다** — 원형·색·고명이 항상 채워진다.
    static func fallback(name: String, koreanName: String?, cuisine: String?, id: String) -> DishLook {
        let (defaultArchetype, dl, dc, dh) = cuisineDefault(cuisine)
        let archetype = keywordArchetype(name: name, koreanName: koreanName) ?? defaultArchetype
        // 색상은 id 해시로 흔든다 — 매핑 없는 레시피 여럿이 같은 원형에 몰려도 서로 다른 색이 된다.
        let h = stableHash(id)
        let fill = ReffiColor.oklch(dl + Double(h % 5) * 0.012 - 0.024,
                                    dc,
                                    (dh + Double((h >> 8) % 7) * 9).truncatingRemainder(dividingBy: 360))
        let markPool: [DishMark] = [M(.ring, DishPalette.scallion), M(.disc, DishPalette.carrot),
                                    M(.leafy, DishPalette.parsley), M(.cube, DishPalette.tofuWhite),
                                    M(.dot, DishPalette.sesame), M(.strip, DishPalette.chickenTan)]
        let i1 = Int((h >> 16) % UInt64(markPool.count))
        let i2 = Int((h >> 24) % UInt64(markPool.count - 1))
        return DishLook(archetype: archetype,
                        fill: fill,
                        accent: accentDefault(for: archetype),
                        vessel: archetype == .stewPot ? .clay : (archetype == .skillet ? .iron : .porcelain),
                        mark: markPool[i1],
                        mark2: markPool[(i1 + 1 + i2) % markPool.count],
                        layers: archetype == .rollSlices ? 3 : (archetype == .discStack ? 2 : 1))
    }

    /// 폴백 보조 면 — **보조 면이 없으면 형태가 무너지는 원형**(밥이 없는 커리 접시, 속이 없는 샌드위치)만
    /// 기본값을 채운다. 나머지는 nil로 두어 원형이 스스로 완결되게 한다.
    private static func accentDefault(for a: DishArchetype) -> Color? {
        switch a {
        case .curryPlate, .riceBowl:  DishPalette.riceWhite
        case .sandwichStack:          DishPalette.lettuce
        case .foldedWrap:             DishPalette.beefBrown
        case .rollSlices:             DishPalette.riceWhite
        case .bakeDish:               DishPalette.pastaCream
        case .grillPlate:             DishPalette.lettuce
        default:                      nil
        }
    }
}
