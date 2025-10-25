//
//  ContentView.swift
//  SlideMenuView_3
//
//  Created by Yuki Sasaki on 2025/10/03.
//

import SwiftUI
import CoreData
import UIKit

// MARK: - エディット
import UIKit
import CoreData

import UIKit
import CoreData

class FolderViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate, UISearchBarDelegate {
    
    //***//イニシャライズ
    
    //***

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchFolders()
        setupSearchAndSortHeader()
        // 通常セル用
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        
        // カスタムセル用
        tableView.register(CustomCell.self, forCellReuseIdentifier: CustomCell.reuseID)
        
        loadExpandedState()
        
        // 取得後に展開状態を反映して flattenedFolders を作る
        buildFlattenedFolders()
        
        // テーブルビューをリロード
        tableView.reloadData()
        
    }
    
    //***
    
    // MARK: - 並び替え
    private var tableView = UITableView()
    private var searchBar = UISearchBar()
    private var sortButton: UIButton!
    private var headerStackView: UIStackView!
    private let bottomToolbar = UIToolbar()
    /*enum SortType: Int {
        case order = 0
        case title = 1
        case createdAt = 2
        case currentDate = 3
    }*/
    enum SortType: String {
        case createdAt
        case title
        case currentDate
        case order
    }
    private var currentSort: SortType = {
        if let raw = UserDefaults.standard.string(forKey: "currentSort"),
           let sort = SortType(rawValue: raw) {
            return sort
        }
        return .createdAt
    }() {
        didSet {
            UserDefaults.standard.set(currentSort.rawValue, forKey: "currentSort")
        }
    }

    private var ascending: Bool = {
        if UserDefaults.standard.object(forKey: "ascending") != nil {
            return UserDefaults.standard.bool(forKey: "ascending")
        }
        return true
    }() {
        didSet {
            UserDefaults.standard.set(ascending, forKey: "ascending")
        }
    }

    var selectedFolders: Set<Folder> = []
    var bottomToolbarState: BottomToolbarState = .normal {
        didSet { updateToolbar() }
    }
    var suppressFRCUpdates = false
    
    enum BottomToolbarState {
        case normal, selecting, editing
    }
    var isHideMode = false // ← トグルで切り替え
    
    ///***
    
    private func updateToolbar() {
        switch bottomToolbarState {
        case .normal:
            bottomToolbar.isHidden = false
            let edit = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(startEditing))
            bottomToolbar.setItems([edit], animated: false)
            
        case .selecting:
            bottomToolbar.isHidden = false
            let cancel = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(editCancelEdit))
            bottomToolbar.setItems([cancel], animated: false)
            
        case .editing:
            bottomToolbar.isHidden = false
            let cancel = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(selectCancelEdit))
            if selectedFolders.isEmpty {
                bottomToolbar.setItems([cancel], animated: false)
            } else {
                let transfer = UIBarButtonItem(title: "Transfer", style: .plain, target: self, action: #selector(transferItems))
                bottomToolbar.setItems([cancel, UIBarButtonItem.flexibleSpace(), transfer], animated: false)
            }
        }
    }
    // MARK: - Actions
    @objc private func startEditing() {
        bottomToolbarState = .selecting
        isHideMode = true
        
        tableView.setEditing(true, animated: true)  // ← 編集モードに切り替え
        tableView.reloadData()
    }
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
    
    // MARK: - 並べ替えメニュー生成
    func makeSortMenu() -> UIMenu {
        return UIMenu(title: "並び替え", children: [
            UIAction(title: "作成日", image: UIImage(systemName: "calendar"),
                     state: currentSort == .createdAt ? .on : .off) { [weak self] _ in
                         guard let self = self else { return }
                         self.currentSort = .createdAt
                         self.fetchFolders()
                         // 編集モードを解除
                         self.tableView.setEditing(false, animated: true)
                         if let button = self.sortButton { button.menu = self.makeSortMenu() }
                     },
            
            UIAction(title: "名前", image: UIImage(systemName: "textformat"),
                     state: currentSort == .title ? .on : .off) { [weak self] _ in
                         guard let self = self else { return }
                         self.currentSort = .title
                         self.fetchFolders()
                         self.tableView.setEditing(false, animated: true)
                         if let button = self.sortButton { button.menu = self.makeSortMenu() }
                     },
            
            UIAction(title: "追加日", image: UIImage(systemName: "clock"),
                     state: currentSort == .currentDate ? .on : .off) { [weak self] _ in
                         guard let self = self else { return }
                         self.currentSort = .currentDate
                         self.fetchFolders()
                         self.tableView.setEditing(false, animated: true)
                         if let button = self.sortButton { button.menu = self.makeSortMenu() }
                     },
            // 1. UIAction 内で編集モードに切り替え
            UIAction(title: "順番", image: UIImage(systemName: "list.number"),
                     state: currentSort == .order ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentSort = .order
                
                // fetchFolders() は呼ばない！
                // self.fetchFolders()
                
                // 編集モードを有効化
                tableView.setEditing(true, animated: true)
                tableView.allowsSelectionDuringEditing = true
                
                if let button = self.sortButton {
                    button.menu = self.makeSortMenu()
                }
            },
            
            
            UIAction(title: ascending ? "昇順 (A→Z)" : "降順 (Z→A)",
                     image: UIImage(systemName: "arrow.up.arrow.down")) { [weak self] _ in
                         guard let self = self else { return }
                         self.ascending.toggle()
                         self.fetchFolders()
                         if let button = self.sortButton { button.menu = self.makeSortMenu() }
                     }
        ])
    }
    
    private func setupSearchAndSortHeader() {
        sortButton = UIButton(type: .system)
        sortButton.setTitle("並び替え", for: .normal)
        sortButton.setImage(UIImage(systemName: "arrow.up.arrow.down"), for: .normal)
        sortButton.tintColor = .systemBlue
        sortButton.showsMenuAsPrimaryAction = true
        sortButton.contentHorizontalAlignment = .center
        sortButton.menu = makeSortMenu()
        
        /*searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.placeholder = "フォルダ名を検索"*/
        // MARK: - サーチバーセットアップ
        searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.placeholder = "フォルダ名を検索"
        //navigationItem.titleView = searchBar
        
        // StackViewでまとめる
        headerStackView = UIStackView(arrangedSubviews: [sortButton, searchBar])
        headerStackView.axis = .vertical
        //headerStackView.spacing = 8
        headerStackView.alignment = .fill
        
        // レイアウトを確定させるためframe指定
        headerStackView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 100)
        tableView.tableHeaderView = headerStackView
    }

    // MARK: - UIセットアップ
    private func setupUI() {
        view.backgroundColor = .systemBackground

        // MARK: - サーチバーセットアップ
        /*searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.placeholder = "フォルダ名を検索"
        navigationItem.titleView = searchBar*/

        // MARK: - UITableViewセットアップ
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)

        // MARK: - ナビゲーションバーに「親フォルダ追加」ボタン
        let addParentFolderButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addParentFolder)
        )
        navigationItem.rightBarButtonItem = addParentFolderButton

        //tableView.register(CustomCell.self, forCellReuseIdentifier: CustomCell.reuseID)
    }

    // MARK: - ボタンアクション
    @objc private func addParentFolder() {
        // 新しい親フォルダを作成
        let newFolder = Folder(context: context)
        newFolder.folderName = "新しいフォルダ"
        newFolder.sortIndex = (visibleFlattenedFolders.map { $0.folder.sortIndex }.max() ?? 0) + 1
        newFolder.level = 0  // 親フォルダなのでレベル0

        // Core Data 保存
        do {
            try context.save()
        } catch {
            print("保存に失敗: \(error)")
            return
        }

        // データ反映
        buildVisibleFlattenedFolders() // ← これが visibleFlattenedFolders を再構築する関数なら呼ぶ

        // テーブル更新
        tableView.reloadData()

        print("親フォルダが追加されました: \(newFolder.folderName ?? "")")
    }




    // MARK: - Fetch　frc
    
    private func fetchFolders(predicate: NSPredicate? = nil) {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        
        // sortDescriptors を sortIndex を優先して設定
        let sortKey: String
        switch currentSort {
        case .order:
            sortKey = "sortIndex"
        case .title:
            sortKey = "folderName"
        case .createdAt:
            sortKey = "folderMadeTime"
        case .currentDate:
            sortKey = "currentDate"
        }

        if currentSort == .order {
            // 並び替えモード order のときは sortIndex のみ
            request.sortDescriptors = [NSSortDescriptor(key: "sortIndex", ascending: ascending)]
        } else {
            // その他のモードのときは sortIndex を優先、さらにタイトルや日付でソート
            request.sortDescriptors = [
                NSSortDescriptor(key: "sortIndex", ascending: true),
                NSSortDescriptor(key: sortKey, ascending: ascending)
            ]
        }

        if let predicate = predicate {
            request.predicate = predicate
        }

        fetchedResultsController = NSFetchedResultsController(fetchRequest: request,
                                                              managedObjectContext: context,
                                                              sectionNameKeyPath: nil,
                                                              cacheName: nil)
        fetchedResultsController.delegate = self

        do {
            try fetchedResultsController.performFetch()

            if isSearching {
                groupFoldersByLevel()
            } else {
                buildFlattenedFolders()
            }

            tableView.reloadData()
        } catch {
            print("Fetch failed: \(error)")
        }
    }

    // MARK: - 検索

    // MARK: - 検索時: 階層ごと表示
    
    private func groupFoldersByLevel() {
        guard let folders = fetchedResultsController.fetchedObjects else { return }
        groupedByLevel = Dictionary(grouping: folders, by: { Int64($0.level) })
        sortedLevels = groupedByLevel.keys.sorted()
    }

    // MARK: - 通常時: 展開構造
    
    private func buildFlattenedFolders() {
        guard let allFolders = fetchedResultsController.fetchedObjects else { return }

        var rootFolders = allFolders.filter { $0.parent == nil }

        if currentSort == .order {
            // order モードのときは sortIndex で並び替え
            rootFolders.sort { ($0.sortIndex) < ($1.sortIndex) }
        }

        // flattenedFolders はもう level 付きにする
        visibleFlattenedFolders = flattenWithLevel(nodes: rootFolders)
    }

    private func flattenWithLevel(nodes: [Folder], level: Int = 0) -> [(folder: Folder, level: Int)] {
        var result: [(folder: Folder, level: Int)] = []

        let sortedNodes: [Folder]
        switch currentSort {
        case .order:
            sortedNodes = nodes.sorted { ascending ? $0.sortIndex < $1.sortIndex : $0.sortIndex > $1.sortIndex }
        case .title:
            sortedNodes = nodes.sorted { ascending ? ($0.folderName ?? "") < ($1.folderName ?? "") : ($0.folderName ?? "") > ($1.folderName ?? "") }
        case .createdAt:
            sortedNodes = nodes.sorted { ascending ? ($0.folderMadeTime ?? Date.distantPast) < ($1.folderMadeTime ?? Date.distantPast) : ($0.folderMadeTime ?? Date.distantPast) > ($1.folderMadeTime ?? Date.distantPast) }
        case .currentDate:
            sortedNodes = nodes.sorted { ascending ? ($0.currentDate ?? Date.distantPast) < ($1.currentDate ?? Date.distantPast) : ($0.currentDate ?? Date.distantPast) > ($1.currentDate ?? Date.distantPast) }
        }

        for node in sortedNodes {
            result.append((folder: node, level: level))
            if expandedState[node.uuid] == true, let children = node.children as? Set<Folder> {
                result.append(contentsOf: flattenWithLevel(nodes: Array(children), level: level + 1))
            }
        }

        return result
    }

    private func buildVisibleFlattenedFolders() {
        var result: [(folder: Folder, level: Int)] = []

        func addChildren(of folder: Folder, level: Int) {
            result.append((folder, level))
            
            if expandedState[folder.uuid] ?? false,
               let children = (folder.children as? Set<Folder>)?.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                for child in children {
                    addChildren(of: child, level: level + 1)
                }
            }
        }

        let rootFolders = flattenedFolders.map { $0.folder }.filter { $0.parent == nil }
        for root in rootFolders {
            addChildren(of: root, level: 0)
        }

        visibleFlattenedFolders = result
    }

    func isVisible(_ folder: Folder) -> Bool {
        var parent = folder.parent
        while let p = parent {
            if expandedState[p.uuid] == false { return false }
            parent = p.parent
        }
        return true
    }

    //flatten
    
    // MARK: - Flatten（再帰展開）the flatten
    private func flatten(nodes: [Folder]) -> [Folder] {
        var result: [Folder] = []

        let sortedNodes: [Folder]
        switch currentSort {
        case .order:
            sortedNodes = nodes.sorted { ascending ? $0.sortIndex < $1.sortIndex : $0.sortIndex > $1.sortIndex }
        case .title:
            sortedNodes = nodes.sorted { ascending ? ($0.folderName ?? "") < ($1.folderName ?? "") : ($0.folderName ?? "") > ($1.folderName ?? "") }
        case .createdAt:
            sortedNodes = nodes.sorted { ascending ? ($0.folderMadeTime ?? Date.distantPast) < ($1.folderMadeTime ?? Date.distantPast) : ($0.folderMadeTime ?? Date.distantPast) > ($1.folderMadeTime ?? Date.distantPast) }
        case .currentDate:
            sortedNodes = nodes.sorted { ascending ? ($0.currentDate ?? Date.distantPast) < ($1.currentDate ?? Date.distantPast) : ($0.currentDate ?? Date.distantPast) > ($1.currentDate ?? Date.distantPast) }
        }

        for node in sortedNodes {
            result.append(node)
            if expandedState[node.uuid] == true, let children = node.children as? Set<Folder> {
                let childrenSorted = flatten(nodes: Array(children))
                result.append(contentsOf: childrenSorted)
            }
        }
        return result
    }

    //***デフォルトfunc

    // MARK: - UITableViewDataSource　データソース

    //移動
    

    // 並び替え処理
    func tableView(_ tableView: UITableView,
                   moveRowAt sourceIndexPath: IndexPath,
                   to destinationIndexPath: IndexPath) {
        guard currentSort == .order else { return }

        let coreDataStart = normalBefore.count
        let coreDataEnd = coreDataStart + flattenedFolders.count - 1

        // CoreDataセル範囲外なら何もしない
        if sourceIndexPath.row < coreDataStart || sourceIndexPath.row > coreDataEnd ||
           destinationIndexPath.row < coreDataStart || destinationIndexPath.row > coreDataEnd {
            tableView.reloadData()
            return
        }

        // CoreDataインデックスに変換
        let from = sourceIndexPath.row - coreDataStart
        let to = destinationIndexPath.row - coreDataStart

        // 並べ替え処理
        let moved = flattenedFolders.remove(at: from)
        flattenedFolders.insert(moved, at: to)

        // sortIndex更新
        for (i, tuple) in flattenedFolders.enumerated() {
            tuple.folder.sortIndex = Int64(i)
        }

        // ✅ 保存
        do {
            try context.save()
            print("✅ 並び順を保存しました")
        } catch {
            print("❌ 保存失敗: \(error)")
        }

        // ⚠️ 即fetchFolders()しない！
        // save直後にフェッチし直すと順序がリセットされて見える
    }
    func saveFolderOrder() {
        for (index, tuple) in flattenedFolders.enumerated() {
            tuple.folder.sortIndex = Int64(index)  // CoreData の順番用プロパティ
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to save folder order:", error)
        }
    }
    
    // 削除・挿入ボタンを出さない
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }

    // ハンドルを出すかどうか
    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false // インデント不要
    }

    // 並び替えを許可
    // 並び替え可能セルの指定
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        guard currentSort == .order else { return false }

        // normalBefore
        if indexPath.row < normalBefore.count { return false }

        // CoreDataセル範囲の計算
        let coreDataStart = normalBefore.count
        let coreDataEnd = coreDataStart + flattenedFolders.count - 1

        // normalAfter
        if indexPath.row > coreDataEnd { return false }

        // CoreDataセルのみOK
        return true
    }

    
    
    /*func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        // flattenedFolders の並びを更新
        let movedFolder = flattenedFolders.remove(at: sourceIndexPath.row)
        flattenedFolders.insert(movedFolder, at: destinationIndexPath.row)
        
        // ここで必要なら CoreData の順序も更新
    }*/
    
    //セクション
    

    func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? sortedLevels.count : 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if isSearching {
            let level = sortedLevels[section]
            return "第\(level + 1)階層"
        } else {
            return nil
        }
    }
    
    
    
    let normalBefore = ["Apple", "Orange"]
    let normalAfter = ["Banana"]


    //セル表示
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isSearching {
            // 検索モード: セクションごとの階層表示
            let level = sortedLevels[indexPath.section]
            guard let folders = groupedByLevel[level], indexPath.row < folders.count else {
                return UITableViewCell()
            }
            let folder = folders[indexPath.row]

            let cell = tableView.dequeueReusableCell(withIdentifier: CustomCell.reuseID, for: indexPath) as! CustomCell
            let isExpanded = expandedState[folder.uuid] ?? false
            let hasChildren = (folder.children?.count ?? 0) > 0
            cell.configureCell(
                name: folder.folderName ?? "無題",
                level: Int(folder.level),
                isExpanded: isExpanded,
                hasChildren: hasChildren,
                systemName: "folder",
                tintColor: .systemBlue
            )
            return cell
        } else {
            // 通常モード: normalBefore + visibleFlattenedFolders + normalAfter
            let row = indexPath.row

            if row < normalBefore.count {
                let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
                cell.textLabel?.text = normalBefore[row]
                return cell
            }

            let folderStartIndex = normalBefore.count
            let folderEndIndex = folderStartIndex + visibleFlattenedFolders.count

            if row >= folderStartIndex && row < folderEndIndex {
                let tuple = visibleFlattenedFolders[row - folderStartIndex]
                let folder = tuple.folder   // タプルから Folder を取り出す
                let isExpanded = expandedState[folder.uuid] ?? false
                let hasChildren = (folder.children?.count ?? 0) > 0

                let cell = tableView.dequeueReusableCell(withIdentifier: CustomCell.reuseID, for: indexPath) as! CustomCell
                cell.configureCell(
                    name: folder.folderName ?? "無題",
                    level: Int(folder.level),
                    isExpanded: isExpanded,
                    hasChildren: hasChildren,
                    systemName: "folder",
                    tintColor: .systemBlue
                )

                // 矢印タップのハンドリング
                cell.chevronTapped = { [weak self, weak cell] in
                    guard let self = self, let cell = cell else { return }
                    self.toggleFolder(folder)
                }

                return cell
            }

            let afterIndex = row - folderEndIndex
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.textLabel?.text = normalAfter[afterIndex]
            return cell
        }
    }


    
    
    // MARK: - 開閉
    
    //基本プロパティ
    
    //var expandedState: [NSManagedObjectID: Bool] = [:]
    var expandedState: [UUID: Bool] = [:]
    
    var visibleState: [UUID: Bool] = [:]
    
    //***
    
    // 保存
    private func saveExpandedState() {
        var dict: [String: Bool] = [:]
        for (uuid, isExpanded) in expandedState {
            dict[uuid.uuidString] = isExpanded
        }
        UserDefaults.standard.set(dict, forKey: "expandedState")
    }

    // 復元
    private func loadExpandedState() {
        guard let dict = UserDefaults.standard.dictionary(forKey: "expandedState") as? [String: Bool] else { return }
        var restored: [UUID: Bool] = [:]
        for (uuidString, isExpanded) in dict {
            if let uuid = UUID(uuidString: uuidString) {
                restored[uuid] = isExpanded
            }
        }
        expandedState = restored
    }
    
    //子フォルダの可視制御
    func showChildren(of folder: Folder) {
        // タプルの folder 部分でインデックスを取得
        guard let index = visibleFlattenedFolders.firstIndex(where: { $0.folder == folder }),
              let childrenSet = folder.children as? Set<Folder> else { return }

        // currentSort に従って並び替え
        let children: [Folder]
        switch currentSort {
        case .order:
            children = childrenSet.sorted { ascending ? $0.sortIndex < $1.sortIndex : $0.sortIndex > $1.sortIndex }
        case .title:
            children = childrenSet.sorted { ascending ? ($0.folderName ?? "") < ($1.folderName ?? "") : ($0.folderName ?? "") > ($1.folderName ?? "") }
        case .createdAt:
            children = childrenSet.sorted { ascending ? ($0.folderMadeTime ?? Date.distantPast) < ($1.folderMadeTime ?? Date.distantPast) : ($0.folderMadeTime ?? Date.distantPast) > ($1.folderMadeTime ?? Date.distantPast) }
        case .currentDate:
            children = childrenSet.sorted { ascending ? ($0.currentDate ?? Date.distantPast) < ($1.currentDate ?? Date.distantPast) : ($0.currentDate ?? Date.distantPast) > ($1.currentDate ?? Date.distantPast) }
        }

        // 挿入位置とレベル計算
        let insertIndex = index + 1
        let parentLevel = visibleFlattenedFolders[index].level
        let childrenTuples = children.map { (folder: $0, level: parentLevel + 1) }

        // タプル配列として挿入
        visibleFlattenedFolders.insert(contentsOf: childrenTuples, at: insertIndex)

        // 展開済みなら孫も再帰的に追加
        for child in children where expandedState[child.uuid] == true {
            showChildren(of: child)
        }
    }

    func hideDescendants(of folder: Folder) {
        // タプルの folder 部分でインデックスを取得
        guard let index = visibleFlattenedFolders.firstIndex(where: { $0.folder == folder }),
              let children = folder.children?.allObjects as? [Folder] else { return }

        // 再帰的に子孫を隠す
        for child in children {
            hideDescendants(of: child)
        }

        // visibleFlattenedFolders から子フォルダを削除
        visibleFlattenedFolders.removeAll { tuple in
            children.contains(tuple.folder)
        }
    }
    
    // MARK: - Toggle Folder（展開／折りたたみ）　トグル
    func toggleFolder(_ folder: Folder) {
        let currently = expandedState[folder.uuid] ?? false
        expandedState[folder.uuid] = !currently

        // visibleFlattenedFolders を再構築
        let oldVisible = visibleFlattenedFolders
        buildVisibleFlattenedFolders()
        let newVisible = visibleFlattenedFolders
        let startRow = normalBefore.count

        // 削除行
        var deleteIndexPaths: [IndexPath] = []
        for (i, f) in oldVisible.enumerated() {
            if !newVisible.contains(where: { $0.folder == f.folder }) {
                deleteIndexPaths.append(IndexPath(row: startRow + i, section: 0))
            }
        }

        // 追加行
        var insertIndexPaths: [IndexPath] = []
        for (i, f) in newVisible.enumerated() {
            if !oldVisible.contains(where: { $0.folder == f.folder }) {
                insertIndexPaths.append(IndexPath(row: startRow + i, section: 0))
            }
        }

        tableView.beginUpdates()
        tableView.deleteRows(at: deleteIndexPaths, with: .fade)
        tableView.insertRows(at: insertIndexPaths, with: .fade)
        tableView.endUpdates()

        // 矢印回転
        if let index = newVisible.firstIndex(where: { $0.folder == folder }),
           let cell = tableView.cellForRow(at: IndexPath(row: startRow + index, section: 0)) as? CustomCell {
            cell.rotateChevron(expanded: !currently)
        }

        saveExpandedState()
    }

    // 全子孫を取得
    func allDescendants(of folder: Folder) -> [Folder] {
        guard let children = folder.children?.allObjects as? [Folder] else { return [] }
        var result: [Folder] = []
        for child in children {
            result.append(child)
            result.append(contentsOf: allDescendants(of: child))
        }
        return result
    }

    // 展開状態を考慮して表示すべき子孫を再帰的に取得
    func childrenToShow(for folder: Folder) -> [Folder] {
        guard let children = folder.children?.allObjects as? [Folder] else { return [] }
        var result: [Folder] = []
        let sortedChildren = children.sorted { $0.sortIndex < $1.sortIndex }
        for child in sortedChildren {
            result.append(child)
            if expandedState[child.uuid] == true {
                result.append(contentsOf: childrenToShow(for: child))
            }
        }
        return result
    }

    

    //
    
    // MARK: - UITableViewDelegate　デリゲート

    var sections: [SectionType] = [.normalBefore, .coreData, .normalAfter]
    
    //セクション数
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearching {
            let level = sortedLevels[section]
            return groupedByLevel[level]?.count ?? 0
        } else {
            return normalBefore.count + visibleFlattenedFolders.count + normalAfter.count
        }
    }
    
    //非表示セルは heightForRowAt で高さを0にする
    /*func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.row < flattenedFolders.count else { return 0 }
        let folder = flattenedFolders[indexPath.row]
        let isVisible = visibleState[folder.uuid] ?? true
        return isVisible ? UITableView.automaticDimension : 0
    }*/

    //セルタップ
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !isSearching else { return }

        let row = indexPath.row
        let coreDataStartIndex = normalBefore.count
        let coreDataEndIndex = coreDataStartIndex + visibleFlattenedFolders.count

        if row < normalBefore.count {
            // normalBefore
            print("NormalBefore tapped: \(normalBefore[row])")
            tableView.deselectRow(at: indexPath, animated: true)
        } else if row < coreDataEndIndex {
            // coreData
            let folderIndex = row - coreDataStartIndex
            let folderTuple = visibleFlattenedFolders[folderIndex]
            let folder = folderTuple.folder
            print("CoreData folder tapped: \(folder.folderName ?? "無題")")

            if isHideMode {
                if selectedFolders.contains(folder) {
                    selectedFolders.remove(folder)
                } else {
                    selectedFolders.insert(folder)
                }
                tableView.reloadRows(at: [indexPath], with: .none)
                updateToolbar()
            } else {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        } else {
            // normalAfter
            let afterIndex = row - coreDataEndIndex
            print("NormalAfter tapped: \(normalAfter[afterIndex])")
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    
    
    
    
    

    // MARK: - UISearchBarDelegate　デリゲート

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            isSearching = false
            fetchFolders()
        } else {
            isSearching = true
            let predicate = NSPredicate(format: "folderName CONTAINS[c] %@", searchText)
            fetchFolders(predicate: predicate)
        }
    }
    //***基本プロパティ
    
    var context: NSManagedObjectContext!

    var fetchedResultsController: NSFetchedResultsController<Folder>!

    // 通常時: 展開ツリー
    var flattenedFolders: [(folder: Folder, level: Int)] = []
    var visibleFlattenedFolders: [(folder: Folder, level: Int)] = []
    
    // 検索時: 階層ごとの分類
    var groupedByLevel: [Int64: [Folder]] = [:]
    var sortedLevels: [Int64] = []

    // 状態管理
    var expandedFolders: Set<Folder> = []
    var isSearching: Bool = false
}

// 階層構造管理用
struct FolderNode {
    var folder: Folder
    var level: Int64
}

// CoreDataのFolderにisExpanded追加
extension Folder {
    @objc var isExpanded: Bool {
        get { objc_getAssociatedObject(self, &AssociatedKeys.isExpanded) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &AssociatedKeys.isExpanded, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

private struct AssociatedKeys {
    static var isExpanded = "isExpanded"
}



///***
///
///
///



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
        let folderVC = FolderViewController()
        folderVC.context = self.context
        let nav = UINavigationController(rootViewController: folderVC)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // 必要があれば更新
    }
}


// MARK: - items

enum SectionType {
    case normalBefore
    case coreData
    case normalAfter
}

/*
let normalBefore = ["Apple", "Orange"]
let normalAfter = ["Banana"]

*/
