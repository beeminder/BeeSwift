// Part of BeeSwift. Copyright Beeminder


@objc(DueByTableValueTransformer)
public class DueByTableValueTransformer: ValueTransformer {
    public override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }
    
    public override func transformedValue(_ value: Any?) -> Any? {
        guard let dueByTable = value as? DueByTable else { return nil }
        do {
            return try JSONEncoder().encode(dueByTable)
        } catch {
            print("Error encoding due by table: \(error)")
        }
        return nil
    }
    
    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        do {
            return try JSONDecoder().decode(DueByTable.self, from: data)
        } catch {
            print("Error decoding due by table: \(error)")
            return nil
        }
    }
    
}

public extension DueByTableValueTransformer {
    public static var name: NSValueTransformerName {
        .init(rawValue: String(describing: DueByTableValueTransformer.self))
    }
    
    public static func register() {
        ValueTransformer.setValueTransformer(DueByTableValueTransformer(),
                                             forName: DueByTableValueTransformer.name)
    }
}
