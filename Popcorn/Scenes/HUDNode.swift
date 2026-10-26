import SpriteKit

final class HUDNode: SKNode {
    private let titleLabel = SKLabelNode(fontNamed: Fonts.bold)
    private let subtitleLabel = SKLabelNode(fontNamed: Fonts.medium)
    private let scoreLabel = SKLabelNode(fontNamed: Fonts.title)
    private let comboLabel = SKLabelNode(fontNamed: Fonts.bold)
    private let statusLabel = SKLabelNode(fontNamed: Fonts.medium)
    private let pauseButton = SKShapeNode(circleOfRadius: 18)
    private var hearts: [SKSpriteNode] = []

    override init() {
        super.init()
        zPosition = 10
        titleLabel.fontSize = 16
        titleLabel.fontColor = Palette.text
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        addChild(titleLabel)

        subtitleLabel.fontSize = 13
        subtitleLabel.fontColor = Palette.dimText
        subtitleLabel.horizontalAlignmentMode = .left
        subtitleLabel.verticalAlignmentMode = .center
        addChild(subtitleLabel)

        scoreLabel.fontSize = 24
        scoreLabel.fontColor = Palette.text
        scoreLabel.verticalAlignmentMode = .center
        addChild(scoreLabel)

        comboLabel.fontSize = 13
        comboLabel.fontColor = Palette.star
        comboLabel.verticalAlignmentMode = .center
        addChild(comboLabel)

        statusLabel.fontSize = 12
        statusLabel.fontColor = Palette.dimText
        statusLabel.horizontalAlignmentMode = .right
        statusLabel.verticalAlignmentMode = .center
        addChild(statusLabel)

        pauseButton.fillColor = UIColor(white: 1, alpha: 0.14)
        pauseButton.strokeColor = UIColor(white: 1, alpha: 0.35)
        pauseButton.lineWidth = 1.5
        pauseButton.name = "btn.pause"
        let bars = SKShapeNode(path: {
            let p = CGMutablePath()
            p.addRect(CGRect(x: -6, y: -7, width: 4, height: 14))
            p.addRect(CGRect(x: 2, y: -7, width: 4, height: 14))
            return p
        }())
        bars.fillColor = Palette.text
        bars.strokeColor = .clear
        bars.name = "btn.pause"
        pauseButton.addChild(bars)
        addChild(pauseButton)

        for _ in 0..<3 {
            let heart = SKSpriteNode(texture: TextureFactory.heart(size: 18))
            heart.size = CGSize(width: 18, height: 18)
            heart.isHidden = true
            addChild(heart)
            hearts.append(heart)
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("Not supported") }

    func configure(title: String) {
        titleLabel.text = title
    }

    func layout(rect: CGRect) {
        titleLabel.position = CGPoint(x: rect.minX + 6, y: rect.midY + 8)
        subtitleLabel.position = CGPoint(x: rect.minX + 6, y: rect.midY - 10)
        scoreLabel.position = CGPoint(x: rect.midX, y: rect.midY + 6)
        comboLabel.position = CGPoint(x: rect.midX, y: rect.midY - 13)
        pauseButton.position = CGPoint(x: rect.maxX - 24, y: rect.midY)
        statusLabel.position = CGPoint(x: rect.maxX - 52, y: rect.midY)
        for (i, heart) in hearts.enumerated() {
            heart.position = CGPoint(x: rect.minX + 14 + CGFloat(i) * 22, y: rect.midY - 10)
        }
    }

    func update(score: Int, combo: Int, time: Double, hearts heartCount: Int?, weapon: Weapon, weaponTime: Double, shield: Bool, frozen: Double) {
        scoreLabel.text = HUDNode.formatter.string(from: NSNumber(value: score)) ?? "\(score)"
        comboLabel.text = combo > 1 ? "combo ×\(combo)" : ""
        if let heartCount = heartCount {
            subtitleLabel.text = ""
            for (i, heart) in hearts.enumerated() {
                heart.isHidden = false
                heart.alpha = i < heartCount ? 1 : 0.2
            }
        } else {
            subtitleLabel.text = String(format: "%.0fs", time)
            hearts.forEach { $0.isHidden = true }
        }
        var status: [String] = []
        switch weapon {
        case .normal: break
        case .double: status.append("Double \(Int(ceil(weaponTime)))s")
        case .sticky: status.append("Sticky \(Int(ceil(weaponTime)))s")
        case .rapid: status.append("Rapid \(Int(ceil(weaponTime)))s")
        }
        if shield { status.append("Shield") }
        if frozen > 0 { status.append("Frozen \(Int(ceil(frozen)))s") }
        statusLabel.text = status.joined(separator: " · ")
    }

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}
