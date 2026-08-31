import SwiftUI

/// 영수증/티켓 셰이프 — 상·하 절취(찢김) 엣지. 좌우는 곧다.
///
/// 앱의 시그니처 종이 어휘라 피처가 아니라 디자인 시스템에 산다(`PaperShape` 옆).
///
/// **`tooth`는 톱니의 진폭이 아니라 세로 인셋 예산이다.** `receiptSurface`가 `s5 + tooth`로 콘텐츠
/// 여백을 잡는 그 값이고(`ReffiTooth.chip`/`card`/`ticket` = 6/7/9), 실제 찢김은 그 예산 **안에서**
/// 진폭과 주기를 따로 파생해 그린다. 예전에는 한 숫자가 진폭·주기·인셋을 동시에 맡아 진폭 = 주기/2가
/// 구조적으로 고정됐다 — 빗변이 어떤 크기·어떤 프리셋에서도 정확히 45°였고, 그래서 "촘촘하게"와
/// "얕게"를 동시에 요구하면 표현할 방법 자체가 없었다.
/// **진폭과 주기를 다시 한 숫자로 묶지 마라** — 묶는 순간 45° 삼각파로 돌아가고, 그건 찢은 종이가
/// 아니라 클립아트다.
///
/// `seed`는 칸마다의 변주(봉우리 x·봉우리 들뜸·골 깊이·느린 휨 위상)를 뽑는 난수 시드다.
/// `PaperRect`·`PaperBlob`의 규약과 같다: **시드가 같으면 항상 같은 모양**이라 레이아웃이 흔들리지
/// 않는다. 다만 `seed: 0`이 "변주 없음"을 뜻하지는 않는다 — 상·하 두 변은 시드와 무관하게 서로 다른
/// 난수 스트림을 타므로, 시드를 안 넘겨도 두 절취선이 정렬되지 않는다. 그게 요점이다(아래 `path(in:)`).
struct ReceiptShape: Shape {
    var tooth: CGFloat = ReffiTooth.ticket
    var seed: Int = 0

    // MARK: - 절취 기하
    //
    // 아래 상수의 출처를 정직하게 적는다: **실측이 아니라 눈 판정이다**("톱니가 너무 크고 아마추어
    // 클립아트 같다"는 오너 피드백에 맞춘 값). 종이 물성 인용처럼 보이는 숫자를 여기 박아 두면 다음
    // 사람이 재현할 수도 반박할 수도 없는 근거에 발이 묶인다 — 그러니 **값은 언제든 눈으로 다시 정해도
    // 된다**. 되돌리면 안 되는 것은 값이 아니라 아래 세 관계다.
    //
    // 값은 판단이지만 **관계는 규칙**이다. 셋 다 깨지면 옛 클립아트로 돌아간다:
    //   · 진폭 ≪ 주기 — 빗변이 완만해야 "찢겼다"로 읽힌다(옛 값 0.50 = 45°, 지금 ≈0.29).
    //   · 진폭 ≪ tooth — 찢김은 인셋 예산 **안에** 산다. 예산을 다 쓰면 그게 옛 구조다.
    //   · 칸 수는 tooth가 작을수록 많다 — 좁은 종이일수록 절취 리듬이 촘촘해야 조각으로 안 보인다.

    /// 진폭 = `tooth` × 이 값. **톱니 깊이를 조절하는 단 하나의 손잡이다** — 눈에 안 맞으면 여기만 만진다.
    static let depthRatio: CGFloat = 0.34
    /// 진폭 절대 상한(pt). **폭 비율이 아니다**: 찢김의 거칠기는 종이가 넓다고 커지는 성질이 아니라
    /// 화면 스케일에 매인 값이라, 272pt 소품과 358pt 카드에 같은 "상대 깊이"를 주면 오히려 두 종이가
    /// 서로 다른 재질로 갈린다. tooth 9(티켓)만 이 상한에 걸려 3.06 → 2.6으로 눌린다.
    static let depthCap: CGFloat = 2.6
    /// 주기 = `tooth` × 이 값 — chip 6.9 · card 8.05 · ticket 10.35pt. 티켓이 여전히 가장 굵은 리듬이다
    /// (`ReffiTooth.ticket` 주석의 "가장 큰 종이라 절취 리듬도 가장 굵다"를 진폭이 아니라 주기가 맡는다).
    static let pitchRatio: CGFloat = 1.15
    /// 봉우리 x 흔들림 — 봉우리 중심이 칸 한가운데에서 ±`jitterX`/2 칸만큼 흔들린다.
    /// 칸 경계(골)는 흔들지 않는다: 경계가 흔들리면 마지막 칸이 코너에서 벗어나 가시가 돌아온다.
    static let jitterX: CGFloat = 0.18
    /// 봉우리 들뜸(진폭 대비) — 봉우리가 바깥 변에 딱 붙지 않고 조금씩 안으로 물러난다.
    static let jitterPeak: CGFloat = 0.20
    /// 골 깊이 흔들림(진폭 대비) — 칸마다 파인 깊이가 다르다.
    static let jitterValley: CGFloat = 0.38
    /// 봉우리 평탄부 반폭(칸 대비) — 봉우리를 한 점으로 끝내지 않는다.
    static let tipFlat: CGFloat = 0.10
    /// 느린 휨(진폭 대비 감쇠 폭) — 골 기준선이 폭을 가로질러 천천히 얕아졌다 깊어진다.
    static let bowRatio: CGFloat = 0.25
    /// 칸 수 상한. `path(in:)`은 레이아웃마다 불리므로 비정상적으로 넓은 프레임이 들어와도 루프가
    /// 폭주하지 않아야 한다. 실제로 쓰이는 최대치는 iPad 폭 × chip ≈ 150칸이라 여유가 충분하다.
    static let maxCells = 512

