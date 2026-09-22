// Part of BeeSwift. Copyright Beeminder

import AppIntents
import BeeKit
import CoreSpotlight
import CoreTransferable
import Foundation

struct GoalEntity: AppEntity, IndexedEntity, Equatable {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Goal"
  static var defaultQuery = GoalEntityQuery()
  var id: String
  @Property(title: "Slug") var slug: String
  @Property(title: "Title") var title: String
  /// The number of safe days before derailing. Zero means it's a beemergency.
  @Property(title: "Safe Days") var safeBuf: Int
  /// Whether any datapoints have been entered for today.
  @Property(title: "Has Data Today") var todayta: Bool
  /// The amount pledged (USD) on the goal.
  @Property(title: "Pledge") var pledge: Int
  /// Summary of what's needed to stay on track, e.g., "+2 within 1 day".
  @Property(title: "Required Action") var limSum: String
  /// Whether the goal has been successfully completed.
  @Property(title: "Completed") var won: Bool
  /// The name of the automatic data source (e.g., "apple"), or nil for manual goals.
  @Property(title: "Data Source") var autodata: String?
  var thumbUrl: String?
  var username: String
  /// e.g. "safe for 3 days" or "+1 fruits due by 12am"
  var safeSum: String
  var dueBy: [DueByRow]
  /// Newest first.
  var recentDatapoints: [RecentDatapoint]

  struct DueByRow: Equatable, Sendable {
    /// yyyy-mm-dd
    var date: String
    var weekday: String
    /// "✔" when the day is already covered.
    var delta: String
    var total: String

    var isCovered: Bool { delta == "✔" }
    var summaryLine: String {
      isCovered ? "- \(date) (\(weekday)): already covered" : "- \(date) (\(weekday)): \(delta), total \(total)"
    }
  }

  struct RecentDatapoint: Equatable, Sendable {
    /// yyyy-mm-dd
    var date: String
    var value: String
    var comment: String

    var summaryLine: String { comment.isEmpty ? "- \(date): \(value)" : "- \(date): \(value), comment: \(comment)" }
  }
  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(slug)", subtitle: "\(title)") }
  var displayTitle: String { return slug }

  /// Cheaper than `EntityIdentifier(for: GoalEntity(from: goal))` when only the identity is needed.
  static func identifier(for goal: Goal) -> EntityIdentifier {
    EntityIdentifier(for: GoalEntity.self, identifier: goal.id)
  }

  var webURL: URL { DeeplinkGenerator.generateDeepLinkToGoal(username: username, goalName: slug) }

  var plainTextSummary: String {
    var lines = [String]()
    lines.append(title.isEmpty ? "Beeminder goal \(slug)" : "Beeminder goal \(slug): \(title)")
    lines.append(won ? "Status: completed." : "Status: " + safeSum.prefix(1).uppercased() + safeSum.dropFirst())
    lines.append("Pledge: $\(pledge)")
    lines.append(todayta ? "Data entered today: yes" : "Data entered today: no")
    if let autodata, !autodata.isEmpty {
      lines.append("Data source: \(autodata) (automatic)")
    } else {
      lines.append("Data source: entered manually")
    }
    // An all-covered table would only restate the status line.
    if dueBy.contains(where: { !$0.isCovered }) {
      lines.append("Due by day:")
      lines.append(contentsOf: dueBy.map { $0.summaryLine })
    }
    if recentDatapoints.isEmpty {
      lines.append("Recent datapoints: none")
    } else {
      lines.append("Recent datapoints, newest first:")
      lines.append(contentsOf: recentDatapoints.map { $0.summaryLine })
    }
    lines.append("Link: \(webURL.absoluteString)")
    return lines.joined(separator: "\n")
  }

  var attributeSet: CSSearchableItemAttributeSet {
    let attributes = defaultAttributeSet
    attributes.displayName = displayTitle
    attributes.contentDescription = title
    return attributes
  }

