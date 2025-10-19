//
//  extension.swift
//  SlideMenuView_3
//
//  Created by Yuki Sasaki on 2025/10/03.
//

import SwiftUI

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
