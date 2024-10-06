import Foundation
import SwiftData

@Model public class User {
    public var username: String
    public var deadbeat: Bool
    public var timezone: String
    public var defaultAlertStart: Int
    public var defaultDeadline: Int
    public var defaultLeadTime: Int

    @Relationship(deleteRule: .cascade)  public var goals: Set<Goal>

    /// The last time this record in the CoreData store was updated
    public var lastModifiedLocal: Date

    public init(
                username: String,
                deadbeat: Bool,
                timezone: String,
                defaultAlertStart: Int,
                defaultDeadline: Int,
                defaultLeadTime: Int
    ) {
        self.username = username
        self.deadbeat = deadbeat
        self.timezone = timezone
        self.defaultAlertStart = defaultAlertStart
        self.defaultDeadline = defaultDeadline
        self.defaultLeadTime = defaultLeadTime

        lastModifiedLocal = Date()
    }
}
