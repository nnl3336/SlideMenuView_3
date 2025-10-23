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
        
        
        
        // 取得後に展開状態を反映して flattenedFolders を作る
        buildFlattenedFolders()
        
        //***
        //showBottomToolbar() // MARK: - 下部表示
        
        setupToolbar()
        updateToolbar()
        
        // テーブルビューをリロード
        tableView.reloadData()
        
    }
    
    //***
    
    // MARK: - スワイプアクション

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        let item = visibleFlattenedFolders[indexPath.row]  // item は (folder: Folder, level: Int) タプル
        let folder = item.folder  // folder 本体を取り出す

        // 非表示アクション
        let hideAction = UIContextualAction(style: .normal, title: "非表示") { [weak self] action, view, completion in
            guard let self = self else { return }

            folder.isHide = true  // タプルから folder を取り出して操作

            self.buildVisibleFlattenedFolders()

            tableView.performBatchUpdates({
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }, completion: { _ in
                completion(true)
            })
        }
        hideAction.backgroundColor = .systemGray

        // 削除アクション
        let deleteAction = UIContextualAction(style: .destructive, title: "削除") { [weak self] action, view, completion in
            guard let self = self else { return }

            // flattenedFolders から削除
            if let index = self.flattenedFolders.firstIndex(where: { $0.parent == folder }) {
                self.flattenedFolders.remove(at: index)
            }

            self.buildVisibleFlattenedFolders()

            tableView.deleteRows(at: [indexPath], with: .automatic)

            completion(true)
        }

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, hideAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    

    
    // MARK: - ツールバー
    
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
    
    // MARK: - アップデート
    
    private func updateToolbar() {
            switch bottomToolbarState {
            case .normal:
                bottomToolbar.isHidden = false
                let edit = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(startEditing))
                bottomToolbar.setItems([edit], animated: false)

            case .editing:
                bottomToolbar.isHidden = false
                let edit = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(editCancelEdit))
                bottomToolbar.setItems([edit], animated: false)

            case .selecting:
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

    //Actions
    
    @objc private func startEditing() {
        bottomToolbarState = .editing
        isHideMode = true
        tableView.reloadData() // ←ここが重要
    }

    @objc private func selectCancelEdit() {
        isSelecting = false
        // 選択アイテムをクリア
        //selectedItems.removeAll()
        selectedFolders.removeAll()
        
        // bottomToolbarState を通常に戻す
        bottomToolbarState = .normal
        
        // テーブルの選択状態もリセット
        tableView.reloadData()
        
        //
        updateToolbar()
    }

    @objc private func editCancelEdit() {
        isHideMode = false
        // 選択アイテムをクリア
        //selectedItems.removeAll()
        selectedFolders.removeAll()
        
        // bottomToolbarState を通常に戻す
        bottomToolbarState = .normal
        
        // テーブルの選択状態もリセット
        tableView.reloadData()
        
        //
        updateToolbar()
    }
    
    
    
    // MARK: - コンテキストメニュー　.contextMenu
    
    //基本プロパティ
    
    //private var selectedItems = Set<Folder>()
    var isSelecting: Bool = false
    
    //***
    
    func tableView(_ tableView: UITableView,
                   contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {
        
        guard indexPath.row < visibleFlattenedFolders.count else {
            print("⚠️ indexPath.row \(indexPath.row) is out of range (count: \(visibleFlattenedFolders.count))")
            return nil
        }
        
        let item = visibleFlattenedFolders[indexPath.row]

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self = self else {
                return UIMenu(title: "", children: [])
            }

            // ✅ フォルダ追加アクション
            // ここは以前のコードで addFolder が定義されていればそのまま

            // 選択/トグルアクション
            let selectAction = UIAction(
                title: self.selectedFolders.contains(item.folder) ? "選択解除" : "選択",
                image: UIImage(systemName: self.selectedFolders.contains(item.folder) ? "checkmark.circle.fill" : "checkmark.circle")
            ) { _ in
                guard let index = self.flattenedFolders.firstIndex(of: item.folder) else { return }
                let indexPath = IndexPath(row: index, section: 0)

                if self.selectedFolders.contains(item.folder) {
                    // 選択解除
                    self.selectedFolders.remove(item.folder)
                    tableView.deselectRow(at: indexPath, animated: true)
                } else {
                    // 選択
                    self.selectedFolders.insert(item.folder)
                    tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                }

                self.isSelecting = true
                self.bottomToolbarState = .selecting
                self.updateToolbar()
            }

            // 削除アクション
            let delete = UIAction(title: "削除", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.delete(item.folder)
            }

            return UIMenu(title: "", children: [/* addFolder?, */ selectAction, delete])
        }
    }
    // MARK: - 子フォルダ追加
    func addChildFolder(parent: Folder, name: String) {
        let newFolder = Folder(context: context)
        newFolder.folderName = name
        newFolder.id = UUID()
        newFolder.folderMadeTime = Date()
        newFolder.currentDate = Date()
        newFolder.level = parent.level + 1
        newFolder.parent = parent
        newFolder.sortIndex = Int64(parent.children?.count ?? 0)

        do {
            try context.save()
            fetchFolders()
        } catch {
            print("❌ フォルダ作成エラー: \(error)")
        }
    }
    /*func toggleSelection(at indexPath: IndexPath, in tableView: UITableView) {
        let item = flattenedFolders[indexPath.row]
        
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
        
        // セルのチェックマーク更新
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.accessoryType = selectedItems.contains(item) ? .checkmark : .none
        }
    }*/
    func delete(_ item: Folder) {
        context.delete(item)
        do {
            try context.save()
            fetchFolders()
        } catch {
            print("❌ フォルダ削除エラー: \(error)")
        }
    }
    func presentAddFolderAlert(parent: Folder) {
        let alert = UIAlertController(title: "フォルダ名を入力", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "新しいフォルダ名"
        }

        let addAction = UIAlertAction(title: "追加", style: .default) { [weak self] _ in
            guard let self = self else { return }
            guard let folderName = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces), !folderName.isEmpty else {
                self.presentWarningAlert(message: "フォルダ名を入力してください")
                return
            }
            self.addChildFolder(parent: parent, name: folderName)
        }

        let cancelAction = UIAlertAction(title: "キャンセル", style: .cancel)

        alert.addAction(addAction)
        alert.addAction(cancelAction)

        self.present(alert, animated: true)
    }

    func presentWarningAlert(message: String) {
        let warning = UIAlertController(title: "無効な名前", message: message, preferredStyle: .alert)
        warning.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(warning, animated: true)
    }

    
    
    // MARK: - //並び替え
    
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

    var selectedFolders: Set<Folder> = [] {
        didSet {
            
        }
    }
    var bottomToolbarState: BottomToolbarState = .normal {
        didSet { updateToolbar() }
    }
    var suppressFRCUpdates = false
    
    enum BottomToolbarState {
        case normal, selecting, editing
    }
    var isHideMode = false // ← トグルで切り替え
    
    ///***
    
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
        for (i, folder) in flattenedFolders.enumerated() {
            folder.sortIndex = Int64(i)
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
        for (index, folder) in flattenedFolders.enumerated() {
            folder.sortIndex = Int64(index)  // CoreData の順番用プロパティ
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to save folder order:", error)
        }
    }
    ///
    @objc private func transferItems() {
        // 選択アイテムの転送処理
        //delegate?.didToggleBool_TransferModal(true)
        
        // 選択をクリア
        selectedFolders.removeAll()
        
        // テーブルの選択状態もリセット
        tableView.reloadData()
        
        // 通常に戻す
        bottomToolbarState = .normal
        updateToolbar()
    }
    
    //並べ替えメニュー生成
    
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
    
    //ナビゲーションバー
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
        
        //tableView.register(CustomCell.self, forCellReuseIdentifier: CustomCell.reuseID)
        // 通常セル用
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        // カスタムセル用
        tableView.register(CustomCell.self, forCellReuseIdentifier: CustomCell.reuseID)
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
        let rootFolders = allFolders.filter { $0.parent == nil }
        flattenedFolders = flatten(nodes: rootFolders)
        buildVisibleFlattenedFolders()
    }

    private func buildVisibleFlattenedFolders() {
        visibleFlattenedFolders = []

        func addFolder(_ folder: Folder, level: Int) {
            folder.level = Int64(level)
            visibleFlattenedFolders.append((folder: folder, level: level)) // ←タプルにする

            if folder.isExpanded {
                if let children = folder.children as? Set<Folder> {
                    let sortedChildren = children.sorted { ($0.folderName ?? "") < ($1.folderName ?? "") }
                    for child in sortedChildren {
                        addFolder(child, level: level + 1)
                    }
                }
            }
        }

        for folder in flattenedFolders where folder.parent == nil {
            addFolder(folder, level: 0)
        }
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
    
    //基本プロパティ
    
    let normalBefore = ["Apple", "Orange"]
    let normalAfter = ["Banana"]

    //移動
    
    /*func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        // flattenedFolders の並びを更新
        let movedFolder = flattenedFolders.remove(at: sourceIndexPath.row)
        flattenedFolders.insert(movedFolder, at: destinationIndexPath.row)
        
        // ここで必要なら CoreData の順序も更新
    }*/
    
    //セクション
    
    //セクション数
    func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? sortedLevels.count : 1
    }
    
    //セクションヘッダー
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if isSearching {
            let level = sortedLevels[section]
            return "第\(level + 1)階層"
        } else {
            return nil
        }
    }

    //セル表示
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let folder: Folder
        let level: Int

        if isSearching {
            // 検索モード
            let searchLevel = sortedLevels[indexPath.section]
            guard let folders = groupedByLevel[searchLevel], indexPath.row < folders.count else {
                return UITableViewCell()
            }
            folder = folders[indexPath.row]
            level = Int(folder.level)
        } else {
            // 通常モード
            guard indexPath.row < visibleFlattenedFolders.count else {
                print("⚠️ indexPath.row out of range:", indexPath.row, "count:", visibleFlattenedFolders.count)
                return UITableViewCell()
            }
            (folder, level) = visibleFlattenedFolders[indexPath.row]
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: CustomCell.reuseID, for: indexPath) as! CustomCell
        let isExpanded = expandedState[folder.uuid] ?? false
        let hasChildren = (folder.children?.count ?? 0) > 0

        cell.configureCell(
            name: folder.folderName ?? "無題",
            level: level,
            isExpanded: isExpanded,
            hasChildren: hasChildren,
            systemName: "folder",
            tintColor: .systemBlue,
            isEditMode: isHideMode,
            isHide: folder.isHide
        )

        // 編集モード時のハンドル表示
        cell.showsReorderControl = tableView.isEditing

        return cell
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
        // タプルの folder で検索
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

        let parentLevel = visibleFlattenedFolders[index].level
        let insertIndex = index + 1

        // 子をタプル (folder, level) として挿入
        let childrenTuples = children.map { (folder: $0, level: parentLevel + 1) }
        visibleFlattenedFolders.insert(contentsOf: childrenTuples, at: insertIndex)

        // 展開済みなら孫も再帰的に追加
        for child in children where expandedState[child.uuid] == true {
            showChildren(of: child)
        }
    }

    func hideDescendants(of folder: Folder) {
        // 見つけるのも削除するのもタプルの folder で行う
        guard let index = visibleFlattenedFolders.firstIndex(where: { $0.folder == folder }),
              let children = folder.children?.allObjects as? [Folder] else { return }

        for child in children {
            hideDescendants(of: child)
        }

        // visibleFlattenedFolders から該当する子フォルダを削除
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
    
    // MARK: - //UITableViewDelegate　//デリゲート

    var sections: [SectionType] = [.normalBefore, .coreData, .normalAfter]
    
    //セル個数
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
        let coreDataEndIndex = coreDataStartIndex + flattenedFolders.count

        print("Tapped row: \(row)")
        print("normalBefore.count = \(normalBefore.count), flattenedFolders.count = \(flattenedFolders.count), normalAfter.count = \(normalAfter.count)")
        print("coreData range: \(coreDataStartIndex) ..< \(coreDataEndIndex)")

        if row < normalBefore.count {
            print("→ normalBefore tapped: \(normalBefore[row])")
            tableView.deselectRow(at: indexPath, animated: true)

        } else if row < coreDataEndIndex {
            let folderIndex = row - coreDataStartIndex

            // 範囲チェック
            guard folderIndex >= 0 && folderIndex < flattenedFolders.count else {
                print("⚠️ folderIndex out of range: \(folderIndex)")
                return
            }

            let folder = flattenedFolders[folderIndex]
            print("→ CoreData folder tapped: \(folder.folderName ?? "無題") index: \(folderIndex)")

            if isSelecting {
                if selectedFolders.contains(folder) {
                    selectedFolders.remove(folder)
                    if selectedFolders.isEmpty {
                        self.isSelecting = false
                        bottomToolbarState = .normal
                    }
                    print("Removed folder: \(folder.folderName ?? "")")
                } else {
                    selectedFolders.insert(folder)
                    print("Added folder: \(folder.folderName ?? "")")
                }

                tableView.reloadRows(at: [indexPath], with: .none)
                updateToolbar()
            } else {
                // 通常タップ: フォルダを開く
                print("Opening folder: \(folder.folderName ?? "")")
            }

        } else {
            let afterIndex = row - coreDataEndIndex
            guard afterIndex >= 0 && afterIndex < normalAfter.count else {
                print("⚠️ afterIndex out of range: \(afterIndex)")
                return
            }
            print("→ normalAfter tapped: \(normalAfter[afterIndex])")
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    //選択／解除トグル
    func toggleFolder(_ folder: Folder) {
        let currently = expandedState[folder.uuid] ?? false
        expandedState[folder.uuid] = !currently

        // oldVisible を保持
        let oldVisible = visibleFlattenedFolders

        // visibleFlattenedFolders を再構築
        buildVisibleFlattenedFolders()
        let newVisible = visibleFlattenedFolders

        // normalBefore / normalAfter を更新
        normalBefore = oldVisible
        normalAfter = newVisible

        // UITableView の更新
        updateTableView(oldVisible: oldVisible, newVisible: newVisible)

        saveExpandedState()
    }
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
    var flattenedFolders: [Folder] = []                  // 全フォルダ
    /*var visibleFlattenedFolders: [Folder] = []*/          // 表示用
    // Folder と階層レベルをペアで保持
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
