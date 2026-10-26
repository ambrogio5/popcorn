import XCTest
@testable import Popcorn

final class ArenaMappingTests: XCTestCase {
    func testPhonesAreTallAndOpenFoldablesAreWide() {
        XCTAssertEqual(LayoutMode.forSize(width: 393, height: 852), .tall)   // iPhone 17
        XCTAssertEqual(LayoutMode.forSize(width: 430, height: 932), .tall)   // iPhone Pro Max
        XCTAssertEqual(LayoutMode.forSize(width: 466, height: 678), .tall)   // Duo closed, outer display (iOS 27.1 SDK)
        XCTAssertEqual(LayoutMode.forSize(width: 951, height: 669), .wide)   // Duo open, inner display (landscape-native)
        XCTAssertEqual(LayoutMode.forSize(width: 669, height: 951), .wide)   // Duo open, turned upright
        XCTAssertEqual(LayoutMode.forSize(width: 820, height: 1180), .wide)  // iPad
        XCTAssertEqual(LayoutMode.forSize(width: 852, height: 393), .wide)   // any landscape screen
        XCTAssertTrue(LayoutMode.allowsRotation(screenWidth: 951, screenHeight: 669))
        XCTAssertFalse(LayoutMode.allowsRotation(screenWidth: 466, screenHeight: 678))
        XCTAssertFalse(LayoutMode.allowsRotation(screenWidth: 393, screenHeight: 852))
    }

    func testArenaDimensions() {
        let tall = ArenaSpec(mode: .tall)
        XCTAssertEqual(tall.width, 9)
        XCTAssertEqual(tall.height, 16)
        let wide = ArenaSpec(mode: .wide)
        XCTAssertEqual(wide.width, 16)
        XCTAssertEqual(wide.height, 12)
    }

    func testNormalizedRoundTrip() {
        let spec = ArenaSpec(mode: .wide)
        let p = spec.point(nx: 0.25, ny: 0.75)
        XCTAssertEqual(p.x, 4, accuracy: 1e-9)
        XCTAssertEqual(p.y, 9, accuracy: 1e-9)
        let n = spec.normalized(p)
        XCTAssertEqual(n.x, 0.25, accuracy: 1e-9)
        XCTAssertEqual(n.y, 0.75, accuracy: 1e-9)
    }

    func testPlatformBoxUsesTopEdge() {
        let spec = ArenaSpec(mode: .tall)
        let box = spec.platformBox(LevelPlatform(x: 0.5, y: 0.5, w: 0.25))
        XCTAssertEqual(box.minX, 4.5, accuracy: 1e-9)
        XCTAssertEqual(box.maxX, 6.75, accuracy: 1e-9)
        XCTAssertEqual(box.maxY, 8, accuracy: 1e-9)
        XCTAssertEqual(box.height, ArenaSpec.platformThickness, accuracy: 1e-9)
    }

    func testRelayoutKeepsNormalizedPositionsAndPauses() {
        let level = Level(id: 99, name: "Test", city: 0, par: 30, platforms: [], ladders: [],
                          bubbles: [LevelBubble(x: 0.25, y: 0.75, size: .medium, kind: .plain, dir: 1)])
        let model = GameModel(mode: .level(level), layout: .tall, playerCount: 1, seed: 1)
        let before = model.spec.normalized(model.bubbles[0].pos)

        model.relayout(to: .wide)

        XCTAssertEqual(model.spec.mode, .wide)
        let after = model.spec.normalized(model.bubbles[0].pos)
        XCTAssertEqual(after.x, before.x, accuracy: 1e-9)
        XCTAssertEqual(after.y, before.y, accuracy: 1e-9)
        XCTAssertGreaterThan(model.transitionPause, 0)
        XCTAssertEqual(model.players[0].pos.y, 0, accuracy: 1e-9)

        // Nothing moves during the pause.
        let frozenPos = model.bubbles[0].pos
        model.update(dt: 0.1)
        XCTAssertEqual(model.bubbles[0].pos, frozenPos)
    }

    func testRelayoutToSameModeIsNoOp() {
        let model = GameModel(mode: .storm, layout: .wide, playerCount: 2, seed: 2)
        model.relayout(to: .wide)
        XCTAssertEqual(model.transitionPause, 0)
    }

    func testGameLayoutKeepsArenaInsideScreenAboveControls() {
        let spec = ArenaSpec(mode: .tall)
        let layout = GameLayout.compute(size: CGSize(width: 393, height: 852),
                                        insets: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                                        spec: spec, playerCount: 1)
        XCTAssertGreaterThanOrEqual(layout.arenaRect.minY, layout.controlsRect.maxY)
        XCTAssertLessThanOrEqual(layout.arenaRect.maxY, layout.hudRect.minY + 0.01)
        XCTAssertGreaterThanOrEqual(layout.arenaRect.minX, 0)
        XCTAssertLessThanOrEqual(layout.arenaRect.maxX, 393)
        XCTAssertEqual(layout.arenaSize.width / layout.arenaSize.height, 9.0 / 16.0, accuracy: 1e-6)
    }
}
