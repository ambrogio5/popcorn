import SpriteKit

/// One page per city, eight levels each. Everything is open from the start; stars just record how
/// well each level went.
final class LevelSelectScene: BaseScene {
    private let background = SKSpriteNode()
    private let content = SKNode()
    private var page: Int

    override init(size: CGSize) {
        page = min(max(Progress.shared.lastCity, 0), max(GameContent.shared.cities.count - 1, 0))
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("Not supported") }

    override func setUp() {
        background.anchorPoint = .zero
        addChild(background)
        content.zPosition = 5
        addChild(content)
    }

    override func layoutDidChange() {
        rebuild()
    }

    private func rebuild() {
        let gameContent = GameContent.shared
        let cities = gameContent.cities
        let city = cities[page]
        background.texture = TextureFactory.background(city: city, cityIndex: page, size: size)
        background.size = size
        content.removeAllChildren()

        let insets = safeInsets
        let centerX = size.width / 2
        let top = size.height - insets.top
        let wide = LayoutMode.forSize(width: size.width, height: size.height) == .wide

        let back = makeButton("‹ Menu", name: "btn.back", width: 110, height: 40, primary: false, fontSize: 16)
        back.position = CGPoint(x: insets.left + 16 + 55, y: top - 40)
        content.addChild(back)

        let totalStars = Progress.shared.totalStars(levels: gameContent.levels)
        let starsLabel = makeLabel("★ \(totalStars)", size: 18, color: Palette.star)
        starsLabel.horizontalAlignmentMode = .right
        starsLabel.position = CGPoint(x: size.width - insets.right - 20, y: top - 40)
        content.addChild(starsLabel)

        let cityLabel = makeLabel(city.name, size: wide ? 44 : 36, font: Fonts.title)
        cityLabel.position = CGPoint(x: centerX, y: top - (wide ? 110 : 120))
        content.addChild(cityLabel)

        let pageLabel = makeLabel("\(page + 1) / \(cities.count)", size: 15, color: Palette.dimText)
        pageLabel.position = CGPoint(x: centerX, y: cityLabel.position.y - 34)
        content.addChild(pageLabel)

        let prev = makeButton("‹", name: "btn.prev", width: 48, height: 48, primary: false, fontSize: 28)
        prev.position = CGPoint(x: insets.left + 44, y: cityLabel.position.y)
        prev.alpha = page > 0 ? 1 : 0.3
        content.addChild(prev)
        let next = makeButton("›", name: "btn.next", width: 48, height: 48, primary: false, fontSize: 28)
        next.position = CGPoint(x: size.width - insets.right - 44, y: cityLabel.position.y)
        next.alpha = page < cities.count - 1 ? 1 : 0.3
        content.addChild(next)

        // Level tiles
        let levels = gameContent.levels(inCity: page)
        let columns = wide ? 4 : 2
        let rows = Int(ceil(Double(levels.count) / Double(columns)))
        let gridTop = pageLabel.position.y - 40
        let gridBottom = insets.bottom + 30
        let availableW = size.width - insets.left - insets.right - 40
        let availableH = max(100, gridTop - gridBottom)
        let tileW = min(170, (availableW - CGFloat(columns - 1) * 14) / CGFloat(columns))
        let tileH = min(96, (availableH - CGFloat(max(rows - 1, 0)) * 14) / CGFloat(max(rows, 1)))
        let gridW = CGFloat(columns) * tileW + CGFloat(columns - 1) * 14
        let gridH = CGFloat(rows) * tileH + CGFloat(max(rows - 1, 0)) * 14
        let originX = centerX - gridW / 2 + tileW / 2
        let originY = gridTop - (availableH - gridH) / 2 - tileH / 2

        for (i, level) in levels.enumerated() {
            let col = i % columns
            let row = i / columns
            let tile = SKShapeNode(rectOf: CGSize(width: tileW, height: tileH), cornerRadius: 18)
            tile.fillColor = UIColor(white: 1, alpha: 0.12)
            tile.strokeColor = UIColor(hex: city.accent).withAlphaComponent(0.7)
            tile.lineWidth = 1.5
            tile.name = "btn.level.\(level.id)"
            tile.position = CGPoint(x: originX + CGFloat(col) * (tileW + 14), y: originY - CGFloat(row) * (tileH + 14))
            content.addChild(tile)

            let number = makeLabel("\(level.id)", size: tileH * 0.34, font: Fonts.title)
            number.name = tile.name
            number.position = CGPoint(x: 0, y: tileH * 0.14)
            tile.addChild(number)

            let stars = Progress.shared.stars(for: level.id)
            let starSize = tileH * 0.2
            for s in 0..<3 {
                let star = SKSpriteNode(texture: TextureFactory.star(filled: s < stars, size: starSize))
                star.size = CGSize(width: starSize, height: starSize)
                star.name = tile.name
                star.position = CGPoint(x: CGFloat(s - 1) * (starSize + 4), y: -tileH * 0.22)
                tile.addChild(star)
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let name = buttonName(at: touch.location(in: self)) else { return }
        Haptics.tap()
        SoundBank.shared.play("click", on: self)
        let cities = GameContent.shared.cities
        switch name {
        case "btn.back":
            present(MenuScene(size: size))
        case "btn.prev":
            guard page > 0 else { return }
            page -= 1
            Progress.shared.lastCity = page
            rebuild()
        case "btn.next":
            guard page < cities.count - 1 else { return }
            page += 1
            Progress.shared.lastCity = page
            rebuild()
        default:
            if name.hasPrefix("btn.level."), let id = Int(name.dropFirst("btn.level.".count)),
               let level = GameContent.shared.levels.first(where: { $0.id == id }) {
                present(GameScene(size: size, mode: .level(level), playerCount: Progress.shared.playerCount))
            }
        }
    }
}
