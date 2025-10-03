//
//  ContentView.swift
//  SlideMenuView_3
//
//  Created by Yuki Sasaki on 2025/10/03.
//

import SwiftUI
import CoreData
import UIKit

class FolderTableViewController: UITableViewController, NSFetchedResultsControllerDelegate {

    var context: NSManagedObjectContext!

    var frc: NSFetchedResultsController<Folder>!
    var flatData: [Folder] = []
    var expandedState: [NSManagedObjectID: Bool] = [:]
    
    private(set) var rootFolders: [Folder] = []

    //***

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(CustomCell.self, forCellReuseIdentifier: "cell")

        setupFRC()

        // fetchedObjects から rootFolders を取り出して flatData を作成
        if let objects = frc?.fetchedObjects {
            flatData = flatten(folders: objects.filter { $0.parent == nil })
        }

        // 追加ボタン
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addFolder)
        )
    }

    
    //***
    
    // クラス内プロパティ（既存の var 宣言のそばに追加）
    var suppressFRCUpdates = false

    // 既存の controllerDidChangeContent を次のように置き換えてください
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // 自分で手動更新中は FRC の自動反映を無視
        if suppressFRCUpdates { return }

        if let objects = frc.fetchedObjects {
            flatData = flatten(folders: objects.filter { $0.parent == nil })
            tableView.reloadData()
        }
    }

    // FolderTableViewController に以下のメソッドを追加してください
    func addChildFolder(to parent: Folder) {
        let alert = UIAlertController(title: "子フォルダ名を入力", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "新しい子フォルダ名" }
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.addAction(UIAlertAction(title: "追加", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            guard let text = alert.textFields?.first?.text, !text.isEmpty else { return }

            // 保存中に FRC の自動反映を抑制
            self.suppressFRCUpdates = true

            // 新しいフォルダを作る
            let newFolder = Folder(context: self.context)
            newFolder.folderName = text
            newFolder.parent = parent
            parent.addToChildren(newFolder)   // ← これを追加

            // 親の既存 children 数を元に sortIndex を設定（末尾に追加）
            let currentChildCount = (parent.children as? Set<Folder>)?.count ?? 0
            newFolder.sortIndex = Int64(currentChildCount)

            do {
                try self.context.save()
            } catch {
                print("子フォルダ保存失敗: \(error)")
                self.suppressFRCUpdates = false
                return
            }

            DispatchQueue.main.async {
                // 古い表示配列を保持
                let oldFlat = self.flatData

                // 自動で親を展開する（不要ならこの行を外す）
                self.expandedState[parent.objectID] = true

                // 新しい fetchedObjects から新しい flatData を作る
                guard let objects = self.frc.fetchedObjects else {
                    self.suppressFRCUpdates = false
                    return
                }
                let newFlat = self.flatten(folders: objects.filter { $0.parent == nil })

                // 差分（新しく追加された objectID）を見つける
                let oldIDs = Set(oldFlat.map { $0.objectID })
                var insertIndexPaths: [IndexPath] = []
                for (i, f) in newFlat.enumerated() {
                    if !oldIDs.contains(f.objectID) {
                        insertIndexPaths.append(IndexPath(row: i, section: 0))
                    }
                }

                // data source を先に更新してから table に反映（重要）
                self.flatData = newFlat

                if !insertIndexPaths.isEmpty {
                    self.tableView.beginUpdates()
                    self.tableView.insertRows(at: insertIndexPaths, with: .automatic)
                    self.tableView.endUpdates()

                    // optional: 新しく追加された行までスクロール
                    if let last = insertIndexPaths.last {
                        self.tableView.scrollToRow(at: last, at: .middle, animated: true)
                    }
                } else {
                    // 差分が見つからなければ安全にリロード
                    self.tableView.reloadData()
                }

                // 抑制フラグを戻す
                self.suppressFRCUpdates = false
            }
        }))

        present(alert, animated: true)
    }

    
    // MARK: - Context Menu　コンテキストメニュー
    override func tableView(_ tableView: UITableView,
                            contextMenuConfigurationForRowAt indexPath: IndexPath,
                            point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.row < flatData.count else { return nil }
        let folder = flatData[indexPath.row]

        return UIContextMenuConfiguration(identifier: nil,
                                          previewProvider: nil) { _ in
            let addChild = UIAction(title: "子フォルダを追加",
                                    image: UIImage(systemName: "folder.badge.plus")) { [weak self] _ in
                self?.addChildFolder(to: folder)
            }

            return UIMenu(title: "", children: [addChild])
        }
    }


    private func setupFRC() {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "sortIndex", ascending: true),
            NSSortDescriptor(key: "folderName", ascending: true)
        ]

        frc = NSFetchedResultsController(fetchRequest: request,
                                         managedObjectContext: context,
                                         sectionNameKeyPath: nil,
                                         cacheName: nil)
        frc.delegate = self

        do {
            try frc.performFetch()
            if let objects = frc.fetchedObjects {
                flatData = flatten(folders: objects.filter { $0.parent == nil })
            }
        } catch {
            print("FRC fetch error: \(error)")
        }
    }
    
    // MARK: - Add Folder　フォルダ追加
    @objc private func addFolder() {
        let alert = UIAlertController(title: "新しいフォルダ", message: "名前を入力してください", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "フォルダ名" }

        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.addAction(UIAlertAction(title: "追加", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let name = alert.textFields?.first?.text ?? "無題"

            // 新しいフォルダを作成
            let newFolder = Folder(context: self.context)
            newFolder.folderName = name
            newFolder.sortIndex = (self.flatData.last?.sortIndex ?? -1) + 1

            do { try self.context.save() } catch { print(error) }

            // FRC から再取得
            if let objects = self.frc.fetchedObjects {
                self.flatData = self.flatten(folders: objects.filter { $0.parent == nil })
                self.tableView.reloadData()
            }
        }))

        present(alert, animated: true)
    }

    
    // MARK: - Flatten
    private func flatten(folders: [Folder]) -> [Folder] {
        var result: [Folder] = []
        for folder in folders {
            result.append(folder)
            if expandedState[folder.objectID] == true,
               let children = (folder.children as? Set<Folder>)?.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                result.append(contentsOf: flatten(folders: children))
            }
        }
        return result
    }

    private func getLevel(of folder: Folder) -> Int {
        var level = 0
        var current = folder.parent
        while current != nil {
            level += 1
            current = current?.parent
        }
        return level
    }

    // MARK: - UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        flatData.count
    }