    func path(in rect: CGRect) -> Path {
        // 레이아웃 프로빙 패스는 NaN·무한 크기를 던진다. 그 값이 아래 정수 변환에 닿으면 **트랩**(크래시)이라,
        // 정수 칸 분할을 도입하면서 함께 닫아야 하는 문이다(옛 코드는 정수 변환이 없어 루프가 안 돌 뿐이었다).
        guard rect.width.isFinite, rect.height.isFinite,
              rect.minX.isFinite, rect.minY.isFinite,
              rect.width > 0, rect.height > 0 else { return Path() }

        let t = max(4, tooth)
        // 진폭은 세 상한을 동시에 지킨다: tooth 비율 · 절대 상한 · 면 높이(납작한 면에서 위아래 절취선이
        // 서로를 파고들지 않게). 하한 0.75pt는 3x에서 2px — 이보다 얕으면 1pt 헤어라인에 먹혀 절취선이
        // 아예 사라지고, 그러면 증상이 "톱니가 크다"에서 "매끈한 플라스틱 판"으로 갈아탈 뿐이다.
        let depth = max(0.75, min(t * Self.depthRatio, Self.depthCap, rect.height * 0.25))
        let pitch = max(4, t * Self.pitchRatio)

        // **폭을 정수 칸으로 나눈다.** 마지막 칸을 maxX로 클램프하던 옛 코드는 폭이 주기의 배수가 아닐 때
        // 코너에 "폭 1~4pt × 높이 tooth"의 거의 수직인 가시를 남겼다(카드 358/7 → 1pt, 프로필 346/7 → 3pt,
        // 홈 스트립 358/6 → 4pt). 칸 폭을 `폭 ÷ 정수`로 잡으면 마지막 골이 항상 코너에 정확히 앉아
        // 그 잔여 조각이 **존재할 수 없다**. 칸 폭이 주기에서 최대 반 칸 어긋나는 대가는 눈에 안 보인다.
        let cells = (rect.width / pitch).rounded()
        // 상한 비교를 정수 변환 **전에** 한다 — `Int(_:)`는 Int 범위 밖 값에서 트랩한다.
        let n = cells >= CGFloat(Self.maxCells) ? Self.maxCells : max(3, Int(cells))
        let step = rect.width / CGFloat(n)

        // 상·하단은 **서로 다른 난수 스트림**을 탄다. 같은 스트림이면 두 변이 정확히 180° 회전대칭으로
        // 맞물려(옛 코드에서 폭이 주기의 짝수 배일 때 실제로 그랬다 — 냉장고 카드 322, 오더 메모 342)
        // 오려 낸 종이가 아니라 스탬프로 찍은 테두리가 된다. 호출부 대부분이 시드를 안 넘기므로
        // 이 분리는 **시드가 아니라 구조**로 보장해야 한다.
        let base = UInt64(bitPattern: Int64(seed))
        var top = SeededGen(base &* 2 &+ 1)
        var bottom = SeededGen(base &* 2 &+ 0x9E37_79B9)

        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + depth))
        tear(&p, y0: rect.minY, x0: rect.minX, n: n, step:  step, depth: depth, into:  1, gen: &top)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - depth))
        tear(&p, y0: rect.maxY, x0: rect.maxX, n: n, step: -step, depth: depth, into: -1, gen: &bottom)
        p.closeSubpath()
        return p
    }

    /// 절취선 한 변 — 칸마다 세 점(봉우리 왼쪽 → 봉우리 오른쪽 → 다음 골)을 찍는다.
    /// `x0`/`step`의 부호로 좌→우(상단)와 우→좌(하단)를 같은 코드가 그린다.
    ///
    /// `into`는 종이 안쪽 방향(+1 = 아래로). **모든 y가 `[y0, y0 + into·depth]` 안**이라 어떤 시드에서도
    /// 종이가 프레임을 벗어나지 않는다(`staysInsideFrameForEveryToothAndSeed`가 잠그는 성질).
    /// x도 칸 경계를 넘지 않는다 — 봉우리는 칸의 [0.31, 0.69] 구간에만 앉으므로 x가 단조롭고,
    /// 경로가 스스로를 가로지르지 않는다. `jitterX`나 `tipFlat`을 키울 거면 두 값의 합이 0.5 미만인지
    /// 먼저 확인해라(넘기면 이웃 칸을 침범해 경로가 꼬인다).
    ///
    /// **봉우리를 한 점이 아니라 짧은 평탄부로 끝낸다** — 실제로 찢긴 자리에는 수학적 꼭짓점이 없다.
    /// 진폭 2pt대에서는 곡선 라운딩이 1pt 헤어라인에 먹혀 지각되지 않으므로, 평탄부와 봉우리 들뜸
    /// 지터가 같은 인상을 훨씬 싸게 만든다(`path(in:)`은 레이아웃마다 불린다).
    private func tear(_ p: inout Path, y0: CGFloat, x0: CGFloat, n: Int, step: CGFloat,
                      depth: CGFloat, into: CGFloat, gen: inout SeededGen) {
        let bowPhase = CGFloat(gen.unit()) * .pi * 2
        for k in 0..<n {
            let a = x0 + step * CGFloat(k)
            // 느린 휨 — 칸별 지터만 두면 백색잡음이라 조금만 떨어져 봐도 도로 균일한 회색 띠로 읽힌다.
            // 폭을 가로지르는 저주파 성분이 있어야 "한 번에 쭉 찢었다"는 인상이 생긴다.
            let bow = 0.5 + 0.5 * sin(CGFloat(k) / CGFloat(n) * .pi * 3 + bowPhase)   // 0…1
            let peakY = y0 + into * depth * Self.jitterPeak * CGFloat(gen.unit())
            let valleyJitter = 1 - Self.jitterValley * CGFloat(gen.unit())   // 칸마다 파인 깊이
            let valleyBow = 1 - Self.bowRatio + Self.bowRatio * bow          // 폭을 가로지르는 저주파
            let valleyDepth = depth * valleyJitter * valleyBow               // ≤ depth (프레임 계약)
            let mid = a + step * (0.5 + (CGFloat(gen.unit()) - 0.5) * Self.jitterX)
            p.addLine(to: CGPoint(x: mid - step * Self.tipFlat, y: peakY))
            p.addLine(to: CGPoint(x: mid + step * Self.tipFlat, y: peakY))
            // 마지막 골만은 지터 없이 코너에 **정확히** 앉힌다 — 좌우 직선변이 시작하는 깊이와 같아야
            // 코너에 이음매가 안 생긴다. 칸 경계 x에는 애초에 지터가 없다(위 주석의 단조성 근거).
            p.addLine(to: CGPoint(x: a + step,
                                  y: k == n - 1 ? y0 + into * depth : y0 + into * valleyDepth))
        }
    }
}

