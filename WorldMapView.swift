//
//  WorldMapView.swift
//  Learn
//
//  Created by Mccann Stuart on 15/02/2026.
//

import SwiftUI
import MapKit

struct WorldMapView: View {
    let visitedCountries: Set<String>
    
    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 100, longitudeDelta: 180)
    )
    private static let singleCountrySpan = MKCoordinateSpan(latitudeDelta: 25, longitudeDelta: 35)
    private static let minimumSpan = MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 20)
    
    @State private var cameraPosition: MapCameraPosition = .region(Self.defaultRegion)
    @State private var autoZoomTask: Task<Void, Never>?
    @State private var suppressAutoZoom = false
    
    var body: some View {
        ZStack {
            GeometryReader { proxy in
                if proxy.size.width > 0 && proxy.size.height > 0 {
                    // Base map
                    Map(position: $cameraPosition, interactionModes: .all) {
                        // Add annotations for visited countries
                        ForEach(Array(visitedCountries), id: \.self) { code in
                            if let coordinate = countryCoordinate(for: code) {
                                Annotation(code, coordinate: coordinate) {
                                    Circle()
                                        .fill(.blue)
                                        .frame(width: 10, height: 10)
                                        .overlay(
                                            Circle()
                                                .stroke(.white, lineWidth: 2)
                                        )
                                }
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .flat))
                    .onChange(of: cameraPosition) { _, _ in
                        scheduleAutoZoomIfNeeded()
                    }
                } else {
                    Color.clear
                }
            }
            
            // Overlay with visited countries count
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("\(visitedCountries.count) countries")
                        .font(.system(.caption, design: .rounded).bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                        .padding(8)
                }
            }
        }
        .onAppear {
            updateCamera(for: visitedCountries, animated: false)
        }
        .onChange(of: visitedCountries) { _, newValue in
            updateCamera(for: newValue, animated: true)
        }
    }
    
    private func updateCamera(for codes: Set<String>, animated: Bool) {
        suppressAutoZoom = true
        autoZoomTask?.cancel()
        let coordinates = codes.compactMap { countryCoordinate(for: $0) }
        let region: MKCoordinateRegion
        
        if coordinates.isEmpty {
            region = Self.defaultRegion
        } else if coordinates.count == 1, let coordinate = coordinates.first {
            region = MKCoordinateRegion(center: coordinate, span: Self.singleCountrySpan)
        } else {
            var minLat = 90.0
            var maxLat = -90.0
            var minLon = 180.0
            var maxLon = -180.0
            
            for coordinate in coordinates {
                minLat = min(minLat, coordinate.latitude)
                maxLat = max(maxLat, coordinate.latitude)
                minLon = min(minLon, coordinate.longitude)
                maxLon = max(maxLon, coordinate.longitude)
            }
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            let latDelta = max((maxLat - minLat) * 1.35, Self.minimumSpan.latitudeDelta)
            let lonDelta = max((maxLon - minLon) * 1.35, Self.minimumSpan.longitudeDelta)
            let span = MKCoordinateSpan(
                latitudeDelta: min(latDelta, 160),
                longitudeDelta: min(lonDelta, 360)
            )
            region = MKCoordinateRegion(center: center, span: span)
        }
        
        if animated {
            withAnimation(.easeInOut(duration: 0.6)) {
                cameraPosition = .region(region)
            }
        } else {
            cameraPosition = .region(region)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            suppressAutoZoom = false
        }
    }
    
    private func scheduleAutoZoomIfNeeded() {
        guard !suppressAutoZoom else { return }
        guard !visitedCountries.isEmpty else { return }
        
        autoZoomTask?.cancel()
        autoZoomTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            guard let visibleRegion = cameraPosition.region else { return }
            guard !areAllVisitedCountriesVisible(in: visibleRegion) else { return }
            updateCamera(for: visitedCountries, animated: true)
        }
    }
    
    private func areAllVisitedCountriesVisible(in region: MKCoordinateRegion) -> Bool {
        let coordinates = visitedCountries.compactMap { countryCoordinate(for: $0) }
        return coordinates.allSatisfy { regionContains(region, coordinate: $0) }
    }
    
    private func regionContains(_ region: MKCoordinateRegion, coordinate: CLLocationCoordinate2D) -> Bool {
        let halfLat = region.span.latitudeDelta / 2
        let minLat = region.center.latitude - halfLat
        let maxLat = region.center.latitude + halfLat
        guard coordinate.latitude >= minLat && coordinate.latitude <= maxLat else { return false }
        
        let halfLon = region.span.longitudeDelta / 2
        let minLon = region.center.longitude - halfLon
        let maxLon = region.center.longitude + halfLon
        
        if minLon < -180 || maxLon > 180 {
            let normalized = normalizeLongitude(coordinate.longitude)
            let normalizedMin = normalizeLongitude(minLon)
            let normalizedMax = normalizeLongitude(maxLon)
            
            if normalizedMin <= normalizedMax {
                return normalized >= normalizedMin && normalized <= normalizedMax
            } else {
                return normalized >= normalizedMin || normalized <= normalizedMax
            }
        } else {
            return coordinate.longitude >= minLon && coordinate.longitude <= maxLon
        }
    }
    
    private func normalizeLongitude(_ longitude: Double) -> Double {
        var value = longitude.truncatingRemainder(dividingBy: 360)
        if value < 0 { value += 360 }
        return value
    }
}

