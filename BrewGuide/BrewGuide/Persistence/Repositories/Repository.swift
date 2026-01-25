import Foundation
import SwiftData

/// Protocol defining common repository operations for SwiftData entities.
/// Repositories abstract persistence layer from Domain and UI layers.
protocol Repository {
    associatedtype Entity
    
    /// Fetch all entities matching optional predicate
    func fetchAll(matching predicate: Predicate<Entity>?) async throws -> [Entity]
    
    /// Fetch a single entity by ID
    func fetch(byId id: UUID) async throws -> Entity?
    
    /// Insert a new entity
    func insert(_ entity: Entity) async throws
    
    /// Update an existing entity
    func update(_ entity: Entity) async throws
    
    /// Delete an entity
    func delete(_ entity: Entity) async throws
    
    /// Save changes to the context
    func save() async throws
}

/// Base implementation for SwiftData repositories using ModelContext.
@MainActor
class BaseRepository<T: PersistentModel> {
    /// The model context for persistence operations
    let context: ModelContext
    
    /// Initialize with a model context
    init(context: ModelContext) {
        self.context = context
    }
    
    /// Fetch entities matching a descriptor
    func fetch(descriptor: FetchDescriptor<T>) throws -> [T] {
        try context.fetch(descriptor)
    }
    
    /// Insert an entity into the context
    func insert(_ entity: T) {
        context.insert(entity)
    }
    
    /// Delete an entity from the context
    func delete(_ entity: T) {
        context.delete(entity)
    }
    
    /// Save changes to the context
    func save() throws {
        try context.save()
    }
}
