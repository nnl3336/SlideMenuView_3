//
//  extension.swift
//  SlideMenuView_3
//
//  Created by Yuki Sasaki on 2025/10/03.
//

import SwiftUI

import CoreData

private var isVisibleKey: UInt8 = 0

extension Folder {
    var isVisible: Bool {
        get {
            (objc_getAssociatedObject(self, &isVisibleKey) as? Bool) ?? true
        }
        set {
            objc_setAssociatedObject(self, &isVisibleKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        return Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}

extension Folder {
    /// id が nil の場合、自動で UUID を割り当てる
    var safeID: UUID {
        if let id = self.id {
            return id
        } else {
            let newID = UUID()
            self.id = newID
            try? self.managedObjectContext?.save()
            return newID
        }
    }
}

//階層Folder
/*extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}*/

// CoreData Folder の UUID 拡張　階層Folder
extension Folder {
    var uuid: UUID {
        if let id = self.value(forKey: "id") as? UUID { return id }
        let newId = UUID()
        self.setValue(newId, forKey: "id")
        return newId
    }
}

extension Folder {
    /// 親をたどって階層レベルを計算
    var level: Int {
        var depth = 0
        var current = self.parent
        while let p = current {
            depth += 1
            current = p.parent
        }
        return depth
    }
}
