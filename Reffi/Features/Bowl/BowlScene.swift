import SpriteKit
import SwiftUI

/// 보울 물리 씬 — 각 재료가 제 일러스트(FoodMotif)대로 정사각 글래스 보울 안으로 떨어져 쌓인다.
/// 일러스트를 텍스처로 렌더 → SKSpriteNode + 알파 기반 물리 바디(충돌=그림 외형).
/// **이름 라벨은 씬이 아니라 SwiftUI 오버레이**(글래스 위 최상단, 안 흐려짐)로 그리도록 위치만 콜백한다.
final class BowlScene: SKScene {
    /// 라벨 1개의 레이아웃(뷰 좌표 y-down).
    struct LabelLayout: Identifiable { let id: UUID; let name: String; let pos: CGPoint; let alpha: CGFloat }

    private var nodes: [UUID: SKSpriteNode] = [:]
    private var names: [UUID: String] = [:]
    private var textureCache: [FoodGlyph: SKTexture] = [:]
    private var pending: [Ingredient] = []
    private var disabledIDs: Set<UUID> = []

    var onToggle: ((UUID) -> Void)?
    var onLayout: (([LabelLayout]) -> Void)?

    /// 노드 크기 — FoodMotif는 프레임의 ~65%만 채우므로 크게 잡아야 일러스트가 또렷하고 보울 위로 솟는다.
    private var blockSide: CGFloat { max(96, size.width * 0.40) }   // 크게 — 또렷이 보이게
    private var wallInset: CGFloat { max(3, size.width * 0.012) }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -11)
        rebuild()
        sync(pending, disabled: disabledIDs, animated: false)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 1 else { return }
        rebuild()
        sync(pending, disabled: disabledIDs, animated: false)
    }

    private func rebuild() {
        guard size.width > 1, size.height > 1 else { return }
        childNode(withName: "bowl")?.removeFromParent()
        let bowl = SKNode()
        bowl.name = "bowl"
        bowl.physicsBody = SKPhysicsBody(edgeChainFrom: BowlGeometry.physicsPath(size: size, inset: wallInset))
        bowl.physicsBody?.friction = 0.9
        addChild(bowl)
    }

    /// 매 프레임 라벨 위치를 뷰 좌표(y-down)로 변환해 SwiftUI 오버레이로 보낸다(글래스 위 또렷).
    override func update(_ currentTime: TimeInterval) {
        guard let onLayout else { return }
        let off = blockSide * 0.34 + 4
        var out: [LabelLayout] = []
        for (id, node) in nodes {
            guard let name = names[id] else { continue }
            let pos = CGPoint(x: node.position.x, y: size.height - (node.position.y + off))
            out.append(LabelLayout(id: id, name: name, pos: pos, alpha: node.alpha))
        }
        onLayout(out)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let loc = touches.first?.location(in: self) else { return }
        for node in self.nodes(at: loc) where node.name?.hasPrefix("blob:") == true {
            if let id = UUID(uuidString: String(node.name!.dropFirst(5))) { onToggle?(id) }
            return
        }
    }

    func sync(_ ingredients: [Ingredient], disabled: Set<UUID>, animated: Bool = true) {
        pending = ingredients
        disabledIDs = disabled
        guard size.width > 1 else { return }
        let ids = Set(ingredients.map(\.id))
        for (id, node) in nodes where !ids.contains(id) {
            node.removeFromParent(); nodes[id] = nil; names[id] = nil
        }
        for (i, ing) in ingredients.enumerated() where nodes[ing.id] == nil {
            addBlock(ing, order: i, count: ingredients.count)
        }
        for (id, node) in nodes {
            node.run(.fadeAlpha(to: disabled.contains(id) ? 0.3 : 1, duration: 0.18))
        }
    }

    /// 글리프 일러스트를 텍스처로 렌더(캐시). SpriteKit 콜백·SwiftUI 모두 메인에서 호출됨.
    private func texture(_ g: FoodGlyph, side: CGFloat) -> SKTexture? {
        if let t = textureCache[g] { return t }
        let renderer = ImageRenderer(content: FoodMotif(glyph: g).frame(width: side, height: side))
        renderer.scale = 3
        guard let img = renderer.uiImage else { return nil }
        let t = SKTexture(image: img)
        textureCache[g] = t
        return t
    }

    private func addBlock(_ ing: Ingredient, order: Int, count: Int) {
        let s = blockSide
        let node: SKSpriteNode
        if let tex = texture(ing.glyph, side: s) {
            node = SKSpriteNode(texture: tex, size: CGSize(width: s, height: s))
            node.physicsBody = SKPhysicsBody(texture: tex, size: CGSize(width: s, height: s))
        } else {
            node = SKSpriteNode(color: UIColor(ing.freshness.main), size: CGSize(width: s, height: s))
            node.physicsBody = SKPhysicsBody(circleOfRadius: s * 0.4)
        }
        node.name = "blob:\(ing.id.uuidString)"
        let body = node.physicsBody!
        body.restitution = 0.02
        body.friction = 0.95
        body.linearDamping = 0.7
        body.angularDamping = 0.85
        body.allowsRotation = true

        // 보울 림 안에서 좌우로 살짝 흩어 떨어뜨려 가운데로 모여 쌓이게(가운데가 보울 윗변 위로 솟음).
        let span = BowlGeometry.dropSpan(size.width)
        let frac = count <= 1 ? 0.5 : CGFloat(order) / CGFloat(count - 1)
        let x = size.width * 0.5 + (frac - 0.5) * span
        let jitter = CGFloat((order % 3) - 1) * s * 0.09
        node.zRotation = CGFloat((order % 2 == 0) ? 0.18 : -0.22)
        node.position = CGPoint(x: x + jitter, y: size.height * (1.05 + CGFloat(order) * 0.16))
        addChild(node)
        nodes[ing.id] = node
        names[ing.id] = ing.name
    }
}
