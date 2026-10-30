import XCTest
@testable import Popcorn

/// A player who does nothing after the level starts, or after a knock-down, must not be hit by
/// a bubble they could not have seen coming.
final class SpawnSafetyTests: XCTestCase {
    private var bundle: Bundle { Bundle(for: GameViewController.self) }

    private func run(_ model: GameModel, until seconds: Double) -> (firstHit: Double?, hits: Int) {
        var firstHit: Double?
        var hits = 0
        while model.elapsed < seconds {
            model.update(dt: GameModel.fixedStep)
            for event in model.drainEvents() {
                if case .playerHit = event {
                    hits += 1
                    if firstHit == nil { firstHit = model.elapsed }
                }
            }
        }
        return (firstHit, hits)
    }

    /// Mirrors the `safe_start` rule in Tools/generate_levels.py against the real engine: no
    /// standing player is hit before 5 s in any shape or player count. The shield lasts 4 s, so
    /// this leaves a second to react once it drops.
    func testStandingPlayerIsSafeForFiveSecondsInEveryLevel() throws {
        let levels = try LevelLoader.loadLevels(from: bundle)
        for level in levels {
            for mode in LayoutMode.allCases {
                for players in 1...2 {
                    let model = GameModel(mode: .level(level), layout: mode, playerCount: players, seed: 1)
                    let result = run(model, until: 5.0)
                    XCTAssertNil(result.firstHit,
                                 "level \(level.id) \(level.name), \(mode.rawValue), \(players)p: hit at \(result.firstHit ?? 0) s")
                }
            }
        }
    }

    /// A tiny bubble timed to be sitting on the spawn the moment the starting shield drops: the
    /// shield stays up until the bubble has moved off instead of knocking the player down on the
    /// spot, and drops once the overlap budget is spent.
    func testShieldStaysUpWhileABubbleSitsOnTheSpawn() {
        let level = Level(id: 99, name: "Test", city: 0, par: 30, platforms: [], ladders: [],
                          bubbles: [LevelBubble(x: 0.211, y: 0.3, size: .tiny, kind: .plain, dir: 1)])
        let model = GameModel(mode: .level(level), layout: .tall, playerCount: 1, seed: 1)
        let spawn = model.players[0].box

        // Sanity: the bubble really is on the spawn box when the shield would drop.
        let probe = GameModel(mode: .level(level), layout: .tall, playerCount: 1, seed: 1)
        _ = run(probe, until: GameModel.startInvulnerability)
        XCTAssertTrue(spawn.overlapsCircle(center: probe.bubbles[0].pos, radius: probe.bubbles[0].radius))

        let result = run(model, until: 12)
        XCTAssertNotNil(result.firstHit, "the shield must drop again once the bubble has moved off")
        XCTAssertGreaterThan(result.firstHit ?? 0, GameModel.startInvulnerability + 0.1,
                             "hit the instant the shield dropped, with the bubble already on the player")
    }

    func testRespawnAndFoldShieldsAreAtLeastAsLongAsAReaction() {
        XCTAssertGreaterThanOrEqual(GameModel.respawnInvulnerability, 2.5)
        XCTAssertGreaterThanOrEqual(GameModel.foldInvulnerability, 2.5)
        XCTAssertGreaterThan(GameModel.startInvulnerability, GameModel.startGrace)
    }
}
