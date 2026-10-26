import XCTest
@testable import Popcorn

final class LevelLoaderTests: XCTestCase {
    private var bundle: Bundle { Bundle(for: GameViewController.self) }

    func testAllBundledLevelsAreValid() throws {
        let levels = try LevelLoader.loadLevels(from: bundle)
        XCTAssertEqual(levels.count, 64)
        XCTAssertEqual(levels.map(\.id), Array(1...64))
        try LevelLoader.validate(levels)
        XCTAssertTrue(LevelValidator.problems(in: Level.storm).isEmpty)
    }

    func testCitiesCoverEveryLevel() throws {
        let levels = try LevelLoader.loadLevels(from: bundle)
        let cities = try LevelLoader.loadCities(from: bundle)
        XCTAssertEqual(cities.count, 8)
        for level in levels {
            XCTAssertTrue(cities.indices.contains(level.city), "level \(level.id) points at a missing city")
        }
        for cityIndex in cities.indices {
            XCTAssertEqual(levels.filter { $0.city == cityIndex }.count, 8)
        }
    }

    func testValidatorCatchesUnreachablePlatform() {
        let level = Level(id: 1, name: "Bad", city: 0, par: 10,
                          platforms: [LevelPlatform(x: 0.3, y: 0.5, w: 0.4)], ladders: [],
                          bubbles: [LevelBubble(x: 0.5, y: 0.85, size: .small, kind: .plain, dir: 1)])
        XCTAssertTrue(LevelValidator.problems(in: level).contains { $0.contains("cannot be reached") })
    }

    func testValidatorCatchesBubbleInsidePlatform() {
        let level = Level(id: 1, name: "Bad", city: 0, par: 10,
                          platforms: [LevelPlatform(x: 0.2, y: 0.5, w: 0.6)],
                          ladders: [LevelLadder(x: 0.5, y0: 0, y1: 0.5)],
                          bubbles: [LevelBubble(x: 0.5, y: 0.5, size: .medium, kind: .plain, dir: 1)])
        XCTAssertTrue(LevelValidator.problems(in: level).contains { $0.contains("inside platform") })
    }

    func testDecodingRoundTrip() throws {
        let level = Level(id: 7, name: "Round trip", city: 2, par: 33,
                          platforms: [LevelPlatform(x: 0.1, y: 0.4, w: 0.3)],
                          ladders: [LevelLadder(x: 0.2, y0: 0, y1: 0.4)],
                          bubbles: [LevelBubble(x: 0.6, y: 0.8, size: .large, kind: .golden, dir: -1)])
        let data = try JSONEncoder().encode([level])
        XCTAssertEqual(try LevelLoader.decodeLevels(from: data), [level])
    }
}
