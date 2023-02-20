import Foundation

/// Thread-safe container for a single wrapped variable
/// Allows a single value to be read/written from multiple threads by locking access.
/// This assumes the contained value is a struct or immutable - a mutable value could be modified in unsafe ways by
/// users of this class.
final class SynchronizedBox<Value> {
    let lock = NSLock()
    var innerValue: Value

    init(_ innerValue: Value) {
        self.innerValue = innerValue
    }

    func set(_ newValue: Value) {
        lock.withLock {
            self.innerValue = newValue
        }
    }

    func get() -> Value {
        lock.withLock {
            self.innerValue
        }
    }
}
