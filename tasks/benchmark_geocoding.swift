
import Foundation

// Mocks
struct MockLocation: Sendable {
    let coordinate: (latitude: Double, longitude: Double)
}

struct MockAsset: Sendable {
    let creationDate: Date
    let location: MockLocation
    let id: Int
}

struct CountryResolution: Sendable {
    let countryCode: String?
    let timeZone: TimeZone?
}

protocol CountryResolving: Sendable {
    func resolveCountry(for location: MockLocation) async -> CountryResolution?
}

actor MockResolver: CountryResolving {
    func resolveCountry(for location: MockLocation) async -> CountryResolution? {
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        return CountryResolution(countryCode: "US", timeZone: TimeZone(identifier: "America/New_York"))
    }
}

// DayKey mock
enum DayKey {
    static func make(from date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}

// Result struct to carry data out of the concurrent task
struct IngestResult: Sendable {
    let index: Int
    let creationDate: Date
    let dayKey: String
    let resolution: CountryResolution?
}

// Optimized Implementation
func runConcurrent(assets: [MockAsset], resolver: CountryResolving) async {
    print("Starting Concurrent (Batched)...")
    let start = Date()

    let batchSize = 5
    var processedCount = 0

    // Process in batches
    for i in stride(from: 0, to: assets.count, by: batchSize) {
        let end = min(i + batchSize, assets.count)
        let chunkIndices = i..<end

        // Use TaskGroup to process the chunk concurrently
        await withTaskGroup(of: IngestResult?.self) { group in
            for index in chunkIndices {
                let asset = assets[index]
                group.addTask {
                    // Perform heavy I/O
                    let resolution = await resolver.resolveCountry(for: asset.location)
                    let timeZone = resolution?.timeZone ?? TimeZone.current
                    let dayKey = DayKey.make(from: asset.creationDate, timeZone: timeZone)

                    return IngestResult(
                        index: index,
                        creationDate: asset.creationDate,
                        dayKey: dayKey,
                        resolution: resolution
                    )
                }
            }

            // Collect results
            var results: [IngestResult] = []
            for await result in group {
                if let res = result {
                    results.append(res)
                }
            }

            // Sort to maintain original order (important for state updates)
            results.sort { $0.index < $1.index }

            // Process results serially (simulating actor context)
            for res in results {
                // strict ordering achieved
                // modelContext.insert(...)
                // state.update(...)
                _ = res
            }

            processedCount += results.count
        }
    }

    let duration = Date().timeIntervalSince(start)
    print("Concurrent finished in \(String(format: "%.3f", duration))s")
}

// Sequential Implementation
func runSequential(assets: [MockAsset], resolver: CountryResolving) async {
    print("Starting Sequential...")
    let start = Date()

    for (index, asset) in assets.enumerated() {
        let resolution = await resolver.resolveCountry(for: asset.location)
        let timeZone = resolution?.timeZone ?? TimeZone.current
        let dayKey = DayKey.make(from: asset.creationDate, timeZone: timeZone)

        let res = IngestResult(
            index: index,
            creationDate: asset.creationDate,
            dayKey: dayKey,
            resolution: resolution
        )
        _ = res
    }

    let duration = Date().timeIntervalSince(start)
    print("Sequential finished in \(String(format: "%.3f", duration))s")
}


@main
struct Benchmark {
    static func main() async {
        let assetCount = 20
        print("Benchmarking with \(assetCount) assets...")

        let assets = (0..<assetCount).map { i in
            MockAsset(
                creationDate: Date(),
                location: MockLocation(coordinate: (0, 0)),
                id: i
            )
        }

        let resolver = MockResolver()

        await runSequential(assets: assets, resolver: resolver)
        await runConcurrent(assets: assets, resolver: resolver)
    }
}
