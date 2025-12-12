import SwiftUI

struct CharterFormState {
    var name: String = ""
    var startDate: Date = Date()
    var endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    var destination: String = ""
    var region: String = regionOptions.first?.name ?? ""
    var vessel: String = vesselOptions.first?.name ?? ""
    var guests: Int = 6
    var captainIncluded: Bool = true
    var chefIncluded: Bool = false
    var deckhandIncluded: Bool = false
    var budget: Double = 0
    var notes: String = ""
    
    var nights: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
    
    var crewSummary: String {
        var roles: [String] = []
        if captainIncluded { roles.append("Captain") }
        if chefIncluded { roles.append("Chef") }
        if deckhandIncluded { roles.append("Deckhand") }
        return roles.isEmpty ? "Crew TBD" : roles.joined(separator: " • ")
    }
    
    var dateSummary: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate)
        return "\(start) – \(end)"
    }
    
    var regionDetails: String? {
        CharterFormState.regionOptions.first(where: { $0.name == region })?.description
    }
    
    struct Region: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let subregions: String
        let description: String
        let colors: [Color]
    }
    
    static let regionOptions: [Region] = [
        Region(
            name: "Mediterranean",
            icon: "🌊",
            subregions: "Aegean, Ionian, Cyclades",
            description: "Calm summers, protected anchorages, postcard villages.",
            colors: [Color(red: 0.09, green: 0.44, blue: 0.64), Color(red: 0.0, green: 0.3, blue: 0.46)]
        ),
        Region(
            name: "Caribbean",
            icon: "🏝️",
            subregions: "Grenadines, BVI, USVI",
            description: "Trade winds, warm water, and island hopping ease.",
            colors: [Color(red: 0.0, green: 0.6, blue: 0.55), Color(red: 0.0, green: 0.45, blue: 0.35)]
        ),
        Region(
            name: "Baltic",
            icon: "⚓️",
            subregions: "Stockholm, Helsinki, Tallinn",
            description: "Historic harbors and long summer days.",
            colors: [Color(red: 0.21, green: 0.27, blue: 0.38), Color(red: 0.1, green: 0.16, blue: 0.27)]
        ),
        Region(
            name: "Southeast Asia",
            icon: "🌅",
            subregions: "Phuket, Langkawi",
            description: "Limestone cliffs, warm seas, year-round adventure.",
            colors: [Color(red: 0.93, green: 0.5, blue: 0.26), Color(red: 0.8, green: 0.3, blue: 0.2)]
        ),
        Region(
            name: "Pacific Northwest",
            icon: "🌲",
            subregions: "San Juans, Desolation Sound",
            description: "Quiet coves, wildlife, and dramatic coastlines.",
            colors: [Color(red: 0.12, green: 0.35, blue: 0.28), Color(red: 0.05, green: 0.2, blue: 0.18)]
        )
    ]
    
    struct Vessel: Identifiable {
        let id = UUID()
        let name: String
        let length: Int
        let berths: Int
        let rating: Int
        let pricePerNight: Double
        let highlights: [String]
        let colors: [Color]
    }
    
    static let vesselOptions: [Vessel] = [
        Vessel(
            name: "44ft Catamaran",
            length: 44,
            berths: 8,
            rating: 5,
            pricePerNight: 2800,
            highlights: ["Spacious flybridge", "Great for families", "Stable at anchor"],
            colors: [Color(red: 0.16, green: 0.45, blue: 0.58), Color(red: 0.08, green: 0.32, blue: 0.46)]
        ),
        Vessel(
            name: "38ft Monohull",
            length: 38,
            berths: 6,
            rating: 4,
            pricePerNight: 1900,
            highlights: ["Classic sailing feel", "Easy to handle", "Shallow draft"],
            colors: [Color(red: 0.25, green: 0.28, blue: 0.36), Color(red: 0.16, green: 0.2, blue: 0.3)]
        ),
        Vessel(
            name: "50ft Motor Yacht",
            length: 50,
            berths: 6,
            rating: 5,
            pricePerNight: 4200,
            highlights: ["Fast passages", "Lux interior", "Crewed experience"],
            colors: [Color(red: 0.38, green: 0.31, blue: 0.48), Color(red: 0.22, green: 0.18, blue: 0.32)]
        )
    ]
    
    static var mock: CharterFormState {
        var state = CharterFormState()
        state.name = "Summer Escape 2025"
        state.region = "Mediterranean"
        state.vessel = "44ft Catamaran"
        state.guests = 6
        state.captainIncluded = true
        state.chefIncluded = true
        state.budget = 24000
        state.notes = "Include snorkeling gear and child life vests."
        return state
    }
}

