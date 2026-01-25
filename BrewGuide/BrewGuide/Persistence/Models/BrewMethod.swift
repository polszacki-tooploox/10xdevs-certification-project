import Foundation

/// Brew method supported by the app.
/// String-backed for CloudKit compatibility and forward compatibility.
enum BrewMethod: String, Codable, CaseIterable {
    case v60 = "v60"
    
    var displayName: String {
        switch self {
        case .v60:
            return "V60"
        }
    }
}
