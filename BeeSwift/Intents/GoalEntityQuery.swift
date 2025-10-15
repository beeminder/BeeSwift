// Part of BeeSwift. Copyright Beeminder

import AppIntents
import BeeKit
import CoreData
import Foundation

struct GoalEntityQuery: EnumerableEntityQuery, EntityStringQuery {
  func allEntities() async throws -> [GoalEntity] { return try await fetchGoals() }

  func entities(for identifiers: [String]) async throws -> [GoalEntity] {
    return try await fetchGoals(additionalPredicate: NSPredicate(format: "id IN %@", identifiers))
  }

  func suggestedEntities() async throws -> [GoalEntity] { return try await fetchGoals(fetchLimit: 20) }

  func entities(matching string: String) async throws -> [GoalEntity] {
    return try await fetchGoals(
      additionalPredicate: NSPredicate(format: "slug CONTAINS[cd] %@ OR title CONTAINS[cd] %@", string, string)
    )
  }

  private func fetchGoals(
    additionalPredicate: NSPredicate? = nil,
    sortDescriptors: [NSSortDescriptor] = [NSSortDescriptor(key: "urgencyKey", ascending: true)],
    fetchLimit: Int? = nil
  ) async throws -> [GoalEntity] {
    let container = ServiceLocator.persistentContainer
    let context = container.viewContext
    guard let currentUser = ServiceLocator.currentUserManager.user(context: context) else { return [] }
    return try await context.perform {
      let request = NSFetchRequest<Goal>(entityName: "Goal")

      // Always add owner constraint
      let ownerPredicate = NSPredicate(format: "owner == %@", currentUser)
      if let additionalPredicate = additionalPredicate {
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [ownerPredicate, additionalPredicate])
      } else {
        request.predicate = ownerPredicate
      }

      request.sortDescriptors = sortDescriptors
      if let fetchLimit = fetchLimit { request.fetchLimit = fetchLimit }

      let goals = try context.fetch(request)
      return goals.map { GoalEntity(from: $0) }
    }
  }
}
