import Foundation

/// Quick taste feedback tag for brew logs.
/// String-backed for CloudKit compatibility.
enum TasteTag: String, Codable, CaseIterable {
    case tooBitter = "too_bitter"
    case tooSour = "too_sour"
    case tooWeak = "too_weak"
    case tooStrong = "too_strong"
    
    var displayName: String {
        switch self {
        case .tooBitter:
            return "Too Bitter"
        case .tooSour:
            return "Too Sour"
        case .tooWeak:
            return "Too Weak"
        case .tooStrong:
            return "Too Strong"
        }
    }
    
    /// Static adjustment hint based on taste tag (per PRD 3.8.4)
    var adjustmentHint: String {
        switch self {
        case .tooSour:
            return "Try slightly finer or hotter"
        case .tooBitter:
            return "Try slightly coarser or cooler"
        case .tooWeak:
            return "Try higher dose or finer"
        case .tooStrong:
            return "Try lower dose or coarser"
        }
    }
}
