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
        
        setupToolbar()
        updateToolbar()

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
    
    // MARK: - UIMenu
    
    private var bottomToolbar: UIToolbar = UIToolbar()
    
    enum BottomToolbarState {
        case normal
        case selecting
        case editing   // 将来的に編集モードなど追加したい場合に便利
    }

    var selectedFolders: Set<Folder> = []
    var isHideMode = false // ← トグルで切り替え


    
    @objc private func transferItems() {
        // 選択アイテムの転送処理
        //delegate?.didToggleBool_TransferModal(true)
        
        // 選択をクリア
        selectedFolders.removeAll()
        
        // テーブルの選択状態もリセット
        tableView.reloadData()
        
        // ツールバーを通常に戻す
        bottomToolbarState = .normal
        updateToolbar()
    }
    
    private func updateToolbar() {
            switch bottomToolbarState {
            case .normal:
                bottomToolbar.isHidden = false
                let edit = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(startEditing))
                bottomToolbar.setItems([edit], animated: false)

            case .selecting:
                bottomToolbar.isHidden = false
                let edit = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(editCancelEdit))
                bottomToolbar.setItems([edit], animated: false)

            case .editing:
                bottomToolbar.isHidden = false
                let cancel = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(selectCancelEdit))

                if selectedFolders.isEmpty {
                    // 選択なし → Cancel だけ
                    bottomToolbar.setItems([cancel], animated: false)
                } else {
                    // 選択あり → Cancel + Transfer
                    let transfer = UIBarButtonItem(title: "Transfer", style: .plain, target: self, action: #selector(transferItems))
                    bottomToolbar.setItems([cancel, UIBarButtonItem.flexibleSpace(), transfer], animated: false)
                }
            }
        }
    
    private func setupToolbar() {
        bottomToolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomToolbar)
        
        NSLayoutConstraint.activate([
            bottomToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomToolbar.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    //var isEditingMode: Bool = false
    
    @objc private func editCancelEdit() {
        isHideMode = false
        // 選択アイテムをクリア
        selectedFolders.removeAll()
        
        // bottomToolbarState を通常に戻す
        bottomToolbarState = .normal
        
        // テーブルの選択状態もリセット
        tableView.reloadData()
        
        // ツールバーを更新
        updateToolbar()
    }

    private var bottomToolbarState: BottomToolbarState = .normal {
        didSet {
            updateToolbar()
        }
    }
    

    // MARK: - Actions
    @objc private func startEditing() {
        bottomToolbarState = .selecting
        isHideMode = true
        tableView.reloadData() // ←ここが重要
    }


    @objc private func selectCancelEdit() {
        // 選択アイテムをクリア
        selectedFolders.removeAll()
        
        // bottomToolbarState を通常に戻す
        bottomToolbarState = .normal
        
        // テーブルの選択状態もリセット
        tableView.reloadData()
        
        // ツールバーを更新
        updateToolbar()
    }
    
    
    
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
            if expandedState[folder.objectID] == true {
                let children = (folder.children?.allObjects as? [Folder])?.sorted { $0.sortIndex < $1.sortIndex } ?? []
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
        let isExpanded = expandedState[folder.objectID] ?? false
        cell.configure(with: folder, level: level, isExpanded: isExpanded)

        // 矢印タップで開閉
        cell.arrowTapAction = { [weak self] in
            self?.toggleFolder(for: folder)
        }

        return cell
    }

    // MARK: - Helpers

    /// 展開時に挿入すべき「表示される子孫」を返す
    private func visibleChildrenForExpand(of folder: Folder) -> [Folder] {
        let children = (folder.children?.allObjects as? [Folder])?
            .sorted(by: { $0.sortIndex < $1.sortIndex }) ?? []
        var result: [Folder] = []
        for child in children {
            result.append(child)
            // もし子が既に expandedState == true なら、その子の子も表示対象に含める
            if expandedState[child.objectID] == true {
                result.append(contentsOf: visibleChildrenForExpand(of: child))
            }
        }
        return result
    }

    /// flatData 内で、`folder` の直後に続く「表示中の descendant」のインデックスリストを返す
    private func indicesOfDescendantsInFlatData(startingAt folderIndex: Int, parentLevel: Int) -> [Int] {
        var indices: [Int] = []
        var i = folderIndex + 1
        while i < flatData.count {
            let level = getLevel(of: flatData[i])
            if level > parentLevel {
                indices.append(i)
                i += 1
            } else {
                break
            }
        }
        return indices
    }

    /// 再帰で配下の expandedState を false にする
    private func collapseAllDescendantsState(of folder: Folder) {
        guard let children = folder.children as? Set<Folder> else { return }
        for child in children {
            expandedState[child.objectID] = false
            collapseAllDescendantsState(of: child)
        }
    }

    // MARK: - Toggle (animated)

    @objc func toggleFolder(for folder: Folder) {
        // まず folder の現在の行を探す
        guard let row = flatData.firstIndex(of: folder) else { return }
        let isExpanded = expandedState[folder.objectID] ?? false
        let parentLevel = getLevel(of: folder)

        if !isExpanded {
            // ----- 展開 -----
            // 表示すべき子（および、すでに expanded な子の孫まで）を列挙
            let itemsToInsert = visibleChildrenForExpand(of: folder)
            guard !itemsToInsert.isEmpty else {
                // 子がいなければ単に state を true にして矢印更新だけ
                expandedState[folder.objectID] = true
                if let cell = tableView.cellForRow(at: IndexPath(row: row, section: 0)) as? CustomCell {
                    cell.arrowImageView.image = UIImage(systemName: "chevron.down")
                    UIView.animate(withDuration: 0.25) {
                        cell.arrowImageView.transform = CGAffineTransform(rotationAngle: .pi/2)
                    }
                }
                return
            }

            let startIndex = row + 1
            let indexPaths = itemsToInsert.enumerated().map { IndexPath(row: startIndex + $0.offset, section: 0) }

            // 1) dataSource を先に更新
            flatData.insert(contentsOf: itemsToInsert, at: startIndex)
            expandedState[folder.objectID] = true

            // 2) tableView にアニメーションで反映
            tableView.beginUpdates()
            tableView.insertRows(at: indexPaths, with: .fade)
            tableView.endUpdates()

        } else {
            // ----- 折りたたみ -----
            let indicesToDelete = indicesOfDescendantsInFlatData(startingAt: row, parentLevel: parentLevel)
            guard !indicesToDelete.isEmpty else {
                expandedState[folder.objectID] = false
                if let cell = tableView.cellForRow(at: IndexPath(row: row, section: 0)) as? CustomCell {
                    cell.arrowImageView.image = UIImage(systemName: "chevron.right")
                    UIView.animate(withDuration: 0.25) {
                        cell.arrowImageView.transform = .identity
                    }
                }
                return
            }

            let indexPaths = indicesToDelete.map { IndexPath(row: $0, section: 0) }

            // ❌ 展開状態を全て false にする処理を削除！
            // if let objects = indicesToDelete.map({ flatData[$0] }) as? [Folder] {
            //     for f in objects { expandedState[f.objectID] = false }
            // }
            // collapseAllDescendantsState(of: folder)

            // ✅ 自分（親フォルダ）だけ閉じる
            expandedState[folder.objectID] = false

            // データ更新
            for idx in indicesToDelete.sorted(by: >) {
                flatData.remove(at: idx)
            }

            // アニメーション
            tableView.beginUpdates()
            tableView.deleteRows(at: indexPaths, with: .fade)
            tableView.endUpdates()
        }

        // 親セルの矢印回転更新
        if let parentCell = tableView.cellForRow(at: IndexPath(row: row, section: 0)) as? CustomCell {
            let nowExpanded = expandedState[folder.objectID] ?? false
            let imageName = nowExpanded ? "chevron.down" : "chevron.right"
            UIView.transition(with: parentCell.arrowImageView,
                              duration: 0.22,
                              options: .transitionCrossDissolve,
                              animations: {
                parentCell.arrowImageView.image = UIImage(systemName: imageName)?.withRenderingMode(.alwaysTemplate)
                parentCell.arrowImageView.semanticContentAttribute = .forceLeftToRight
            }, completion: nil)
        }
        
    }



    // MARK: - Toggle Folder

    private func collapseAllDescendants(of folder: Folder) {
        guard let children = folder.children as? Set<Folder> else { return }
        for child in children {
            expandedState[child.objectID] = false
            collapseAllDescendants(of: child) // 再帰で孫・ひ孫も閉じる
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


