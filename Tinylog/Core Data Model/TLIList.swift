//
//  TLIList.swift
//  Tinylog
//
//  Created by Spiros Gerokostas on 17/10/15.
//  Copyright © 2015 Spiros Gerokostas. All rights reserved.
//

import Foundation
import CoreData

class TLIList: NSManagedObject {

    static let entityName = "List"

    init(context: NSManagedObjectContext, title: String, color: String) {
        // swiftlint:disable force_unwrapping
        let entity = NSEntityDescription.entity(forEntityName: TLIList.entityName, in: context)!
        super.init(entity: entity, insertInto: context)

        self.title = title
        self.color = color
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()

        if self.uniqueIdentifier == nil {
            self.uniqueIdentifier = ProcessInfo.processInfo.globallyUniqueString
        }
    }

    func highestPosition() -> NSInteger {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Task")
        let positionDescriptor  = NSSortDescriptor(key: "position", ascending: false)
        fetchRequest.predicate = NSPredicate(format: "list = %@", self)
        fetchRequest.sortDescriptors = [positionDescriptor]
        fetchRequest.fetchLimit = 1

        do {
            if let results = try self.managedObjectContext?.fetch(fetchRequest) {
                if results.isEmpty {
                    return 0
                }
                if let task = results[0] as? TLITask,
                    let list = task.list,
                    let position = list.position {
                        return position.intValue
                }
            }
        } catch let error as NSError {
            print("error : \(error.localizedDescription)")
        }
        return 0
    }

    func numberOfLists(_ context: NSManagedObjectContext) -> NSInteger {
        // Fetch all objects from list
        let fetchRequestTotal: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Task")
        let positionDescriptor  = NSSortDescriptor(key: "position", ascending: false)
        fetchRequestTotal.sortDescriptors = [positionDescriptor]
        fetchRequestTotal.predicate  = NSPredicate(format: "archivedAt = nil AND list = %@", self)
        fetchRequestTotal.fetchBatchSize = 20

        do {
            let results: NSArray = try context.fetch(fetchRequestTotal) as NSArray
            return results.count
        } catch let error as NSError {
            print("error : \(error.localizedDescription)")
        }
        return 0
    }

    @objc
    fileprivate override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
}
