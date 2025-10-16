//
//  Folder+CoreDataProperties.swift
//  SlideMenuView_3
//
//  Created by Yuki Sasaki on 2025/10/16.
//
//

import Foundation
import CoreData


extension Folder {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Folder> {
        return NSFetchRequest<Folder>(entityName: "Folder")
    }

    @NSManaged public var currentDate: Date?
    @NSManaged public var folderMadeTime: Date?
    @NSManaged public var folderName: String?
    @NSManaged public var sortIndex: Int64
    //@NSManaged public var level: Int64
    @NSManaged public var children: NSSet?
    @NSManaged public var parent: Folder?

}

// MARK: Generated accessors for children
extension Folder {

    @objc(addChildrenObject:)
    @NSManaged public func addToChildren(_ value: Folder)

    @objc(removeChildrenObject:)
    @NSManaged public func removeFromChildren(_ value: Folder)

    @objc(addChildren:)
    @NSManaged public func addToChildren(_ values: NSSet)

    @objc(removeChildren:)
    @NSManaged public func removeFromChildren(_ values: NSSet)

}

extension Folder : Identifiable {

}
