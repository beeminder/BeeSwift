//
//  DatapointExtension.swift
//  BeeSwift
//
//  Created by Andy Brett on 5/12/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation
import SwiftyJSON
import MagicalRecord

extension Datapoint {
    
    class func crupdateWithJSON(json :JSON) -> Datapoint {
        var datapoint :Datapoint? = Datapoint.MR_findFirstByAttribute("id", withValue:json["id"].string!)
        if (datapoint != nil) {
            Datapoint.updateDatapoint(datapoint!, withJSON: json)
        }
        else {
            datapoint = Datapoint.MR_createEntity()
            Datapoint.updateDatapoint(datapoint!, withJSON: json)
        }
        return datapoint!
    }
    
    class func updateDatapoint(datapoint :Datapoint, withJSON json :JSON) {
        datapoint.timestamp = json["timestamp"].number!
        datapoint.value = json["value"].number!
        datapoint.comment = json["comment"].string!
        datapoint.updated_at = json["updated_at"].number!
        datapoint.canonical = json["canonical"].string!
        datapoint.id = json["id"].string!
        if json["requestid"].string != nil {
            datapoint.requestid = json["requestid"].string!
        }
        NSManagedObjectContext.MR_defaultContext().MR_saveToPersistentStoreWithCompletion(nil)        
    }
    
}