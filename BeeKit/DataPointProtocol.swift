import Foundation

public protocol DataPointProtocol : BeeDataPoint, Hashable {
    var id: String { get }
    var daystamp: Daystamp { get }
    var value: NSNumber { get }
    var comment: String { get }
    var requestid: String { get }
    var updatedAt: Int { get }
}