/// 영수증 면이 얼마나 들려 있나(§6.4) — 카드 그림자 토큰과 1:1.
enum ReffiPaperLift {
    /// 캔버스에 붙은 종이 — 빈 상태·검색 결과 없음처럼 조용한 안내 면.
    case flat
    /// 오린 영수증 한 장(`reffiShadowCard`).
    case card
    /// 떠 있는 요소(`reffiShadow1`) — 온보딩 질문 카드·로그인 카드처럼 화면에 한 장만 뜨는 면.
    case floating
}

extension View {

    /// 흰 영수증 카드 한 장(§13.8) — 톱니 면 + 종이 결 + 종이 헤어라인 + 엘리베이션을 한 번에 얹는다.
    ///
    /// **세로 패딩을 톱니에서 계산하는 게 이 모디파이어의 핵심**이다. 톱니는 면 안쪽으로 파고들어
    /// 그만큼 콘텐츠 여백을 먹는데, 그 보정을 호출부가 손으로 적어 온 결과 같은 카드가 s5+7 / s5+3 /
    /// s5로 갈렸다(=톱니를 7로 정해 놓고 보정은 3만 준 카드가 셋). 여기서 `s5 + tooth`로 한 번만
    /// 계산하면 톱니를 바꿔도 여백이 따라온다.
    ///
    /// 헤더 행이 따로 있는 카드(`ReceiptCard`·`FridgeCard`)는 위·아래 보정이 비대칭이라 자체
    /// 프리셋으로 남는다 — 그 프리셋도 톱니와 엘리베이션은 이 토큰들을 쓴다.
    /// `seed`는 칸별 절취 변주와 종이 결의 시드다 — 한 화면에 영수증이 여러 장 겹칠 때 의미가 있고,
    /// 안 넘겨도 상·하 절취선은 서로 다른 그림이다(`ReceiptShape` 참조).
    func receiptSurface(tooth: CGFloat = ReffiTooth.card,
                        seed: Int = 0,
                        alignment: Alignment = .leading,
                        elevated: ReffiPaperLift = .card) -> some View {
        modifier(ReceiptSurface(tooth: tooth, seed: seed, alignment: alignment, lift: elevated))
    }
}

