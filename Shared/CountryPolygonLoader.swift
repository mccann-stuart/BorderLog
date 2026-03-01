//
//  CountryPolygonLoader.swift
//  BorderLog
//

import CoreLocation
import Foundation
import Combine
import zlib

/// Simple GeoJSON models
nonisolated private struct FeatureCollection: Decodable {
    let features: [Feature]
}

nonisolated private struct Feature: Decodable {
    let id: String?
    let geometry: Geometry
}

nonisolated private struct Geometry: Decodable {
    let type: String
    let coordinates: AnyCodableCoordinates
}

nonisolated private struct AnyCodableCoordinates: Decodable {
    var rawPolygons: [[[[Double]]]] = []

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Polygons are [[[Double]]] (array of linear rings, each an array of line points)
        // MultiPolygons are [[[[Double]]]] (array of Polygons)

        if let multi = try? container.decode([[[[Double]]]].self) {
            self.rawPolygons = multi
        } else if let single = try? container.decode([[[Double]]].self) {
            self.rawPolygons = [single]
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid geometry coordinates")
        }
    }
}

@MainActor
final class CountryPolygonLoader: ObservableObject {
    static let shared = CountryPolygonLoader()

    @Published private(set) var isLoaded = false
    private var coordinatesByCountryCode: [String: [[[CLLocationCoordinate2D]]]] = [:]

    private init() {}

    func getPolygons(for displayCodes: Set<String>) -> [String: [[[CLLocationCoordinate2D]]]] {
        if !isLoaded {
            loadPolygons()
        }

        var result: [String: [[[CLLocationCoordinate2D]]]] = [:]
        for code in displayCodes {
            let normalized = CountryCodeNormalizer.normalize(code) ?? code.uppercased()
            if let polys = coordinatesByCountryCode[normalized] {
                result[normalized] = polys
            }
        }
        return result
    }

    private func loadPolygons() {
        guard !isLoaded else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let b64 = CountryPolygonsData.base64CompressedGeoJSON
            guard let compressedData = Data(base64Encoded: b64) else { return }

            // Simple zlib decompression
            guard let jsonData = try? compressedData.decompressZlib() else { return }

            guard let collection = try? JSONDecoder().decode(FeatureCollection.self, from: jsonData) else { return }

            var parsed: [String: [[[CLLocationCoordinate2D]]]] = [:]

            for feature in collection.features {
                guard let alpha3 = feature.id,
                      let alpha2 = alpha3ToAlpha2[alpha3] else { continue }

                var countryPolygons: [[[CLLocationCoordinate2D]]] = []
                for polygon in feature.geometry.coordinates.rawPolygons {
                    var rings: [[CLLocationCoordinate2D]] = []
                    for ring in polygon {
                        let coords = ring.compactMap { point -> CLLocationCoordinate2D? in
                            guard point.count >= 2 else { return nil }
                            return CLLocationCoordinate2D(latitude: point[1], longitude: point[0])
                        }
                        rings.append(coords)
                    }
                    countryPolygons.append(rings)
                }

                parsed[alpha2] = countryPolygons
            }

            DispatchQueue.main.async {
                self.coordinatesByCountryCode = parsed
                self.isLoaded = true
            }
        }
    }

}

