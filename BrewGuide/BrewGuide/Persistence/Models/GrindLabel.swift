import Foundation

/// Grind size label for recipes and brew logs.
/// String-backed for CloudKit compatibility.
enum GrindLabel: String, Codable, CaseIterable {
    case fine = "fine"
    case medium = "medium"
    case coarse = "coarse"
    
    var displayName: String {
        rawValue.capitalized
    }
}
