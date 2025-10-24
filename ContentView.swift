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
        
        loadExpandedState()
        
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

        let item = visibleFlattenedFolders[indexPath.row]
        let folder = item.folder

        // ✅ Core DataのFolderだけスワイプアクションを許可
        guard folder is NSManagedObject else {
            return nil
        }

        // --- 非表示アクション ---
        let hideAction = UIContextualAction(style: .normal, title: "非表示") { [weak self] _, _, completion in
            guard let self = self else { return }

            folder.isHide = true
            try? self.context.save()

            // 配列更新
            self.visibleFlattenedFolders.removeAll { $0.folder.isHide }
            tableView.performBatchUpdates({
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }, completion: { _ in completion(true) })
        }
        hideAction.backgroundColor = .systemGray

        // --- 削除アクション ---
        let deleteAction = UIContextualAction(style: .destructive, title: "削除") { [weak self] _, _, completion in
            guard let self = self else { return }

            self.context.delete(folder)
            try? self.context.save()

            self.visibleFlattenedFolders.remove(at: indexPath.row)
            tableView.performBatchUpdates({
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }, completion: { _ in completion(true) })
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
        
        let item = flattenedFolders[indexPath.row]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self = self else {
                return UIMenu(title: "", children: [])
            }

            // フォルダ追加アクション
            let addFolder = UIAction(title: "フォルダ追加", image: UIImage(systemName: "folder.badge.plus")) { _ in
                self.presentAddFolderAlert(parent: item) // ← ここで呼ぶ
            }

            // 選択/トグルアクション
            let selectAction = UIAction(
                title: self.selectedFolders.contains(item) ? "選択解除" : "選択",
                image: UIImage(systemName: self.selectedFolders.contains(item) ? "checkmark.circle.fill" : "checkmark.circle")
            ) { _ in
                guard let index = self.flattenedFolders.firstIndex(of: item) else { return }
                let indexPath = IndexPath(row: index, section: 0)

                if self.selectedFolders.contains(item) {
                    // 選択解除
                    self.selectedFolders.remove(item)
                    tableView.deselectRow(at: indexPath, animated: true)
                } else {
                    // 選択
                    self.selectedFolders.insert(item)
                    tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                }

                self.isSelecting = true
                self.bottomToolbarState = .selecting
                self.updateToolbar()
            }

            // 削除アクション
            let delete = UIAction(title: "削除", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.delete(item)
            }

            return UIMenu(title: "", children: [addFolder, selectAction, delete])
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
    // MARK: - Flatten
    private func flatten(nodes: [Folder]) -> [Folder] {
        var result: [Folder] = []

        let sortedNodes = nodes.sorted(by: sortClosure)
        
        for node in sortedNodes {
            result.append(node)
            
            if expandedState[node.uuid] == true, let children = node.children as? Set<Folder>, !children.isEmpty {
                let childrenFlattened = flatten(nodes: Array(children))
                result.append(contentsOf: childrenFlattened)
            }
        }
        return result
    }

    // MARK: - Sort closure
    private var sortClosure: (Folder, Folder) -> Bool {
        return { [self] lhs, rhs in  // selfをキャプチャ
            switch self.currentSort {
            case .order:
                return self.ascending ? lhs.sortIndex < rhs.sortIndex : lhs.sortIndex > rhs.sortIndex
            case .title:
                return self.ascending ? (lhs.folderName ?? "") < (rhs.folderName ?? "") : (lhs.folderName ?? "") > (rhs.folderName ?? "")
            case .createdAt:
                return self.ascending ? (lhs.folderMadeTime ?? Date.distantPast) < (rhs.folderMadeTime ?? Date.distantPast) : (lhs.folderMadeTime ?? Date.distantPast) > (rhs.folderMadeTime ?? Date.distantPast)
            case .currentDate:
                return self.ascending ? (lhs.currentDate ?? Date.distantPast) < (rhs.currentDate ?? Date.distantPast) : (lhs.currentDate ?? Date.distantPast) > (rhs.currentDate ?? Date.distantPast)
            }
        }
    }

    // MARK: - Visible array 更新
    private func buildVisibleFlattenedFolders() {
        if isSearching, let keywords = searchBar.text, !keywords.isEmpty {
            // 検索フィルターを適用
            visibleFlattenedFolders = flattenedFolders
                .filter { $0.folderName?.localizedCaseInsensitiveContains(keywords) ?? false }
                .map { (folder: $0, level: 0) } // レベルは仮で0に
        } else {
            visibleFlattenedFolders = flattenedFolders
                .map { (folder: $0, level: 0) } // すべてのフォルダをレベル0として扱う
        }
        tableView.reloadData()
    }

    // MARK: - 削除/非表示後に呼ぶ
    private func refreshAfterChange() {
        guard let allFolders = fetchedResultsController.fetchedObjects else { return }
        let rootFolders = allFolders.filter { $0.parent == nil }
        flattenedFolders = flatten(nodes: rootFolders)
        buildVisibleFlattenedFolders()
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
                tintColor: .systemBlue,
                isEditMode: isHideMode,      // 編集モードかどうか
                isHide: folder.isHide         // フォルダの非表示状態
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
                let folder = tuple.folder // タプルから Folder を取り出す
                let level = tuple.level

                let isExpanded = expandedState[folder.uuid] ?? false
                let hasChildren = (folder.children?.count ?? 0) > 0

                let cell = tableView.dequeueReusableCell(withIdentifier: CustomCell.reuseID, for: indexPath) as! CustomCell
                cell.configureCell(
                    name: folder.folderName ?? "無題",
                    level: Int(level),   // タプルから取得した level を使う
                    isExpanded: isExpanded,
                    hasChildren: hasChildren,
                    systemName: "folder",
                    tintColor: .systemBlue,
                    isEditMode: isHideMode,
                    isHide: folder.isHide
                )

                // 選択状態
                let isSelected = selectedFolders.contains(folder)
                cell.updateSelectionAppearance(isSelected: isSelected)

                cell.chevronTapped = { [weak self] in
                    self?.toggleFolder(folder)
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

        // タプルとして挿入する（level は現在の folder の level + 1）
        let insertIndex = index + 1
        let childrenTuples = children.map { (folder: $0, level: visibleFlattenedFolders[index].level + 1) }
        visibleFlattenedFolders.insert(contentsOf: childrenTuples, at: insertIndex)

        // 展開済みなら孫も再帰的に追加
        for child in children where expandedState[child.uuid] == true {
            showChildren(of: child)
        }
    }

    func hideDescendants(of folder: Folder) {
        // visibleFlattenedFolders の中から folder に一致するインデックスを探す
        guard let index = visibleFlattenedFolders.firstIndex(where: { $0.folder == folder }),
              let children = folder.children?.allObjects as? [Folder] else { return }

        for child in children {
            hideDescendants(of: child)
        }

        // タプルの folder が children に含まれるものを削除
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

        if row < normalBefore.count {
            // normalBefore
            //print("NormalBefore tapped: \(normalBefore[row])")
            tableView.deselectRow(at: indexPath, animated: true)

        } else if row < coreDataEndIndex {
            // coreData
            let folderIndex = row - coreDataStartIndex
            let folder = flattenedFolders[folderIndex]
            //print("CoreData folder tapped: \(folder.folderName ?? "無題")")

            if isSelecting {
                // 選択モード時: トグル選択
                if selectedFolders.contains(folder) {
                    selectedFolders.remove(folder)
                    if selectedFolders.isEmpty {
                        self.isSelecting = false
                        bottomToolbarState = .normal
                    }
                    print("Removed folder: \(folder)")
                } else {
                    selectedFolders.insert(folder)
                    print("Added folder: \(folder)")
                }
                
                tableView.reloadRows(at: [indexPath], with: .none)
                updateToolbar()
                
            } else {
                // 通常タップ: フォルダを開く
            }

        } else {
            // normalAfter
            let afterIndex = row - coreDataEndIndex
            print("NormalAfter tapped: \(normalAfter[afterIndex])")
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    //選択／解除トグル
    func toggleSelection(for folder: Folder, at indexPath: IndexPath) {
        if selectedFolders.contains(folder) {
            selectedFolders.remove(folder)
            print("Removed folder: \(folder.folderName ?? "無題")")
            if selectedFolders.isEmpty {
                self.isSelecting = false
                self.bottomToolbarState = .normal
            }
        } else {
            selectedFolders.insert(folder)
            print("Added folder: \(folder.folderName ?? "無題")")
        }

        print("Current selectedFolders count: \(selectedFolders.count)")

        print("Selected folders:")
        for f in selectedFolders {
            print(" - \(f.folderName ?? "無題")")
        }

        // セルの背景色を更新
        if let cell = tableView.cellForRow(at: indexPath) as? CustomCell {
            cell.updateSelectionAppearance(isSelected: selectedFolders.contains(folder))
        }

        // その他 UI 更新
        updateToolbar()
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
    // ContentView などのクラスで
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