// Helper function to get approximate coordinates for country codes
private func countryCoordinate(for code: String) -> CLLocationCoordinate2D? {
    let normalized = CountryCodeNormalizer.normalize(code) ?? code.uppercased()
    let coordinates: [String: CLLocationCoordinate2D] = [
        // Schengen countries
        "AT": CLLocationCoordinate2D(latitude: 47.5162, longitude: 14.5501), // Austria
        "BE": CLLocationCoordinate2D(latitude: 50.5039, longitude: 4.4699),  // Belgium
        "CZ": CLLocationCoordinate2D(latitude: 49.8175, longitude: 15.4730), // Czechia
        "DE": CLLocationCoordinate2D(latitude: 51.1657, longitude: 10.4515), // Germany
        "DK": CLLocationCoordinate2D(latitude: 56.2639, longitude: 9.5018),  // Denmark
        "EE": CLLocationCoordinate2D(latitude: 58.5953, longitude: 25.0136), // Estonia
        "ES": CLLocationCoordinate2D(latitude: 40.4637, longitude: -3.7492), // Spain
        "FI": CLLocationCoordinate2D(latitude: 61.9241, longitude: 25.7482), // Finland
        "FR": CLLocationCoordinate2D(latitude: 46.2276, longitude: 2.2137),  // France
        "GR": CLLocationCoordinate2D(latitude: 39.0742, longitude: 21.8243), // Greece
        "HU": CLLocationCoordinate2D(latitude: 47.1625, longitude: 19.5033), // Hungary
        "IT": CLLocationCoordinate2D(latitude: 41.8719, longitude: 12.5674), // Italy
        "LV": CLLocationCoordinate2D(latitude: 56.8796, longitude: 24.6032), // Latvia
        "LI": CLLocationCoordinate2D(latitude: 47.1660, longitude: 9.5554),  // Liechtenstein
        "LT": CLLocationCoordinate2D(latitude: 55.1694, longitude: 23.8813), // Lithuania
        "LU": CLLocationCoordinate2D(latitude: 49.8153, longitude: 6.1296),  // Luxembourg
        "MT": CLLocationCoordinate2D(latitude: 35.9375, longitude: 14.3754), // Malta
        "NL": CLLocationCoordinate2D(latitude: 52.1326, longitude: 5.2913),  // Netherlands
        "NO": CLLocationCoordinate2D(latitude: 60.4720, longitude: 8.4689),  // Norway
        "PL": CLLocationCoordinate2D(latitude: 51.9194, longitude: 19.1451), // Poland
        "PT": CLLocationCoordinate2D(latitude: 39.3999, longitude: -8.2245), // Portugal
        "SE": CLLocationCoordinate2D(latitude: 60.1282, longitude: 18.6435), // Sweden
        "SI": CLLocationCoordinate2D(latitude: 46.1512, longitude: 14.9955), // Slovenia
        "SK": CLLocationCoordinate2D(latitude: 48.6690, longitude: 19.6990), // Slovakia
        "IS": CLLocationCoordinate2D(latitude: 64.9631, longitude: -19.0208),// Iceland
        "CH": CLLocationCoordinate2D(latitude: 46.8182, longitude: 8.2275),  // Switzerland
        "HR": CLLocationCoordinate2D(latitude: 45.1000, longitude: 15.2000), // Croatia
        
        // Common non-Schengen countries
        "GB": CLLocationCoordinate2D(latitude: 55.3781, longitude: -3.4360), // United Kingdom
        "US": CLLocationCoordinate2D(latitude: 37.0902, longitude: -95.7129),// United States
        "CA": CLLocationCoordinate2D(latitude: 56.1304, longitude: -106.3468),// Canada
        "AU": CLLocationCoordinate2D(latitude: -25.2744, longitude: 133.7751),// Australia
        "NZ": CLLocationCoordinate2D(latitude: -40.9006, longitude: 174.8860),// New Zealand
        "JP": CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529), // Japan
        "CN": CLLocationCoordinate2D(latitude: 35.8617, longitude: 104.1954), // China
        "IN": CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),  // India
        "BR": CLLocationCoordinate2D(latitude: -14.2350, longitude: -51.9253),// Brazil
        "ZA": CLLocationCoordinate2D(latitude: -30.5595, longitude: 22.9375), // South Africa
        "MX": CLLocationCoordinate2D(latitude: 23.6345, longitude: -102.5528),// Mexico
        "AR": CLLocationCoordinate2D(latitude: -38.4161, longitude: -63.6167),// Argentina
        "CL": CLLocationCoordinate2D(latitude: -35.6751, longitude: -71.5430),// Chile
        "CO": CLLocationCoordinate2D(latitude: 4.5709, longitude: -74.2973),  // Colombia
        "PE": CLLocationCoordinate2D(latitude: -9.1900, longitude: -75.0152), // Peru
        "TH": CLLocationCoordinate2D(latitude: 15.8700, longitude: 100.9925), // Thailand
        "VN": CLLocationCoordinate2D(latitude: 14.0583, longitude: 108.2772), // Vietnam
        "SG": CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198),  // Singapore
        "MY": CLLocationCoordinate2D(latitude: 4.2105, longitude: 101.9758),  // Malaysia
        "ID": CLLocationCoordinate2D(latitude: -0.7893, longitude: 113.9213), // Indonesia
        "PH": CLLocationCoordinate2D(latitude: 12.8797, longitude: 121.7740), // Philippines
        "KR": CLLocationCoordinate2D(latitude: 35.9078, longitude: 127.7669), // South Korea
        "TR": CLLocationCoordinate2D(latitude: 38.9637, longitude: 35.2433),  // Turkey
        "AE": CLLocationCoordinate2D(latitude: 23.4241, longitude: 53.8478),  // UAE
        "EG": CLLocationCoordinate2D(latitude: 26.8206, longitude: 30.8025),  // Egypt
        "MA": CLLocationCoordinate2D(latitude: 31.7917, longitude: -7.0926),  // Morocco
        "RU": CLLocationCoordinate2D(latitude: 61.5240, longitude: 105.3188), // Russia
        "UA": CLLocationCoordinate2D(latitude: 48.3794, longitude: 31.1656),  // Ukraine
        "IE": CLLocationCoordinate2D(latitude: 53.4129, longitude: -8.2439),  // Ireland
        "IL": CLLocationCoordinate2D(latitude: 31.0461, longitude: 34.8516),  // Israel
    ]
    
    return coordinates[normalized]
}

#Preview {
    WorldMapView(visitedCountries: ["US", "FR", "DE", "IT", "JP", "AU"])
        .frame(height: 300)
}
