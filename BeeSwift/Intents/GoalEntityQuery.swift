// Part of BeeSwift. Copyright Beeminder

import AppIntents
import BeeKit
import CoreData
import Foundation

struct GoalEntityQuery: EnumerableEntityQuery, EntityStringQuery {
  func allEntities() async throws -> [GoalEntity] { return try await fetchGoals { _ in } }

  func entities(for identifiers: [String]) async throws -> [GoalEntity] {
    return try await fetchGoals { request in request.predicate = NSPredicate(format: "id IN %@", identifiers) }
  }

  func suggestedEntities() async throws -> [GoalEntity] {
    return try await fetchGoals { request in
      request.sortDescriptors = [NSSortDescriptor(key: "urgencyKey", ascending: true)]
      request.fetchLimit = 20
    }
  }

  func entities(matching string: String) async throws -> [GoalEntity] {
    return try await fetchGoals { request in
      request.predicate = NSPredicate(format: "slug CONTAINS[cd] %@ OR title CONTAINS[cd] %@", string, string)
      request.sortDescriptors = [NSSortDescriptor(key: "slug", ascending: true)]
    }
  }

  private func fetchGoals(configureFetch: @escaping (NSFetchRequest<Goal>) -> Void) async throws -> [GoalEntity] {
    let container = ServiceLocator.persistentContainer
    let context = container.viewContext
    return try await context.perform {
      let request = NSFetchRequest<Goal>(entityName: "Goal")
      configureFetch(request)

      guard let currentUser = ServiceLocator.currentUserManager.user(context: context) else { return [] }
      let ownerPredicate = NSPredicate(format: "owner == %@", currentUser)
      if let existingPredicate = request.predicate {
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [ownerPredicate, existingPredicate])
      } else {
        request.predicate = ownerPredicate
      }

      let goals = try context.fetch(request)
      return goals.map { GoalEntity(from: $0) }
    }
  }
}