  init(
    id: String,
    slug: String,
    title: String,
    safeBuf: Int = 0,
    todayta: Bool = false,
    pledge: Int = 0,
    limSum: String = "",
    won: Bool = false,
    autodata: String? = nil,
    thumbUrl: String? = nil,
    username: String = "",
    safeSum: String = "",
    dueBy: [DueByRow] = [],
    recentDatapoints: [RecentDatapoint] = [],
  ) {
    self.id = id
    self.username = username
    self.safeSum = safeSum
    self.dueBy = dueBy
    self.recentDatapoints = recentDatapoints
    self.slug = slug
    self.title = title
    self.safeBuf = safeBuf
    self.todayta = todayta
    self.pledge = pledge
    self.limSum = limSum
    self.won = won
    self.autodata = autodata
    self.thumbUrl = thumbUrl
  }

  /// `includeRecentData: false` avoids faulting in the goal's datapoints.
  init(from goal: Goal, includeRecentData: Bool = true) {
    self.id = goal.id
    self.username = goal.owner.username
    self.safeSum = goal.safeSum
    self.dueBy = Self.dueByRows(of: goal)
    self.recentDatapoints = includeRecentData ? Self.recentDatapoints(of: goal) : []
    self.slug = goal.slug
    self.title = goal.title
    self.safeBuf = goal.safeBuf
    self.todayta = goal.todayta
    self.pledge = goal.pledge
    self.limSum = goal.limSum
    self.won = goal.won
    self.autodata = goal.autodata
    self.thumbUrl = goal.thumbUrl
  }

  static let maxRecentDatapointsInSummary = 10

  private static let weekdayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "EEE"
    return formatter
  }()

  private static func dueByRows(of goal: Goal) -> [DueByRow] {
    goal.dueBy.sorted { $0.key < $1.key }.compactMap { daystampString, entry in
      guard let daystamp = try? Daystamp(fromString: daystampString) else { return nil }
      let components = DateComponents(year: daystamp.year, month: daystamp.month, day: daystamp.day)
      let weekday = Calendar(identifier: .gregorian).date(from: components).map { weekdayFormatter.string(from: $0) }
      return DueByRow(
        date: String(format: "%04d-%02d-%02d", daystamp.year, daystamp.month, daystamp.day),
        weekday: weekday ?? "",
        delta: entry.formattedDelta,
        total: entry.formattedTotal,
      )
    }
  }

  private static func recentDatapoints(of goal: Goal) -> [RecentDatapoint] {
    let newestFirst = goal.recentData.sorted { ($0.daystamp, $0.updatedAt) > ($1.daystamp, $1.updatedAt) }
    return newestFirst.prefix(maxRecentDatapointsInSummary).map { datapoint in
      RecentDatapoint(
        date: String(
          format: "%04d-%02d-%02d",
          datapoint.daystamp.year,
          datapoint.daystamp.month,
          datapoint.daystamp.day,
        ),
        value: datapoint.formattedValue(hhmmFormat: goal.hhmmFormat),
        comment: datapoint.comment,
      )
    }
  }

  static func == (lhs: GoalEntity, rhs: GoalEntity) -> Bool {
    return lhs.id == rhs.id && lhs.slug == rhs.slug && lhs.title == rhs.title && lhs.safeBuf == rhs.safeBuf
      && lhs.todayta == rhs.todayta && lhs.pledge == rhs.pledge && lhs.limSum == rhs.limSum && lhs.won == rhs.won
      && lhs.autodata == rhs.autodata && lhs.thumbUrl == rhs.thumbUrl && lhs.username == rhs.username
      && lhs.safeSum == rhs.safeSum && lhs.dueBy == rhs.dueBy && lhs.recentDatapoints == rhs.recentDatapoints
  }
}

/// Lets Siri and Apple Intelligence pull the goal's content when it is the on-screen entity.
extension GoalEntity: Transferable {
  static var transferRepresentation: some TransferRepresentation {
    ProxyRepresentation(exporting: \.plainTextSummary)
    ProxyRepresentation(exporting: \.webURL)
  }
}
