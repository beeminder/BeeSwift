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
    
    class func crupdateWithJSON(_ json :JSON) -> Datapoint {
        var datapoint :Datapoint? = Datapoint.mr_findFirst(byAttribute: "id", withValue:json["id"].string!)
        if (datapoint != nil) {
            Datapoint.updateDatapoint(datapoint!, withJSON: json)
        }
        else {
            datapoint = Datapoint.mr_createEntity()
            Datapoint.updateDatapoint(datapoint!, withJSON: json)
        }
        return datapoint!
    }
    
    class func updateDatapoint(_ datapoint :Datapoint, withJSON json :JSON) {
        datapoint.timestamp = json["timestamp"].number!
        datapoint.value = json["value"].number!
        datapoint.comment = json["comment"].string!
        datapoint.updated_at = json["updated_at"].number!
        datapoint.canonical = json["canonical"].string!
        datapoint.id = json["id"].string!
        datapoint.daystamp = json["daystamp"].number!
        if json["requestid"].string != nil {
            datapoint.requestid = json["requestid"].string!
        }
        NSManagedObjectContext.mr_default().mr_saveToPersistentStore(completion: nil)        
    }
    
}