private struct ReceiptSurface: ViewModifier {
    let tooth: CGFloat
    let seed: Int
    let alignment: Alignment
    let lift: ReffiPaperLift

    func body(content: Content) -> some View {
        let shape = ReceiptShape(tooth: tooth, seed: seed)
        let surface = content
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s5 + tooth)   // 톱니 인셋 보정
            .frame(maxWidth: .infinity, alignment: alignment)
            // **이 앱에서 매끈한 면은 시스템 컨트롤이고, 종이는 전부 결을 갖는다** — `fieldSurface`가
            // 입력 필드에 대해 못박은 그 규칙(PaperShape.swift)의 같은 축이다. 정작 앱에서 가장 넓은
            // 종이인 영수증만 결이 없어, 결을 가진 버튼·칩·필드 옆에서 혼자 플라스틱 판으로 읽혔다.
            //
            // 세기 0.4는 시스템 최저값이다(버튼 1.4 · 칩·다이얼로그 0.9 · 필드 0.5). 두 가지 이유로
            // 낮춘다: ① 결의 인상은 반점 밀도 × 면적이라 버튼과 같은 세기를 400×700pt 면에 주면
            // 훨씬 거칠어 보인다 ② 감열지는 코팅면이라 실제로 매끈한 축이다. 결은 "종이다"만 말하면
            // 되고, 이 면에서 형태를 맡는 것은 절취선이다.
            //
            // **그림자는 안전하다** — 아래 `compositingGroup()`이 이 Canvas까지 한 장으로 묶은 뒤에야
            // `lift`의 그림자가 걸리므로, 반점 하나하나가 자기 그림자를 얻지 않는다. 같은 경계가
            // `.overlay` 블렌드도 카드 안에 가둔다(겹쳐 쌓인 아래 카드로 새지 않는다).
            //
            // 비용은 정직하게 적는다: `PaperGrain`의 반점 수는 면적 비례이고 상한이 없다(상한을 걸면
            // 큰 카드만 다른 종이가 되므로 일부러 없앤 것이다). 긴 목록 카드가 스크롤에서 프레임을
            // 떨구면 **밀도를 깎지 말고** 이 배경에 `.drawingGroup()`을 붙여 정적 래스터로 굳혀라 —
            // 카드 수만큼 오프스크린 텍스처가 생기므로 메모리와 맞바꾸는 선택이다.
            .background {
                shape.fill(ReffiColor.receipt)
                    .overlay(PaperGrain(seed: UInt64(bitPattern: Int64(seed)) &+ 23, strength: 0.4)
                                .clipShape(shape))
            }
            .paperEdge(shape)
            // **영수증 한 장은 그림자도 한 장 몫만 드리운다.**
            //
            // SwiftUI의 `.shadow`는 붙인 뷰를 하나로 합쳐서 드리우는 게 아니라 **자식 프리미티브마다
            // 따로** 드리운다(합쳐서 한 번 드리우게 하려면 그 전에 합성 그룹으로 묶어야 한다).
            // 그래서 아래 `lift`의 그림자가 카드 윤곽뿐 아니라 **카드 안에서 면을 가진 자식 전부**에
            // 각자 그림자를 달아 주고 있었다. To buy 메모 행이 그 값을 정면으로 받았다: 행 얼굴은
            // 밀기용 불투명 면이라(21차 `1834785`, 뒤의 빨간 조각을 가리는 유일한 수단) 카드와 **같은
            // `receipt` 토큰**인데도, 자기 그림자를 얻는 순간 영수증 위에 뜬 흰 카드로 읽혔다
            // (사용자 제보 "리스트에 쉐도우가 있어서 어색해"). 실측: 행 얼굴과 카드 얼굴의 픽셀은
            // 같은 (251,250,247)인데 행 아래로 폭 ≈9pt의 어두운 띠(249 → 241)가 깔려 있었다.
            //
            // 여기서 묶으면 그림자는 **영수증 윤곽 한 번**만 그려진다. 덤으로 긴 카드(타임라인)에서
            // 자식 수만큼 돌던 그림자 필터가 한 번으로 줄어든다.
            .compositingGroup()

        switch lift {
        case .flat:     surface
        case .card:     surface.reffiShadowCard()
        case .floating: surface.reffiShadow1()
        }
    }
}

/// 가로 점선/구분선용 1px 라인.
struct HLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
