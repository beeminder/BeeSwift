// Part of BeeSwift. Copyright Beeminder

import Foundation
import AppIntents
import CoreData
import BeeKit

struct GoalEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [GoalEntity] {
        let container = ServiceLocator.persistentContainer
        let context = container.viewContext
        
        guard let currentUser = ServiceLocator.currentUserManager.user(context: context) else {
            return []
        }
        
        return try await context.perform {
            let request = NSFetchRequest<Goal>(entityName: "Goal")
            request.predicate = NSPredicate(format: "owner == %@ AND id IN %@", currentUser, identifiers)

            let goals = try context.fetch(request)
            return goals.map { GoalEntity(from: $0) }
        }
    }
    
    func suggestedEntities() async throws -> [GoalEntity] {
        let container = ServiceLocator.persistentContainer
        let context = container.viewContext
        
        guard let currentUser = ServiceLocator.currentUserManager.user(context: context) else {
            return []
        }
        
        return try await context.perform {
            let request = NSFetchRequest<Goal>(entityName: "Goal")
            request.predicate = NSPredicate(format: "owner == %@", currentUser)
            request.sortDescriptors = [NSSortDescriptor(key: "urgencyKey", ascending: true)]
            request.fetchLimit = 20

            let goals = try context.fetch(request)
            return goals.map { GoalEntity(from: $0) }
        }
    }
    
    func entities(matching string: String) async throws -> [GoalEntity] {
        let container = ServiceLocator.persistentContainer
        let context = container.viewContext
        
        guard let currentUser = ServiceLocator.currentUserManager.user(context: context) else {
            return []
        }
        
        return try await context.perform {
            let request = NSFetchRequest<Goal>(entityName: "Goal")
            request.predicate = NSPredicate(
                format: "owner == %@ AND (slug CONTAINS[cd] %@ OR title CONTAINS[cd] %@)",
                currentUser, string, string
            )
            request.sortDescriptors = [NSSortDescriptor(key: "urgencyKey", ascending: true)]
            
            let goals = try context.fetch(request)
            return goals.map { GoalEntity(from: $0) }
        }
    }
}
