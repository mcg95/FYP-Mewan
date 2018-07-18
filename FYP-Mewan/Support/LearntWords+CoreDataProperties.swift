//
//  LearntWords+CoreDataProperties.swift
//  
//
//  Created by Mewan Chathuranga on 15/05/2018.
//
//

import Foundation
import CoreData


extension LearntWords {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LearntWords> {
        return NSFetchRequest<LearntWords>(entityName: "LearntWords")
    }

    @NSManaged public var englishword: String?
    @NSManaged public var malayword: String?

}
