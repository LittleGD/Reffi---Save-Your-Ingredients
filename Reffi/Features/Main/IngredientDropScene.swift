import SpriteKit
import SwiftUI

/// 재료 낙하 씬(§13) — **진짜 물리 엔진**(SpriteKit, 레퍼런스 École Vision의 gravity-based). 재료가 위에서
/// 떨어져 충돌·바운스하며 **쌓여서 그대로 남는다**(사라지지 않음). 끌어서 던질 수 있고, 짧게 탭하면 판정을 묻는다.
/// 재료 식별·신선도는 실루엣 + 아래 뱃지 행이 전달한다(씬 위 이름 라벨 없음, §13.4).
/// 바닥은 씬 하단보다 위(요리시작 버튼 충돌 마진). 터치는 **한 손가락만** 추적해 멀티터치에 상태가 안 꼬인다.
final class IngredientDropScene: SKScene {
    private var chips: [UUID: SKSpriteNode] = [:]
    private var textureCache: [String: SKTexture] = [:]
    private var pending: [Ingredient] = []

    private var dragTouch: UITouch?          // 추적 중인 단일 터치 — 나머지 손가락은 무시
    private var dragged: SKSpriteNode?
    private var dragTarget: CGPoint = .zero
    private var dragStart: CGPoint = .zero   // 탭 판정은 시작점 기준 누적 이동으로(느린 드래그 오판 방지)
    private var dragMoved = false

    /// 짧은 탭 = 판정 묻기(Ate/Tossed).
    var onRemove: ((UUID) -> Void)?
    /// 제스처 판정(§13.6 B) — 칩을 존에 끌어다 놓으면 (id, wasted). 탭 오버레이는 접근성 경로로 유지.
    var onDecide: ((UUID, Bool) -> Void)?
    var reduceMotion = false

    // 판정 바스켓 — 드래그 중에만 나타나는 휴지통(좌상)·냄비(우상) 종이 블롭.
    // 손가락이 근처에 오면 재료가 자석처럼 끌려 들어간다(마그네틱 캡처).
    private var tossZone: SKSpriteNode?
    private var ateZone: SKSpriteNode?
    private let zoneSide: CGFloat = 86
    private let magnetRadius: CGFloat = 88

