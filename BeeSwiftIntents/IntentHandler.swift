//
//  IntentHandler.swift
//  BeeSwiftIntents
//
//  Created by Theo Spears on 9/1/22.
//

import Foundation
import Intents

@available(iOS 14.0, *)
class IntentHandler : INExtension {
    override func handler(for intent: INIntent) -> Any? {
        AddDataIntentHandler()
    }
}
