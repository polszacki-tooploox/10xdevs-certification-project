import Foundation

/// Semantic type of a brew step, determining timer and UI behavior.
enum StepKind: String, Codable, CaseIterable {
    /// Manual setup step (rinse filter, add grounds). No timer, manual advance.
    case preparation
    
    /// Pre-infusion pour then wait. Timer = wait duration AFTER pour complete.
    case bloom
    
    /// Active water addition. User pours to target weight BY milestone time.
    case pour
    
    /// Passive wait (e.g., drawdown). Timer = countdown duration.
    case wait
    
    /// Brief action like swirl or stir. Optional short timer, manual advance.
    case agitate
}