// MARK: - セル表示
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let folder = flatData[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! CustomCell

        let level = getLevel(of: folder)
        cell.indentationLevel = level
        cell.indentationWidth = 20
        cell.configure(with: folder, isExpanded: expandedState[folder.objectID] ?? false)

        return cell
    }



    // MARK: - Toggle Folder

    @objc private func toggleFolder(_ sender: UITapGestureRecognizer) {
        guard let row = sender.view?.tag else { return }
        let folder = flatData[row]
        let isExpanded = expandedState[folder.objectID] ?? false
        expandedState[folder.objectID] = !isExpanded

        let startIndex = row + 1
        var indexPaths: [IndexPath] = []

        let children = (folder.children as? Set<Folder>)?.sorted(by: { $0.sortIndex < $1.sortIndex }) ?? []

        tableView.beginUpdates()
        if !isExpanded {
            // 展開
            flatData.insert(contentsOf: children, at: startIndex)
            indexPaths = children.indices.map { IndexPath(row: startIndex + $0, section: 0) }
            tableView.insertRows(at: indexPaths, with: .fade)
        } else {
            // 折りたたみ
            flatData.removeSubrange(startIndex..<startIndex + children.count)
            indexPaths = children.indices.map { IndexPath(row: startIndex + $0, section: 0) }
            tableView.deleteRows(at: indexPaths, with: .fade)
        }
        tableView.endUpdates()

        // 矢印アニメーション
        if let arrow = tableView.cellForRow(at: IndexPath(row: row, section: 0))?.accessoryView as? UIImageView {
            UIView.animate(withDuration: 0.25) {
                arrow.transform = !isExpanded ? CGAffineTransform(rotationAngle: .pi/2) : .identity
            }
        }
    }

    // MARK: - NSFetchedResultsControllerDelegate

    /*func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let objects = frc.fetchedObjects {
            flatData = flatten(folders: objects.filter { $0.parent == nil })
            tableView.reloadData() // 差分更新に変えるとさらにアニメーション対応可能
        }
    }*/
}





// SwiftUI Preview / 使用例
struct ContentView: View {
    var body: some View {
        //NavigationView {
            ListVCWrapper()
                //.navigationTitle("Detail")
        //}
    }
}


// ListViewController 用ラッパー
struct ListVCWrapper: UIViewControllerRepresentable {

    @Environment(\.managedObjectContext) var context

    func makeUIViewController(context: Context) -> UINavigationController {
        let folderVC = FolderTableViewController()
        folderVC.context = self.context
        let nav = UINavigationController(rootViewController: folderVC)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // 必要があれば更新
    }
}


