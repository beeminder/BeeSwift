//
//  JSONUser.swift
//  BeeSwift
//
//  Created by krugerk on 23.06.20.
//  Copyright © 2020 krugerk. All rights reserved.
//

import Foundation

import SwiftyJSON

/**
 A User object ("object" in the JSON sense) includes information about a user, like their list of goals.
 
 - seealso:
 [Beeminder API - User](https://api.beeminder.com/#user)
 */
struct JSONUser: Codable {
    let username: String
    /// DRAFT: example: "Europe\/Berlin"
    let timezone: String
    /// (number): Unix timestamp (in seconds) of the last update to this user or any of their goals or datapoints.
    let updated_at: TimeInterval
    /// goals (array): A list of slugs for each of the user's goals, or an array of goal hashes (objects) if diff_since or associations is sent.
    let goals: [String]
    ///  (boolean): True if the user's payment info is out of date, or an attempted payment has failed.
    let deadbeat: Bool
    ///  (number): The idea of Urgency Load is to construct a single number that captures how edge-skatey you are across all your goals. A lower number means fewer urgently due goals. A score of 0 means that you have >= 7 days of buffer on all of your active goals.
    let urgency_load: Int
    ///  (array): An array of hashes, each with one key/value pair for the id of the deleted goal.
    ///  Optional, only returned if diff_since is sent.
    let deleted_goals: [DeletedGoal]?
    
    // MARK: - these were provided in the json but not on the api doc
    
    let id: String
    
    let remaining_subs_credit: Int
    let default_deadline: Int
    
    /// DRAFT: example 34200; 34200 / 60 / 60 = 9.50 = 9:30 in the morning
    let default_alertstart: TimeInterval
    let subs_downto: String
    let has_authorized_fitbit: Bool
    
    /// DRAFT: string, probably with well-known strings
    ///
    /// - Core Beeminder
    /// - Infinibee
    /// - Bee Plus
    /// - Beemium
    let subscription: String
    
    /// DRAFT: example 1000
    let subs_freq: Int
    
    /// DRAFT: the extent of the validity of the subscription?
    let subs_lifetime: String
    
    /// example 1416166725
    let created_at: TimeInterval
    
    init?(json: JSON) {
        self.username = json["username"].stringValue
        self.timezone = json["timezone"].stringValue
        self.updated_at = json["updated_at"].doubleValue
        
        self.goals = json["goals"].arrayValue.map { $0.stringValue }
        
        self.deadbeat = json["deadbeat"].boolValue
        self.urgency_load = json["deadbeat"].intValue
        
        self.deleted_goals = json["deleted_goals"].array?.compactMap {
            DeletedGoal(id: $0["id"].stringValue, slug: $0["slug"].stringValue)
        }
        
        self.id = json["id"].stringValue
        
        self.remaining_subs_credit = json["remaining_subs_credit"].intValue
        self.default_deadline = json["default_deadline"].intValue
        
        self.default_alertstart = json["default_alertstart"].doubleValue
        self.subs_downto = json["subs_downto"].stringValue
        self.has_authorized_fitbit = json["has_authorized_fitbit"].boolValue
        
        self.subscription = json["subscription"].stringValue
        
        self.subs_freq = json["subs_freq"].intValue
        
        self.subs_lifetime = json["subs_lifetime"].stringValue
        
        self.created_at = json["created_at"].doubleValue
        
    }
}


/// represents a deleted goal
///
/// hashes, each with one key/value pair for the id of the deleted goal.
struct DeletedGoal: Codable {
    let id: String
    let slug: String
}
