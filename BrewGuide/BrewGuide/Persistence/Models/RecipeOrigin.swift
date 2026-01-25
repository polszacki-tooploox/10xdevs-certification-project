import Foundation

/// Origin/type of a recipe.
/// String-backed for CloudKit compatibility.
enum RecipeOrigin: String, Codable {
    /// Recipe is a built-in starter template
    case starterTemplate = "starter_template"
    
    /// Recipe is a user-created custom recipe
    case custom = "custom"
    
    /// Recipe is a conflicted copy created during sync conflict resolution
    case conflictedCopy = "conflicted_copy"
}
