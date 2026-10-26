import XCTest
@testable import Popcorn

final class BubbleSplitTests: XCTestCase {
    /// A level with one stationary bubble straight above the single player's spawn point.
    private func level(size: BubbleSize, kind: BubbleKind, extra: [LevelBubble] = []) -> Level {
        Level(id: 99, name: "Test", city: 0, par: 30, platforms: [], ladders: [],
              bubbles: [LevelBubble(x: 0.5, y: 0.8, size: size, kind: kind, dir: 0)] + extra)
    }

    private func fireAndWait(_ model: GameModel, seconds: Double = 2.0) -> [GameEvent] {
        var events: [GameEvent] = []
        model.setInput(PlayerInput(moveX: 0, moveY: 0, fire: true), for: 0)
        model.update(dt: 1.0 / 60)
        model.setInput(PlayerInput(), for: 0)
        var t = 0.0
        while t < seconds {
            model.update(dt: 1.0 / 60)
            events += model.drainEvents()
            t += 1.0 / 60
        }
        return events
    }

    func testBubbleSizesStepDownAndTinyPops() {
        XCTAssertEqual(BubbleSize.large.smaller, .medium)
        XCTAssertEqual(BubbleSize.medium.smaller, .small)
        XCTAssertEqual(BubbleSize.small.smaller, .tiny)
        XCTAssertNil(BubbleSize.tiny.smaller)
    }

    func testHarpoonSplitsLargeBubbleIntoTwoMediums() {
        let model = GameModel(mode: .level(level(size: .large, kind: .plain)), layout: .tall, playerCount: 1, seed: 3)
        XCTAssertEqual(model.bubbles.count, 1)

        let events = fireAndWait(model, seconds: 0.8)

        XCTAssertTrue(events.contains { if case .harpoonFired = $0 { return true } else { return false } })
        XCTAssertTrue(events.contains { if case .bubbleSplit(_, .large, _, _) = $0 { return true } else { return false } })
        XCTAssertEqual(model.bubbles.count, 2)
        XCTAssertTrue(model.bubbles.allSatisfy { $0.size == .medium })
        XCTAssertLessThan(model.bubbles[0].vel.x, 0)
        XCTAssertGreaterThan(model.bubbles[1].vel.x, 0)
        XCTAssertGreaterThan(model.score, 0)
    }

    func testTripleBubbleSplitsIntoThree() {
        let model = GameModel(mode: .level(level(size: .medium, kind: .triple)), layout: .wide, playerCount: 1, seed: 4)
        _ = fireAndWait(model)
        XCTAssertEqual(model.bubbles.count, 3)
        XCTAssertTrue(model.bubbles.allSatisfy { $0.size == .small && $0.kind == .plain })
    }

    func testArmoredBubbleNeedsTwoHits() {
        let model = GameModel(mode: .level(level(size: .large, kind: .armored)), layout: .tall, playerCount: 1, seed: 5)
        let first = fireAndWait(model, seconds: 1.0)
        XCTAssertTrue(first.contains { if case .armorCracked = $0 { return true } else { return false } })
        XCTAssertEqual(model.bubbles.count, 1)
        XCTAssertEqual(model.bubbles[0].hitsLeft, 1)
    }

    func testFlippedChildrenStayFlipped() {
        let model = GameModel(mode: .level(level(size: .large, kind: .flipped)), layout: .tall, playerCount: 1, seed: 6)
        _ = fireAndWait(model)
        XCTAssertEqual(model.bubbles.count, 2)
        XCTAssertTrue(model.bubbles.allSatisfy { $0.kind == .flipped })
    }

    func testLightningChainsToNeighbours() {
        // A second tiny bubble sits within lightning range of the first one and gets hit too.
        let neighbour = LevelBubble(x: 0.5 + 2.0 / 9.0, y: 0.8, size: .tiny, kind: .plain, dir: 0)
        let model = GameModel(mode: .level(level(size: .tiny, kind: .lightning, extra: [neighbour])), layout: .tall, playerCount: 1, seed: 7)
        let events = fireAndWait(model)
        XCTAssertTrue(events.contains { if case .lightning = $0 { return true } else { return false } })
        XCTAssertTrue(model.bubbles.isEmpty)
    }

    func testPoppingTheLastBubbleClearsTheLevelWithStars() {
        let model = GameModel(mode: .level(level(size: .tiny, kind: .plain)), layout: .tall, playerCount: 1, seed: 8)
        let events = fireAndWait(model, seconds: 6.0)
        XCTAssertTrue(events.contains { if case .finalPop = $0 { return true } else { return false } })
        guard let result = events.compactMap({ event -> LevelResult? in
            if case .levelCleared(let r) = event { return r } else { return nil }
        }).first else { return XCTFail("level did not finish") }
        XCTAssertEqual(result.deaths, 0)
        XCTAssertEqual(result.stars, 3)
        XCTAssertTrue(model.isOver)
    }

    func testBubblesBounceBackToTheirApex() {
        let model = GameModel(mode: .level(level(size: .large, kind: .plain)), layout: .tall, playerCount: 1, seed: 9)
        var maxY = 0.0
        var sawFloorBounce = false
        for _ in 0..<(60 * 8) {
            model.update(dt: 1.0 / 60)
            if model.drainEvents().contains(where: { if case .bubbleBounced = $0 { return true } else { return false } }) {
                sawFloorBounce = true
            }
            if sawFloorBounce { maxY = max(maxY, model.bubbles[0].pos.y + model.bubbles[0].radius) }
        }
        XCTAssertTrue(sawFloorBounce)
        let expectedApex = BubbleSize.large.apexFraction * model.spec.height
        XCTAssertEqual(maxY, expectedApex, accuracy: 0.6)
    }

    func testPlayerHitFreezesInsteadOfResetting() {
        // Bubble resting right where the player stands, with no grace period left.
        let bubble = LevelBubble(x: 0.5, y: 1.0 / 16.0 * 1.5, size: .tiny, kind: .plain, dir: 0)
        let lvl = Level(id: 98, name: "Hit", city: 0, par: 30, platforms: [], ladders: [], bubbles: [bubble])
        let model = GameModel(mode: .level(lvl), layout: .tall, playerCount: 1, seed: 10)
        var events: [GameEvent] = []
        for _ in 0..<(60 * 3) {
            model.update(dt: 1.0 / 60)
            events += model.drainEvents()
        }
        XCTAssertTrue(events.contains { if case .playerHit = $0 { return true } else { return false } })
        XCTAssertEqual(model.deaths, 1)
        XCTAssertEqual(model.bubbles.count, 1, "the level keeps its state; nothing is reset")
        XCTAssertFalse(model.isOver)
    }
}
