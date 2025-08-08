// Part of BeeSwift. Copyright Beeminder

import Foundation

public class ActivityIndicatorTracker {
    public enum NotificationName {
        public static let activityDidStart = NSNotification.Name(rawValue: "com.beeminder.activityDidStartNotification")
        public static let activityDidEnd = NSNotification.Name(rawValue: "com.beeminder.activityDidEndNotification")
    }
    
    private let queue = DispatchQueue(label: "com.beeminder.activityIndicatorTracker")
    private var activeOperationCount = 0
    
    public init() {}
    
    public func withActivityIndicator<T>(_ operation: () async throws -> T) async throws -> T {
        incrementActivity()
        defer { decrementActivity() }
        return try await operation()
    }
    
    private func incrementActivity() {
        queue.sync {
            let wasZero = activeOperationCount == 0
            activeOperationCount += 1
            if wasZero {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NotificationName.activityDidStart, object: self)
                }
            }
        }
    }
    
    private func decrementActivity() {
        queue.sync {
            activeOperationCount -= 1
            if activeOperationCount == 0 {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NotificationName.activityDidEnd, object: self)
                }
            }
        }
    }
}