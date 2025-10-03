//
//  extension.swift
//  SlideMenuView_3
//
//  Created by Yuki Sasaki on 2025/10/03.
//

import SwiftUI

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
