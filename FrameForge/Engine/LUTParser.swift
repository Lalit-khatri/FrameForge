import Foundation
import CoreImage

struct LUTData: Codable, Identifiable {
    let id: UUID
    var name: String
    var size: Int
    var tableData: [Float]

    init(name: String, size: Int, tableData: [Float]) {
        self.id = UUID()
        self.name = name
        self.size = size
        self.tableData = tableData
    }

    static func parse(from url: URL) throws -> LUTData {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        var size = 0
        var tableData: [Float] = []
        var parsingData = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            if trimmed.hasPrefix("LUT_3D_SIZE") {
                let parts = trimmed.components(separatedBy: .whitespaces)
                if let s = parts.last.flatMap({ Int($0) }) { size = s }
                continue
            }

            if trimmed.hasPrefix("TITLE") || trimmed.hasPrefix("DOMAIN_MIN") || trimmed.hasPrefix("DOMAIN_MAX") {
                continue
            }

            let components = trimmed.components(separatedBy: .whitespaces).compactMap { Float($0) }
            if components.count == 3 {
                parsingData = true
                tableData.append(contentsOf: components)
            }
        }

        guard size > 0, tableData.count == size * size * size * 3 else {
            throw NSError(domain: "LUTParser", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid .cube file format"])
        }

        let name = url.deletingPathExtension().lastPathComponent
        return LUTData(name: name, size: size, tableData: tableData)
    }

    func createFilter() -> CIFilter? {
        let dimension = size
        let count = dimension * dimension * dimension
        var colorCubeData = [Float](repeating: 0, count: count * 4)

        for i in 0..<count {
            let baseIndex = i * 3
            guard baseIndex + 2 < tableData.count else { break }
            colorCubeData[i * 4 + 0] = tableData[baseIndex]
            colorCubeData[i * 4 + 1] = tableData[baseIndex + 1]
            colorCubeData[i * 4 + 2] = tableData[baseIndex + 2]
            colorCubeData[i * 4 + 3] = 1.0
        }

        let data = Data(bytes: colorCubeData, count: colorCubeData.count * MemoryLayout<Float>.size)
        let filter = CIFilter(name: "CIColorCubeWithColorSpace")
        filter?.setValue(dimension, forKey: "inputCubeDimension")
        filter?.setValue(data, forKey: "inputCubeData")
        filter?.setValue(CGColorSpaceCreateDeviceRGB(), forKey: "inputColorSpace")
        return filter
    }
}