private let alpha3ToAlpha2: [String: String] = [
        "AFG": "AF", "ALA": "AX", "ALB": "AL", "DZA": "DZ", "ASM": "AS",
        "AND": "AD", "AGO": "AO", "AIA": "AI", "ATA": "AQ", "ATG": "AG",
        "ARG": "AR", "ARM": "AM", "ABW": "AW", "AUS": "AU", "AUT": "AT",
        "AZE": "AZ", "BHS": "BS", "BHR": "BH", "BGD": "BD", "BRB": "BB",
        "BLR": "BY", "BEL": "BE", "BLZ": "BZ", "BEN": "BJ", "BMU": "BM",
        "BTN": "BT", "BOL": "BO", "BES": "BQ", "BIH": "BA", "BWA": "BW",
        "BVT": "BV", "BRA": "BR", "IOT": "IO", "BRN": "BN", "BGR": "BG",
        "BFA": "BF", "BDI": "BI", "CPV": "CV", "KHM": "KH", "CMR": "CM",
        "CAN": "CA", "CYM": "KY", "CAF": "CF", "TCD": "TD", "CHL": "CL",
        "CHN": "CN", "CXR": "CX", "CCK": "CC", "COL": "CO", "COM": "KM",
        "COG": "CG", "COD": "CD", "COK": "CK", "CRI": "CR", "CIV": "CI",
        "HRV": "HR", "CUB": "CU", "CUW": "CW", "CYP": "CY", "CZE": "CZ",
        "DNK": "DK", "DJI": "DJ", "DMA": "DM", "DOM": "DO", "ECU": "EC",
        "EGY": "EG", "SLV": "SV", "GNQ": "GQ", "ERI": "ER", "EST": "EE",
        "SWZ": "SZ", "ETH": "ET", "FLK": "FK", "FRO": "FO", "FJI": "FJ",
        "FIN": "FI", "FRA": "FR", "GUF": "GF", "PYF": "PF", "ATF": "TF",
        "GAB": "GA", "GMB": "GM", "GEO": "GE", "DEU": "DE", "GHA": "GH",
        "GIB": "GI", "GRC": "GR", "GRL": "GL", "GRD": "GD", "GLP": "GP",
        "GUM": "GU", "GTM": "GT", "GGY": "GG", "GIN": "GN", "GNB": "GW",
        "GUY": "GY", "HTI": "HT", "HMD": "HM", "VAT": "VA", "HND": "HN",
        "HKG": "HK", "HUN": "HU", "ISL": "IS", "IND": "IN", "IDN": "ID",
        "IRN": "IR", "IRQ": "IQ", "IRL": "IE", "IMN": "IM", "ISR": "IL",
        "ITA": "IT", "JAM": "JM", "JPN": "JP", "JEY": "JE", "JOR": "JO",
        "KAZ": "KZ", "KEN": "KE", "KIR": "KI", "PRK": "KP", "KOR": "KR",
        "KWT": "KW", "KGZ": "KG", "LAO": "LA", "LVA": "LV", "LBN": "LB",
        "LSO": "LS", "LBR": "LR", "LBY": "LY", "LIE": "LI", "LTU": "LT",
        "LUX": "LU", "MAC": "MO", "MDG": "MG", "MWI": "MW", "MYS": "MY",
        "MDV": "MV", "MLI": "ML", "MLT": "MT", "MHL": "MH", "MTQ": "MQ",
        "MRT": "MR", "MUS": "MU", "MYT": "YT", "MEX": "MX", "FSM": "FM",
        "MDA": "MD", "MCO": "MC", "MNG": "MN", "MNE": "ME", "MSR": "MS",
        "MAR": "MA", "MOZ": "MZ", "MMR": "MM", "NAM": "NA", "NRU": "NR",
        "NPL": "NP", "NLD": "NL", "NCL": "NC", "NZL": "NZ", "NIC": "NI",
        "NER": "NE", "NGA": "NG", "NIU": "NU", "NFK": "NF", "MKD": "MK",
        "MNP": "MP", "NOR": "NO", "OMN": "OM", "PAK": "PK", "PLW": "PW",
        "PSE": "PS", "PAN": "PA", "PNG": "PG", "PRY": "PY", "PER": "PE",
        "PHL": "PH", "PCN": "PN", "POL": "PL", "PRT": "PT", "PRI": "PR",
        "QAT": "QA", "REU": "RE", "ROU": "RO", "RUS": "RU", "RWA": "RW",
        "BLM": "BL", "SHN": "SH", "KNA": "KN", "LCA": "LC", "MAF": "MF",
        "SPM": "PM", "VCT": "VC", "WSM": "WS", "SMR": "SM", "STP": "ST",
        "SAU": "SA", "SEN": "SN", "SRB": "RS", "SYC": "SC", "SLE": "SL",
        "SGP": "SG", "SXM": "SX", "SVK": "SK", "SVN": "SI", "SLB": "SB",
        "SOM": "SO", "ZAF": "ZA", "SGS": "GS", "SSD": "SS", "ESP": "ES",
        "LKA": "LK", "SDN": "SD", "SUR": "SR", "SJM": "SJ", "SWE": "SE",
        "CHE": "CH", "SYR": "SY", "TWN": "TW", "TJK": "TJ", "TZA": "TZ",
        "THA": "TH", "TLS": "TL", "TGO": "TG", "TKL": "TK", "TON": "TO",
        "TTO": "TT", "TUN": "TN", "TUR": "TR", "TKM": "TM", "TCA": "TC",
        "TUV": "TV", "UGA": "UG", "UKR": "UA", "ARE": "AE", "GBR": "GB",
        "USA": "US", "UMI": "UM", "URY": "UY", "UZB": "UZ", "VUT": "VU",
        "VEN": "VE", "VNM": "VN", "VGB": "VG", "VIR": "VI", "WLF": "WF",
        "ESH": "EH", "YEM": "YE", "ZMB": "ZM", "ZWE": "ZW",
    ]

extension Data {
    func decompressZlib() throws -> Data {
        let size = 8_000_000 // 8MB should be enough for minified world geojson
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { buffer.deallocate() }

        let decodedSize = try self.withUnsafeBytes { ptr -> Int in
            var stream = z_stream()
            stream.next_in = UnsafeMutablePointer(mutating: ptr.bindMemory(to: UInt8.self).baseAddress!)
            stream.avail_in = UInt32(self.count)
            stream.next_out = buffer
            stream.avail_out = UInt32(size)

            var status = inflateInit_(&stream, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
            guard status == Z_OK else { throw NSError(domain: "Zlib", code: Int(status)) }
            defer { inflateEnd(&stream) }

            status = inflate(&stream, Z_FINISH)
            guard status == Z_STREAM_END || status == Z_OK else { throw NSError(domain: "Zlib", code: Int(status)) }

            return size - Int(stream.avail_out)
        }

        return Data(bytes: buffer, count: decodedSize)
    }
}
