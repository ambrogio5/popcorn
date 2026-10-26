import Foundation

enum LevelLoaderError: Error, LocalizedError {
    case missingResource(String)
    case invalidLevels([String])

    var errorDescription: String? {
        switch self {
        case .missingResource(let name): return "Missing resource \(name)"
        case .invalidLevels(let problems): return "Invalid levels: \(problems.joined(separator: "; "))"
        }
    }
}

enum LevelLoader {
    static func decodeLevels(from data: Data) throws -> [Level] {
        try JSONDecoder().decode([Level].self, from: data)
    }

    static func decodeCities(from data: Data) throws -> [City] {
        try JSONDecoder().decode([City].self, from: data)
    }

    static func loadLevels(from bundle: Bundle = .main) throws -> [Level] {
        guard let url = bundle.url(forResource: "levels", withExtension: "json") else {
            throw LevelLoaderError.missingResource("levels.json")
        }
        return try decodeLevels(from: Data(contentsOf: url))
    }

    static func loadCities(from bundle: Bundle = .main) throws -> [City] {
        guard let url = bundle.url(forResource: "cities", withExtension: "json") else {
            throw LevelLoaderError.missingResource("cities.json")
        }
        return try decodeCities(from: Data(contentsOf: url))
    }

    /// Validates every level and throws if anything is off, so a bad content file fails loudly.
    static func validate(_ levels: [Level]) throws {
        var problems: [String] = []
        for level in levels {
            for problem in LevelValidator.problems(in: level) {
                problems.append("level \(level.id): \(problem)")
            }
        }
        if !problems.isEmpty { throw LevelLoaderError.invalidLevels(problems) }
    }
}

/// All content, loaded once. Falls back to a single built-in level if the bundle is broken, so the
/// app never shows a blank screen.
final class GameContent {
    static let shared = GameContent()

    let levels: [Level]
    let cities: [City]

    private init() {
        var loadedLevels: [Level] = []
        var loadedCities: [City] = []
        do {
            loadedLevels = try LevelLoader.loadLevels()
            loadedCities = try LevelLoader.loadCities()
        } catch {
            assertionFailure("Content failed to load: \(error)")
        }
        if loadedLevels.isEmpty {
            loadedLevels = [Level(id: 1, name: "Fallback", city: 0, par: 40, platforms: [], ladders: [],
                                  bubbles: [LevelBubble(x: 0.3, y: 0.8, size: .large, kind: .plain, dir: 1)])]
        }
        if loadedCities.isEmpty {
            loadedCities = [City(name: "Celerina", skyTop: "#1B2A4A", skyBottom: "#7FB2E5", ground: "#2E3D2F", accent: "#FFD166")]
        }
        levels = loadedLevels
        cities = loadedCities
    }

    func city(for level: Level) -> City {
        cities[min(max(level.city, 0), cities.count - 1)]
    }

    func levels(inCity city: Int) -> [Level] {
        levels.filter { $0.city == city }
    }

    func level(after level: Level) -> Level? {
        guard let i = levels.firstIndex(of: level), i + 1 < levels.count else { return nil }
        return levels[i + 1]
    }
}
