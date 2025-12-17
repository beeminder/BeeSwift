//
//  CoreDataModelExecutor.swift
//  BeeKit
//
//  Provides actor executor support for Core Data managed object contexts.
//  This replaces the @NSModelActor macro from CoreDataEvolution.
//

import CoreData

/// A serial executor that uses an NSManagedObjectContext's queue for actor isolation.
/// This allows actors to safely access Core Data on the context's thread.
public final class CoreDataModelExecutor: SerialExecutor, @unchecked Sendable {
  public let context: NSManagedObjectContext

  public init(context: NSManagedObjectContext) { self.context = context }

  public func enqueue(_ job: consuming ExecutorJob) {
    let unownedJob = UnownedJob(job)
    context.perform { unownedJob.runSynchronously(on: self.asUnownedSerialExecutor()) }
  }

  public func asUnownedSerialExecutor() -> UnownedSerialExecutor { UnownedSerialExecutor(ordinary: self) }
}
