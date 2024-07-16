import Foundation

public protocol DataPointProtocol : BeeDataPoint {
    var id: String { get }
    var daystamp: Daystamp { get }
    var value: NSNumber { get }
    var comment: String { get }
    var requestid: String { get }
}
