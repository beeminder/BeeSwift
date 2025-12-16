//
//  CoreDataModelExecutor.swift
//  BeeKit
//
//  Provides actor executor support for Core Data managed object contexts.
//  This replaces the @NSModelActor macro from CoreDataEvolution.
//

import CoreData

/// A simple wrapper that provides access to an NSManagedObjectContext for use as an actor executor.
/// This allows actors to use the context's serial queue for isolation.
public struct CoreDataModelExecutor: Sendable {
  public let context: NSManagedObjectContext

  public init(context: NSManagedObjectContext) { self.context = context }
}
