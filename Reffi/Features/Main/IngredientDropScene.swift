import SpriteKit
import SwiftUI

/// 재료 낙하 씬(§13) — **진짜 물리 엔진**(SpriteKit, 레퍼런스 École Vision의 gravity-based). 재료가 위에서
/// 떨어져 충돌·바운스하며 **쌓여서 그대로 남는다**(사라지지 않음). 끌어서 던질 수 있고, 짧게 탭하면 끄기/켜기.
/// 비활성은 깔끔한 알파 페이드. 바닥은 씬 하단보다 위(요리시작 버튼 충돌 마진).
final class IngredientDropScene: SKScene {
    /// 이름 라벨 하나의 레이아웃(뷰 좌표 y-down).
    struct LabelInfo: Identifiable { let id: UUID; let name: String; let fresh: Freshness; let pos: CGPoint; let alpha: CGFloat }

    private var nodes: [UUID: SKSpriteNode] = [:]
    private var names: [UUID: String] = [:]
    private var freshes: [UUID: Freshness] = [:]
    private var textureCache: [String: SKTexture] = [:]
    private var pending: [Ingredient] = []

    private var dragged: SKNode?
    private var dragMoved = false
    private var lastTouch: CGPoint = .zero
    private var lastTime: TimeInterval = 0
    private var throwV: CGVector = .zero

    /// 짧은 탭 = 제거(뿅 사라짐).
    var onRemove: ((UUID) -> Void)?
    var onLayout: (([LabelInfo]) -> Void)?
    var reduceMotion = false

    private var chipSide: CGFloat { min(max(124, size.width * 0.42), 188) }
    private var floorY: CGFloat { max(6, size.height * 0.03) }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -26)   // 묵직하게(빠르게 떨어져 쿵)
        buildWalls()
        sync(pending)
    }

    /// 매 프레임 라벨 위치를 뷰 좌표로 변환해 SwiftUI 오버레이로 보낸다(재료 위에 작은 이름).
    override func update(_ currentTime: TimeInterval) {
        guard let onLayout else { return }
        let off = chipSide * 0.42 + 8
        var out: [LabelInfo] = []
        for (id, node) in nodes {
            guard let name = names[id] else { continue }
            let vy = size.height - (node.position.y + off)
            out.append(LabelInfo(id: id, name: name, fresh: freshes[id] ?? .fresh,
                                 pos: CGPoint(x: node.position.x, y: vy), alpha: node.alpha))
        }
        onLayout(out)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 1 else { return }
        buildWalls()
    }

    private func buildWalls() {
        guard size.width > 1, size.height > 1 else { return }
        childNode(withName: "walls")?.removeFromParent()
        let inset: CGFloat = 2
        let p = CGMutablePath()
        p.move(to: CGPoint(x: inset, y: size.height + 320))            // 좌 벽(위로 연장)
        p.addLine(to: CGPoint(x: inset, y: floorY))
        p.addLine(to: CGPoint(x: size.width - inset, y: floorY))       // 바닥
        p.addLine(to: CGPoint(x: size.width - inset, y: size.height + 320)) // 우 벽
        let walls = SKNode()
        walls.name = "walls"
        walls.physicsBody = SKPhysicsBody(edgeChainFrom: p)
        walls.physicsBody?.friction = 0.7
        addChild(walls)
    }

    private func texture(for ing: Ingredient, side: CGFloat) -> SKTexture? {
        let key = "\(ing.glyph)"   // 자연색이라 신선도와 무관
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
        for (id, node) in nodes where !ids.contains(id) {
            nodes[id] = nil; names[id] = nil; freshes[id] = nil
            popOut(node)
        }
        for (i, ing) in ingredients.enumerated() where nodes[ing.id] == nil {
            addChip(ing, order: i, count: ingredients.count)
        }
    }

    /// 제거 연출 — 살짝 커졌다(easeOut) → 뿅 줄며 사라짐(easeIn) → removeFromParent.
    private func popOut(_ node: SKSpriteNode) {
        node.physicsBody = nil   // 물리 정지(라벨/충돌에서 제외)
        node.zPosition = 50
        let grow = SKAction.scale(to: node.xScale * 1.25, duration: 0.13); grow.timingMode = .easeOut
        let pop = SKAction.scale(to: 0.0, duration: 0.17); pop.timingMode = .easeIn
        let fade = SKAction.fadeOut(withDuration: 0.17)
        node.run(.sequence([grow, .group([pop, fade]), .removeFromParent()]))
    }

    private func addChip(_ ing: Ingredient, order: Int, count: Int) {
        let s = chipSide
        let node: SKSpriteNode
        if let tex = texture(for: ing, side: s) {
            node = SKSpriteNode(texture: tex, size: CGSize(width: s, height: s))
            node.physicsBody = SKPhysicsBody(texture: tex, alphaThreshold: 0.5,
                                             size: CGSize(width: s, height: s))
        } else {
            node = SKSpriteNode(color: UIColor(ing.freshness.main), size: CGSize(width: s, height: s))
            node.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: s * 0.7, height: s * 0.7))
        }
        node.name = "chip:\(ing.id.uuidString)"
        names[ing.id] = ing.name
        freshes[ing.id] = ing.freshness
        let body = node.physicsBody!
        body.restitution = 0.12          // 거의 안 튐 — 묵직하게
        body.friction = 0.85
        body.linearDamping = 0.5
        body.angularDamping = 0.85
        body.allowsRotation = true
        body.mass = 1.0                  // 무겁게

        let margin = s * 0.6
        let usable = max(1, size.width - margin * 2)
        let frac = count <= 1 ? 0.5 : CGFloat(order) / CGFloat(count - 1)
        let x = margin + usable * frac + CGFloat((order % 3) - 1) * s * 0.08
        node.zRotation = (order % 2 == 0) ? 0.18 : -0.22
        if reduceMotion {
            node.position = CGPoint(x: x, y: floorY + s * 0.5 + CGFloat(order % 3) * s * 0.4)
        } else {
            node.position = CGPoint(x: x, y: size.height + s * (0.5 + CGFloat(order) * 0.5))  // 위에서 스태거 낙하
        }
        addChild(node)
        nodes[ing.id] = node
    }

    // MARK: - Drag / throw / tap

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let loc = t.location(in: self)
        for node in nodes(at: loc) where node.name?.hasPrefix("chip:") == true {
            dragged = node; dragMoved = false; throwV = .zero
            lastTouch = loc; lastTime = t.timestamp
            node.physicsBody?.isDynamic = false   // 끄는 동안 손가락 따라오게
            return
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let node = dragged else { return }
        let loc = t.location(in: self)
        let dt = t.timestamp - lastTime
        if hypot(loc.x - lastTouch.x, loc.y - lastTouch.y) > 3 { dragMoved = true }
        if dt > 0 { throwV = CGVector(dx: (loc.x - lastTouch.x) / CGFloat(dt),
                                      dy: (loc.y - lastTouch.y) / CGFloat(dt)) }
        node.position = loc
        lastTouch = loc; lastTime = t.timestamp
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let node = dragged else { return }
        node.physicsBody?.isDynamic = true
        if dragMoved {
            node.physicsBody?.velocity = CGVector(dx: max(-1400, min(1400, throwV.dx)),
                                                  dy: max(-1400, min(1400, throwV.dy)))   // 던지기
        } else if let name = node.name, let id = UUID(uuidString: String(name.dropFirst(5))) {
            onRemove?(id)   // 짧은 탭 = 제거
        }
        dragged = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        dragged?.physicsBody?.isDynamic = true
        dragged = nil
    }
}
