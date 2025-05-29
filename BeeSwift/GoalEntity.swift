// Part of BeeSwift. Copyright Beeminder

import Foundation
import AppIntents
import BeeKit

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct GoalEntity: AppEntity, Equatable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Goal"
    static var defaultQuery = GoalEntityQuery()
    
    var id: String
    var slug: String
    var title: String
    var thumbUrl: String?
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(slug)"
        )
    }
    
    init(id: String, slug: String, title: String, thumbUrl: String? = nil) {
        self.id = id
        self.slug = slug
        self.title = title
        self.thumbUrl = thumbUrl
    }
    
    init(from goal: Goal) {
        self.id = goal.id
        self.slug = goal.slug
        self.title = goal.title
        self.thumbUrl = goal.thumbUrl
    }
}