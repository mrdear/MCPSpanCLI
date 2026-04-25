import ArgumentParser
import Foundation

struct MCPConfigService {
    func loadConfig(path: String) throws -> MCPSpanCLIConfig {
        let expandedPath = expand(path: path)
        let url = URL(fileURLWithPath: expandedPath)

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError(
                "Config file not found at \(url.path)"
            )
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        do {
            return try decoder.decode(MCPSpanCLIConfig.self, from: data)
        } catch {
            throw ValidationError(
                "Failed to parse config file at \(url.path): \(error.localizedDescription)"
            )
        }
    }

    func expand(path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }
}