    private var chipSide: CGFloat { min(max(124, size.width * 0.42), 188) }
    private var floorY: CGFloat { max(6, size.height * 0.03) }
    private var boxInset: CGFloat { 2 }
    private var boxTop: CGFloat { size.height + 700 }   // 스폰 상한보다 위 → 닫힌 천장

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -42)   // 적당히 — 가볍게 떨어지되 둥둥 뜨진 않게
        buildWalls()
        layoutZones()
        sync(pending)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 1 else { return }
        buildWalls()
        layoutZones()
    }

    /// 드래그 중인 재료를 손가락 쪽으로 **스프링처럼 끌어당긴다**(텔레포트 아님).
    /// 거리 비례 목표 속도 + 가속 제한 → 약간의 딜레이·관성(실감, §13.4). 동적 바디라 이웃을
    /// 부드럽게 밀 뿐 튕겨내지 않는다. 속도 상한으로 과격한 밀침을 막는다.
    override func update(_ currentTime: TimeInterval) {
        guard let node = dragged, let body = node.physicsBody else { return }
        // 마그네틱 캡처 — 손가락이 바스켓 근처면 추종 목표가 바스켓 중심으로 스냅되어
        // 재료가 자석처럼 끌려 들어간다. 손가락이 벗어나면 다시 손가락을 따른다.
        let captured = captureZone(near: dragTarget)
        let goal = captured?.position ?? dragTarget
        let to = CGVector(dx: goal.x - node.position.x, dy: goal.y - node.position.y)
        let follow: CGFloat = captured != nil ? 13 : 9   // 캡처 중엔 더 민첩하게 착 붙게
        let maxSpeed: CGFloat = 820      // 추종 속도 상한 → 이웃을 과격하게 안 밀침
        var vx = to.dx * follow, vy = to.dy * follow
        let m = hypot(vx, vy)
        if m > maxSpeed { vx *= maxSpeed / m; vy *= maxSpeed / m }
        let inertia: CGFloat = 0.24      // 0~1, 클수록 가볍게(덜 묵직) 따라옴
        let v = body.velocity
        body.velocity = CGVector(dx: v.dx + (vx - v.dx) * inertia,
                                 dy: v.dy + (vy - v.dy) * inertia)
        highlight(tossZone, hovering: captured === tossZone)
        highlight(ateZone, hovering: captured === ateZone)
    }

    /// 손가락 위치 기준 캡처 바스켓(반경 내 가장 가까운 것).
    private func captureZone(near p: CGPoint) -> SKSpriteNode? {
        var best: (zone: SKSpriteNode, d: CGFloat)?
        for z in [tossZone, ateZone].compactMap({ $0 }) {
            let d = hypot(p.x - z.position.x, p.y - z.position.y)
            if d < magnetRadius, d < (best?.d ?? .infinity) { best = (z, d) }
        }
        return best?.zone
    }

    // MARK: - 판정 존 (§13.6 B)

    /// 존 스프라이트 — PaperBlob + 채운 아이콘을 텍스처로 렌더. 평소엔 숨김(alpha 0).
    private func makeZone(toss: Bool) -> SKSpriteNode {
        let tint = toss ? ReffiColor.urgentDark : ReffiColor.blueDark
        let view = ZStack {
            PaperBlob(sides: 9, seed: toss ? 3 : 6)
                .fill(toss ? ReffiColor.urgentLight : ReffiColor.blueLight)
            PaperBlob(sides: 9, seed: toss ? 3 : 6)
                .stroke(tint.opacity(0.35), lineWidth: 1.5)
            (toss ? ReffiIcon.toss : ReffiIcon.ate).reffi(30, .fill)
                .foregroundStyle(tint)
        }
        .frame(width: zoneSide, height: zoneSide)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        let node = SKSpriteNode(texture: renderer.uiImage.map { SKTexture(image: $0) },
                                size: CGSize(width: zoneSide, height: zoneSide))
        node.alpha = 0
        node.zPosition = 30
        return node
    }

    private func layoutZones() {
        guard size.width > 1 else { return }
        if tossZone == nil { let z = makeZone(toss: true); tossZone = z; addChild(z) }
        if ateZone == nil { let z = makeZone(toss: false); ateZone = z; addChild(z) }
        // 상단 모서리 — 더미(바닥)와 겹치지 않고, 들어 올려서 넣는 제스처가 자연스럽다.
        let y = size.height - zoneSide * 0.5 - 12
        tossZone?.position = CGPoint(x: zoneSide * 0.5 + 14, y: y)
        ateZone?.position = CGPoint(x: size.width - zoneSide * 0.5 - 14, y: y)
    }

    /// 드래그 시작/끝에만 보인다 — 평소엔 물리 필드를 어지럽히지 않는다.
    private func setZones(visible: Bool) {
        let fade = SKAction.fadeAlpha(to: visible ? 0.96 : 0, duration: 0.15)
        tossZone?.run(fade)
        ateZone?.run(fade)
        if !visible {
            tossZone?.setScale(1)
            ateZone?.setScale(1)
        }
    }

    private func highlight(_ zone: SKSpriteNode?, hovering: Bool) {
        guard let z = zone else { return }
        let target: CGFloat = hovering ? 1.14 : 1.0
        if abs(z.xScale - target) > 0.01 { z.run(.scale(to: target, duration: 0.1)) }
    }

    /// 바닥(요리시작 버튼 마진) + 좌·우 벽 + 천장으로 **완전히 닫힌 상자**.
    /// 닫혀 있으므로 끌거나 던져도 재료가 화면 밖으로 새지 않는다.
    private func buildWalls() {
        guard size.width > 1, size.height > 1 else { return }
        childNode(withName: "walls")?.removeFromParent()
        let rect = CGRect(x: boxInset, y: floorY,
                          width: size.width - boxInset * 2, height: boxTop - floorY)
        let walls = SKNode()
        walls.name = "walls"
        walls.physicsBody = SKPhysicsBody(edgeLoopFrom: rect)   // 닫힌 루프(상자)
        walls.physicsBody?.friction = 0.7
        addChild(walls)
    }

    private func texture(for ing: Ingredient, side: CGFloat) -> SKTexture? {
        let key = ing.glyph.rawValue   // 자연색이라 신선도와 무관(라벨은 별도 노드)
        if let t = textureCache[key] { return t }
        let view = PaperSilhouette(glyph: ing.glyph, fresh: ing.freshness).frame(width: side, height: side)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let img = renderer.uiImage else { return nil }
        let t = SKTexture(image: img)
        textureCache[key] = t
        return t
    }

    func sync(_ ingredients: [Ingredient]) {
        pending = ingredients
        guard size.width > 1 else { return }
        let ids = Set(ingredients.map(\.id))
        // 빠진 재료는 뿅 사라짐(스프링 팝). 새 재료는 추가.
        for (id, node) in chips where !ids.contains(id) {
            popOut(node, id: id)
        }
        for (i, ing) in ingredients.enumerated() {
            if let node = chips[ing.id] {
                // 이름이 편집됐으면(글리프도 바뀔 수 있음) 칩을 다시 만든다.
                if (node.userData?["name"] as? String) != ing.name {
                    popOut(node, id: ing.id)
                    addChip(ing, order: i, count: ingredients.count)
                }
            } else {
                addChip(ing, order: i, count: ingredients.count)
            }
        }
    }

    /// 제거 연출 — 살짝 커졌다(easeOut) → 뿅 줄며 사라짐(easeIn). Reduce Motion이면 빠른 페이드만.
    /// 제거 중인 노드는 이름을 지워 다시 잡히지 않게 하고, 드래그 중이었다면 드래그 상태도 정리한다.
    private func popOut(_ node: SKSpriteNode, id: UUID) {
        chips[id] = nil
        node.name = nil          // 사라지는 중엔 히트 대상에서 제외
        node.physicsBody = nil   // 물리 정지(충돌에서 제외)
        node.zPosition = 50
        if node === dragged { dragged = nil; dragTouch = nil }

        if reduceMotion {
            node.run(.sequence([.fadeOut(withDuration: 0.12), .removeFromParent()]))
        } else {
            let grow = SKAction.scale(to: node.xScale * 1.25, duration: 0.13); grow.timingMode = .easeOut
            let pop = SKAction.scale(to: 0.0, duration: 0.17); pop.timingMode = .easeIn
            let fade = SKAction.fadeOut(withDuration: 0.17)
            node.run(.sequence([grow, .group([pop, fade]), .removeFromParent()]))
        }
    }

    private func addChip(_ ing: Ingredient, order: Int, count: Int) {
        let s = chipSide
        let node: SKSpriteNode
        let body: SKPhysicsBody
        if let tex = texture(for: ing, side: s) {
            node = SKSpriteNode(texture: tex, size: CGSize(width: s, height: s))
            // 충돌체 = 실루엣 **실제 모양**(텍스처 알파, 그림자 0.2는 임계값 0.5로 제외).
            // 재료 사이 빈틈 없이 맞물려 자연스럽게 쌓인다.
            body = SKPhysicsBody(texture: tex, alphaThreshold: 0.5, size: CGSize(width: s, height: s))
        } else {
            node = SKSpriteNode(color: UIColor(ing.freshness.main), size: CGSize(width: s, height: s))
            body = makeBody(for: ing.glyph, side: s)
        }
        node.physicsBody = body
        node.name = "chip:\(ing.id.uuidString)"
        node.userData = ["name": ing.name]
        body.restitution = 0.12          // 살짝 통통 — 가벼운 느낌
        body.friction = 0.55
        body.linearDamping = 0.2         // 둥둥 뜨진 않게, 빨리 안착
        body.angularDamping = 0.85       // 자연스럽게 기울며 안착하되 무한 회전은 억제
        body.allowsRotation = true       // 자연스러운 물리 — 기울고 굴러 빈틈에 안착
        body.mass = 0.7                  // 가볍게
        body.usesPreciseCollisionDetection = true

        // 가운데 좁은 밴드로 모아 떨어뜨려 **한 더미로 쌓이게** 한다(좌우로 흩지 않음).
        let n = max(1, count)
        let frac = n == 1 ? 0.5 : CGFloat(order) / CGFloat(n - 1)        // 0..1
        let band = min(size.width * 0.66, s * 1.7)                      // 더미 밑변 폭(가운데로 모으되 탑처럼 쌓지 않게)
        let x = size.width / 2 + (frac - 0.5) * band
        node.zRotation = (order % 2 == 0) ? 0.16 : -0.18
        if reduceMotion {
            node.position = CGPoint(x: x, y: floorY + s * (0.45 + CGFloat(order % 3) * 0.5))
        } else {
            // 위에서 스태거 낙하 → 더미. 스폰은 항상 닫힌 천장 **아래**(상자 밖 탈출 방지).
            let y = min(size.height + s * (0.4 + CGFloat(order) * 0.5), boxTop - s * 0.6)
            node.position = CGPoint(x: x, y: y)
        }
        addChild(node)
        chips[ing.id] = node
    }

    /// 글리프별 근사 충돌체(볼록 타원) — 원 대신 재료 비율에 맞춰 자연스럽고 안정적으로 쌓이게.
    private func makeBody(for glyph: FoodGlyph, side s: CGFloat) -> SKPhysicsBody {
        let wf: CGFloat, hf: CGFloat
        switch glyph {
        case .root, .squash:                (wf, hf) = (0.46, 0.80)   // 길쭉 세로(당근·애호박)
        case .milk:                         (wf, hf) = (0.52, 0.80)   // 우유팩
        case .leaf:                         (wf, hf) = (0.54, 0.78)   // 잎
        case .fish:                         (wf, hf) = (0.84, 0.52)   // 길쭉 가로(생선)
        case .meat, .tofu, .cheese, .bread: (wf, hf) = (0.80, 0.60)   // 넓적(고기·두부·치즈·빵)
        case .egg, .mushroom, .pepper, .poultry, .shrimp, .citrus:
                                            (wf, hf) = (0.66, 0.74)   // 타원(달걀·버섯 등)
        default:                            (wf, hf) = (0.74, 0.74)   // 둥근(토마토·양파·사과 등)
        }
        return Self.ovalBody(s * wf, s * hf)
    }

    /// 볼록 N각형 타원 바디 — SpriteKit `polygonFrom`은 볼록만 허용해 끼임·진동이 없다.
    private static func ovalBody(_ w: CGFloat, _ h: CGFloat, sides: Int = 14) -> SKPhysicsBody {
        let path = CGMutablePath()
        for i in 0..<sides {
            let a = CGFloat(i) / CGFloat(sides) * 2 * .pi
            let p = CGPoint(x: cos(a) * w / 2, y: sin(a) * h / 2)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return SKPhysicsBody(polygonFrom: path)
    }

    // MARK: - Drag / throw / tap (단일 터치 추적)

    /// 터치 지점의 재료 칩.
    private func chip(at p: CGPoint) -> SKSpriteNode? {
        for node in nodes(at: p) {
            guard let name = node.name else { continue }
            if name.hasPrefix("chip:"), let sprite = node as? SKSpriteNode { return sprite }
        }
        return nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard dragTouch == nil, let t = touches.first else { return }   // 이미 드래그 중이면 추가 손가락 무시
        let loc = t.location(in: self)
        guard let node = chip(at: loc) else { return }
        dragTouch = t
        dragged = node
        dragMoved = false
        dragStart = loc
        dragTarget = clampToBox(loc)
        setZones(visible: true)
        if let body = node.physicsBody {
            body.affectedByGravity = false   // 잡는 동안 중력 off → 손가락 추종(동적 유지)
            body.angularVelocity = 0
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = dragTouch, touches.contains(t), dragged != nil else { return }
        let raw = t.location(in: self)
        // 탭/드래그 판정은 시작점 기준 **누적** 이동 — 아무리 천천히 끌어도 탭으로 오판하지 않는다.
        if hypot(raw.x - dragStart.x, raw.y - dragStart.y) > 8 { dragMoved = true }
        dragTarget = clampToBox(raw)   // 상자 밖으론 못 끌게 → 새지 않음. 실제 추종은 update()의 스프링.
    }

    /// 끌고 있는 재료의 중심을 상자 내부(반지름 마진)로 제한. 화면 위로도 못 끈다.
    private func clampToBox(_ p: CGPoint) -> CGPoint {
        let r = chipSide * 0.42
        let minX = boxInset + r, maxX = max(boxInset + r, size.width - boxInset - r)
        let minY = floorY + r,   maxY = max(floorY + r, size.height - r)
        return CGPoint(x: min(max(p.x, minX), maxX), y: min(max(p.y, minY), maxY))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = dragTouch, touches.contains(t) else { return }
        defer { dragTouch = nil; dragged = nil; setZones(visible: false) }
        guard let node = dragged, let body = node.physicsBody else { return }
        body.affectedByGravity = true   // 놓으면 중력 복귀 — 현재 속도 그대로 자연스럽게 던져짐
        let cap: CGFloat = 1000
        let m = hypot(body.velocity.dx, body.velocity.dy)
        if m > cap { body.velocity = CGVector(dx: body.velocity.dx * cap / m,
                                              dy: body.velocity.dy * cap / m) }
        let id = node.name.flatMap { UUID(uuidString: String($0.dropFirst(5))) }
        // 캡처된 채 놓으면 제스처 판정 — 휴지통 = Tossed, 냄비 = Ate.
        if dragMoved, let id, let zone = captureZone(near: dragTarget) {
            onDecide?(id, zone === tossZone)
            return
        }
        if !dragMoved, let id {
            onRemove?(id)   // 짧은 탭 = 판정 묻기
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = dragTouch, touches.contains(t) else { return }
        dragged?.physicsBody?.affectedByGravity = true
        dragTouch = nil
        dragged = nil
        setZones(visible: false)
    }
}
