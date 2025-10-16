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
class FolderViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate, UISearchBarDelegate {
    
    //***
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        
        let savedSortRaw = UserDefaults.standard.integer(forKey: "currentSort")
        currentSort = SortType(rawValue: savedSortRaw) ?? .createdAt
        
        ascending = UserDefaults.standard.bool(forKey: "ascending")
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        bottomToolbar.translatesAutoresizingMaskIntoConstraints = false
        
        ///
        
        setupTableView()
        
        setupSearchAndSortHeader()
        setupToolbar()
        
        setupFRC()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(addFolder)
        )
        setupNormalFRC()//通常モード用 NSFetchedResultsController
        setupSearchFRC()//検索モード用 NSFetchedResultsController
        
        // 初期状態は通常モード
        activeFRC = normalFRC
        
        //
        
        if let objects = fetchedResultsController.fetchedObjects {
            flatData = flattenFolders(objects.filter { $0.parent == nil })
            tableView.reloadData()
        }
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomToolbar.topAnchor),
            
            bottomToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }
    
    //***
    
    // MARK: - 検索
    
    //🔄 通常・検索切り替え（UISearchBarDelegate）
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            // 通常モードに戻す
            activeFRC = normalFRC
            tableView.reloadData()
            return
        }
        
        // 検索モードに切替
        searchFRC.fetchRequest.predicate = NSPredicate(format: "folderName CONTAINS[cd] %@", searchText)
        do {
            try searchFRC.performFetch()
            activeFRC = searchFRC
            tableView.reloadData()
        } catch {
            print("Search failed: \(error)")
        }
    }
    
    // MARK: - frc
    func setupSearchFRC() {
        let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "level", ascending: true),
            NSSortDescriptor(key: "folderName", ascending: true)
        ]
        
        // 初期状態はpredicateなし（あとで検索バー入力で更新）
        searchFRC = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: "level", // 階層ごとにセクション分割
            cacheName: nil
        )
        searchFRC.delegate = self
        
        do {
            try normalFRC.performFetch()
        } catch {
            print("Normal FRC fetch failed: \(error)")
        }
    }
    
    func setupNormalFRC() {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "folderMadeTime", ascending: true)]
        
        normalFRC = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        normalFRC.delegate = self
        
        do {
            try normalFRC.performFetch()
        } catch {
            print("Normal FRC fetch failed: \(error)")
        }
    }
    
    
    // MARK: - 階層Folder
    
    //セクションヘッダー
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if isSearching {
            let level = sortedLevels[section]
            return "第\(level + 1)階層"
        } else {
            return nil // 通常時はヘッダーなし
        }
    }
    
    //UITableViewDelegate コンテキストメニュー
    func tableView(_ tableView: UITableView,
                   contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {
        
        // セクション1 (coreData) のみ対象
        guard indexPath.section == 1 else { return nil }
        
        let folder = flatData[indexPath.row].folder
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let addChild = UIAction(title: "子フォルダ追加", image: UIImage(systemName: "folder.badge.plus")) { [weak self] _ in
                self?.addChildFolder(to: folder)
            }
            return UIMenu(title: "", children: [addChild])
        }
    }
    private func addChildFolder(to parentFolder: Folder) {
        let alert = UIAlertController(title: "子フォルダ", message: "名前を入力してください", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "フォルダ名" }
        
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.addAction(UIAlertAction(title: "追加", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let name = alert.textFields?.first?.text ?? "無題"
            
            let newFolder = Folder(context: self.context)
            newFolder.folderName = name
            
            // 子フォルダの sortIndex 計算
            let children = (parentFolder.children as? Set<Folder>) ?? []
            let maxSortIndex = children.map { $0.sortIndex }.max() ?? -1
            newFolder.sortIndex = maxSortIndex + 1
            newFolder.parent = parentFolder
            
            do { try self.context.save() } catch { print(error) }
            // NSFetchedResultsController が自動で controllerDidChangeContent を呼ぶ
        }))
        
        present(alert, animated: true)
    }
    
    //矢印タップのfunc
    func chevronTapped(for folder: Folder, cell: CustomCell) {
        // 現在の展開状態
        let isExpanded = expandedState[ObjectIdentifier(folder)] ?? false
        // トグルする
        expandedState[ObjectIdentifier(folder)] = !isExpanded
        
        // アニメーション開始
        tableView.beginUpdates()
        
        if isExpanded {
            // 折りたたみ: 全ての子孫を削除
            let childrenToRemove = visibleChildrenForExpand(of: folder)
            let startIndex = flatData.firstIndex(where: { $0.folder == folder })! + 1
            let endIndex = startIndex + childrenToRemove.count
            if endIndex <= flatData.count {
                flatData.removeSubrange(startIndex..<endIndex)
                let indexPaths = (0..<childrenToRemove.count).map { IndexPath(row: startIndex + $0, section: 1) }
                tableView.deleteRows(at: indexPaths, with: .fade)
            }
        } else {
            // 展開: 直下の子だけを挿入
            let children = (folder.children?.allObjects as? [Folder])?.sorted(by: { $0.sortIndex < $1.sortIndex }) ?? []
            let startIndex = flatData.firstIndex(where: { $0.folder == folder })! + 1
            let childrenToInsert = children.map { (folder: $0, level: getLevel(of: $0)) }
            flatData.insert(contentsOf: childrenToInsert, at: startIndex)
            let indexPaths = (0..<childrenToInsert.count).map { IndexPath(row: startIndex + $0, section: 1) }
            tableView.insertRows(at: indexPaths, with: .fade)
        }
        
        // 矢印回転
        cell.rotateChevron(expanded: !isExpanded)
        
        tableView.endUpdates()
    }
    
    
    private func flatten(folders: [Folder], level: Int = 0) -> [(folder: Folder, level: Int)] {
        var result: [(folder: Folder, level: Int)] = []
        for folder in folders {
            result.append((folder, level))
            if let children = folder.children?.allObjects as? [Folder] {
                // 子フォルダも階層を +1 して再帰
                result.append(contentsOf: flatten(folders: children, level: level + 1))
            }
        }
        return result
    }
    
    // MARK: - Step 1: モデル定義　基本プロパティ
    class FolderNode: Equatable {
        let id: UUID
        let name: String
        var children: [FolderNode]
        var level: Int
        
        // イニシャライザを追加
        init(id: UUID = UUID(), name: String, children: [FolderNode] = [], level: Int = 0) {
            self.id = id
            self.name = name
            self.children = children
            self.level = level
        }
        
        // Equatable準拠
        static func == (lhs: FolderNode, rhs: FolderNode) -> Bool {
            return lhs.id == rhs.id
        }
    }
    enum SectionType {
        case normalBefore
        case coreData
        case normalAfter
    }
    var rootNodes: [FolderNode] = []
    var groupedCoreData: [Int: [FolderNode]] = [:]
    var sortedLevels: [Int] = []
    
    var isSearching = false
    
    let normalBefore = ["Apple", "Orange"]
    let normalAfter = ["Banana"]
    
    
    // MARK: - Step 2: ダミーデータ
    
    
    // MARK: - Step 3: flattenしてlevelを付与
    // FolderNodeを削除して、Folderを直接使う
    func flattenWithLevel(nodes: [FolderNode], level: Int = 0) -> [(node: FolderNode, level: Int)] {
        var result: [(node: FolderNode, level: Int)] = []
        for node in nodes {
            result.append((node, level))
            result.append(contentsOf: flattenWithLevel(nodes: node.children, level: level + 1))
        }
        return result
    }
    // MARK: - Step 4: 検索して階層ごとに分類
    func search(nodes: [FolderNode], query: String) -> [Int: [FolderNode]] {
        let all = flattenWithLevel(nodes: nodes)
        let filtered = all.filter { $0.node.name.localizedCaseInsensitiveContains(query) }
        let grouped = Dictionary(grouping: filtered.map { $0.node }, by: { $0.level })
        return grouped
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange anObject: Any,
                    at indexPath: IndexPath?,
                    for type: NSFetchedResultsChangeType,
                    newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            if let newIndexPath = newIndexPath {
                tableView.insertRows(at: [newIndexPath], with: .automatic)
            }
        case .delete:
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        case .update:
            if let indexPath = indexPath {
                let folder = controller.object(at: indexPath) as! Folder
                if let cell = tableView.cellForRow(at: indexPath) {
                    cell.textLabel?.text = folder.folderName
                }
            }
        case .move:
            if let indexPath = indexPath, let newIndexPath = newIndexPath {
                tableView.moveRow(at: indexPath, to: newIndexPath)
            }
        @unknown default:
            break
        }
    }
    
    
    
    
    
    // MARK: - Step 5: TableViewController
    
    
    // MARK: - Add Folder　フォルダ追加
    @objc private func addFolder() {
        let alert = UIAlertController(title: "新しいフォルダ", message: "名前を入力してください", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "フォルダ名" }
        
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.addAction(UIAlertAction(title: "追加", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let name = alert.textFields?.first?.text ?? "無題"
            let newFolder = Folder(context: self.context)
            newFolder.folderName = name
            newFolder.sortIndex = (self.flatData.last?.folder.sortIndex ?? -1) + 1
            
            do { try self.context.save() } catch { print(error) }
            // FRC が自動で controllerDidChangeContent を呼ぶ
        }))
        
        present(alert, animated: true)
    }
    
    // MARK: - Setup TableView
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(CustomCell.self, forCellReuseIdentifier: CustomCell.reuseID)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        view.addSubview(tableView)
    }
    
    // MARK: - Header (Search + Sort)
    private func setupSearchAndSortHeader() {
        sortButton = UIButton(type: .system)
        sortButton.setTitle("並び替え", for: .normal)
        sortButton.setImage(UIImage(systemName: "arrow.up.arrow.down"), for: .normal)
        sortButton.tintColor = .systemBlue
        sortButton.showsMenuAsPrimaryAction = true
        sortButton.contentHorizontalAlignment = .center
        sortButton.menu = makeSortMenu()
        
        searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.placeholder = "フォルダ名を検索"
        
        // StackViewでまとめる
        headerStackView = UIStackView(arrangedSubviews: [sortButton, searchBar])
        headerStackView.axis = .vertical
        headerStackView.spacing = 8
        headerStackView.alignment = .fill
        
        // レイアウトを確定させるためframe指定
        headerStackView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 100)
        tableView.tableHeaderView = headerStackView
    }
    
    // MARK: - 並べ替えメニュー生成
    func makeSortMenu() -> UIMenu {
        return UIMenu(title: "並び替え", children: [
            UIAction(title: "作成日", image: UIImage(systemName: "calendar"),
                     state: currentSort == .createdAt ? .on : .off) { [weak self] _ in
                         guard let self = self else { return }
                         self.currentSort = .createdAt
                         self.setupFRC()
                         // 編集モードを解除
                         self.tableView.setEditing(false, animated: true)
                         if let button = self.sortButton { button.menu = self.makeSortMenu() }
                     },
            
            UIAction(title: "名前", image: UIImage(systemName: "textformat"),
                     state: currentSort == .title ? .on : .off) { [weak self] _ in
                         guard let self = self else { return }
                         self.currentSort = .title
                         self.setupFRC()
                         self.tableView.setEditing(false, animated: true)
                         if let button = self.sortButton { button.menu = self.makeSortMenu() }
                     },
            
            UIAction(title: "追加日", image: UIImage(systemName: "clock"),
                     state: currentSort == .currentDate ? .on : .off) { [weak self] _ in
                         guard let self = self else { return }
                         self.currentSort = .currentDate
                         self.setupFRC()
                         self.tableView.setEditing(false, animated: true)
                         if let button = self.sortButton { button.menu = self.makeSortMenu() }
                     },
            // 1. UIAction 内で編集モードに切り替え
            UIAction(title: "順番", image: UIImage(systemName: "list.number"),
                     state: currentSort == .order ? .on : .off) { [weak self] _ in
                         guard let self = self else { return }
                         self.currentSort = .order
                         self.setupFRC()
                         
                         // 編集モードに切り替え（ハンドルが出る）
                         // 編集モードにしても削除は不可、ハンドルのみ表示
                         tableView.setEditing(currentSort == .order, animated: true)
                         tableView.allowsSelectionDuringEditing = true // 選択も可能
                         // メニュー更新
                         if let button = self.sortButton { button.menu = self.makeSortMenu() }
                     },
            
            
            UIAction(title: ascending ? "昇順 (A→Z)" : "降順 (Z→A)",
                     image: UIImage(systemName: "arrow.up.arrow.down")) { [weak self] _ in
                         guard let self = self else { return }
                         self.ascending.toggle()
                         self.setupFRC()
                         if let button = self.sortButton { button.menu = self.makeSortMenu() }
                     }
        ])
    }
    
    var isHideMode = false // ← トグルで切り替え
    
    // MARK: - Bottom Toolbar
    private func setupToolbar() {
        bottomToolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomToolbar)
        
        NSLayoutConstraint.activate([
            bottomToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomToolbar.heightAnchor.constraint(equalToConstant: 44)
        ])
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
        tableView.reloadData() // ←ここが重要
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
    
    // MARK: - FRC
    private func setupFRC() {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        
        switch currentSort {
        case .order:
            request.sortDescriptors = [NSSortDescriptor(key: "sortIndex", ascending: ascending)]
        case .title:
            request.sortDescriptors = [NSSortDescriptor(key: "folderName", ascending: ascending)]
        case .createdAt:
            request.sortDescriptors = [NSSortDescriptor(key: "folderMadeTime", ascending: ascending)]
        case .currentDate:
            request.sortDescriptors = [NSSortDescriptor(key: "currentDate", ascending: ascending)]
        }
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
            // flattenFolders のソート関数も currentSort/ascending に合わせる
            if let objects = fetchedResultsController.fetchedObjects {
                flatData = flattenFolders(objects.filter { $0.parent == nil })
            }
            tableView.reloadData()
        } catch {
            print("❌ Fetch error: \(error)")
        }
    }
    
    // MARK: - UITableView DataSource　データソース
    
    // ContentView または ViewController の先頭で
    /*@State*/ var coreDataResults: [FolderNode] = []
    
    //
    func numberOfSections(in tableView: UITableView) -> Int {
        if isSearching {
            return searchFRC.sections?.count ?? 0
        } else {
            return 1
        }
    }
    
    //セル表示
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearching {
            return searchFRC.sections?[section].numberOfObjects ?? 0
        } else {
            return flatData.count
        }
    }
    
    // MARK: - UITableViewDataSource　データソース
    
    // 通常用
    var normalFRC: NSFetchedResultsController<Folder>!
    
    // 検索用
    var searchFRC: NSFetchedResultsController<Folder>!
    
    // 現在表示しているFRC（通常 or 検索）
    var activeFRC: NSFetchedResultsController<Folder>!
    
    // まず expandedState を ObjectIdentifier に変更
    private var expandedState: [ObjectIdentifier: Bool] = [:]
    
    // MARK: - セル表示
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isSearching {
            let cell = tableView.dequeueReusableCell(withIdentifier: CustomCell.reuseID, for: indexPath) as! CustomCell
            let folder = searchFRC.object(at: indexPath)
            cell.configureCell(
                name: folder.folderName ?? "無題",
                level: Int(folder.level),
                isExpanded: false,
                hasChildren: (folder.children?.count ?? 0) > 0,
                systemName: "folder"
            )
            return cell
        } else {
            // 通常モードは以前の flatData 展開を使う
            let item = flatData[indexPath.row]
            let folder = item.folder
            let level = item.level
            let isExpanded = expandedState[ObjectIdentifier(folder)] ?? false

            let cell = tableView.dequeueReusableCell(withIdentifier: CustomCell.reuseID, for: indexPath) as! CustomCell
            cell.configureCell(
                name: folder.folderName ?? "無題",
                level: level,
                isExpanded: isExpanded,
                hasChildren: (folder.children?.count ?? 0) > 0,
                systemName: "folder"
            )
            return cell
        }
    }
    // MARK: - セルタップ
    func toggleFolder(_ folder: Folder) {
        guard let startIndex = flatData.firstIndex(where: { $0.folder == folder }) else { return }
        let parentLevel = flatData[startIndex].level
        let isExpanded = expandedState[ObjectIdentifier(folder)] ?? false
        
        tableView.beginUpdates()
        
        if isExpanded {
            // 折りたたむ
            var endIndex = startIndex + 1
            while endIndex < flatData.count && flatData[endIndex].level > parentLevel {
                endIndex += 1
            }
            
            if endIndex > startIndex + 1 {
                flatData.removeSubrange((startIndex + 1)..<endIndex)
                let indexPaths = (startIndex + 1..<endIndex).map { IndexPath(row: $0, section: 1) }
                tableView.deleteRows(at: indexPaths, with: .fade)
            }
            
            expandedState[ObjectIdentifier(folder)] = false
        } else {
            // 展開
            let children = (folder.children?.allObjects as? [Folder])?
                .sorted(by: { $0.sortIndex < $1.sortIndex }) ?? []
            
            var insertItems: [(folder: Folder, level: Int)] = []
            for child in children {
                insertItems.append((child, parentLevel + 1))
                // 子が開いている場合は再帰的に追加
                if expandedState[ObjectIdentifier(child)] == true {
                    insertItems.append(contentsOf: getExpandedDescendants(of: child, level: parentLevel + 2))
                }
            }
            
            flatData.insert(contentsOf: insertItems, at: startIndex + 1)
            let indexPaths = (0..<insertItems.count).map { IndexPath(row: startIndex + 1 + $0, section: 1) }
            tableView.insertRows(at: indexPaths, with: .fade)
            
            expandedState[ObjectIdentifier(folder)] = true
        }
        
        tableView.endUpdates()
    }
    // 再帰的に開いている子孫を取得
    private func getExpandedDescendants(of folder: Folder, level: Int) -> [(folder: Folder, level: Int)] {
        var result: [(folder: Folder, level: Int)] = []
        let children = (folder.children?.allObjects as? [Folder])?.sorted(by: { $0.sortIndex < $1.sortIndex }) ?? []
        
        for child in children {
            result.append((child, level))
            if expandedState[ObjectIdentifier(child)] == true {
                result.append(contentsOf: getExpandedDescendants(of: child, level: level + 1))
            }
        }
        return result
    }
    // 指定フォルダの全ての子孫の flatData 上のインデックスを返す
    private func indicesOfDescendants(startingAt parentIndex: Int) -> [Int] {
        let parentLevel = flatData[parentIndex].level
        var indices: [Int] = []
        var i = parentIndex + 1
        while i < flatData.count {
            if flatData[i].level > parentLevel {
                indices.append(i)
                i += 1
            } else {
                break
            }
        }
        return indices
    }
    func handleNormalTap(_ text: String) {
        print("ノーマルセルタップ: \(text)")
        // ここに詳細画面遷移やアクションを追加
    }
    func openFolder(_ folder: FolderNode) {
        print("検索結果のフォルダタップ: \(folder.name)")
        // ここに詳細画面遷移やフォルダ開閉処理を追加
    }
    
    // MARK: - Helpers
    private func flatten(folders: [Folder]) -> [Folder] {
        var result: [Folder] = []
        for folder in folders {
            result.append(folder)
            if expandedState[folder.id] == true {
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
    
    //フラット化
    private func flattenFolders(_ folders: [Folder], level: Int = 0) -> [(folder: Folder, level: Int)] {
        var result: [(folder: Folder, level: Int)] = []
        
        let sortedFolders: [Folder]
        switch currentSort {
        case .order:
            sortedFolders = folders.sorted { ascending ? $0.sortIndex < $1.sortIndex : $0.sortIndex > $1.sortIndex }
        case .title:
            sortedFolders = folders.sorted { ascending ? ($0.folderName ?? "") < ($1.folderName ?? "") : ($0.folderName ?? "") > ($1.folderName ?? "") }
        case .createdAt:
            sortedFolders = folders.sorted { ascending ? ($0.folderMadeTime ?? Date()) < ($1.folderMadeTime ?? Date()) : ($0.folderMadeTime ?? Date()) > ($1.folderMadeTime ?? Date()) }
        case .currentDate:
            sortedFolders = folders.sorted { ascending ? ($0.currentDate ?? Date()) < ($1.currentDate ?? Date()) : ($0.currentDate ?? Date()) > ($1.currentDate ?? Date()) }
        }
        
        for folder in sortedFolders {
            result.append((folder, level))
            if expandedState[ObjectIdentifier(folder)] == true,
               let children = folder.children?.allObjects as? [Folder] {
                result.append(contentsOf: flattenFolders(children, level: level + 1))
            }
        }
        return result
    }
    
    // MARK: - 並び替え
    
    // MARK: - 並び替え用編集スタイル
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        // SortType が order のときはハンドルだけ表示、削除は不可
        if currentSort == .order && indexPath.section == 1 {
            return .none
        } else {
            // 普通の編集モード（削除あり）なら .delete
            return .delete
        }
    }
    
    // 並び替え可能かどうか
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // section 1 のみ並び替え可能
        return currentSort == .order && indexPath.section == 1
    }
    
    // 並び替え後の処理
    var isMovingRow = false
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        isMovingRow = true
        
        let movedItem = flatData.remove(at: sourceIndexPath.row)
        flatData.insert(movedItem, at: destinationIndexPath.row)
        
        for (index, item) in flatData.enumerated() {
            item.folder.sortIndex = Int64(index)
        }
        
        try? context.save()
        isMovingRow = false
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if suppressFRCUpdates || isMovingRow { return } // ←移動中は無視
        
        guard let folders = controller.fetchedObjects as? [Folder] else { return }
        flatData = flattenFolders(folders.filter { $0.parent == nil })
        tableView.reloadData()
        
        // ascending を変更する処理もここに書くなら isMovingRow == false の時だけ
    }
    
    // MARK: - Toggle Folder
    /*func toggleFolder(for folder: FolderNode) {
     guard let index = flatData.firstIndex(of: folder) else { return }
     
     let isExpanded = expandedState[folder.id] ?? false
     expandedState[folder.id] = !isExpanded
     
     tableView.beginUpdates()
     
     if isExpanded {
     // 折りたたみ → 子を削除
     let childrenToRemove = getAllChildren(of: folder)
     let startIndex = index + 1
     flatData.removeSubrange(startIndex..<(startIndex + childrenToRemove.count))
     let indexPaths = childrenToRemove.enumerated().map { IndexPath(row: startIndex + $0.offset, section: 1) }
     tableView.deleteRows(at: indexPaths, with: .fade)
     } else {
     // 展開 → 子を挿入
     let childrenToInsert = getDirectChildren(of: folder)
     let startIndex = index + 1
     flatData.insert(contentsOf: childrenToInsert, at: startIndex)
     let indexPaths = childrenToInsert.enumerated().map { IndexPath(row: startIndex + $0.offset, section: 1) }
     tableView.insertRows(at: indexPaths, with: .fade)
     }
     
     tableView.endUpdates()
     }*/
    
    func getDirectChildren(of folder: FolderNode) -> [FolderNode] {
        return folder.children ?? []
    }
    
    func getAllChildren(of folder: FolderNode) -> [FolderNode] {
        var result: [FolderNode] = []
        
        func traverse(node: FolderNode) {
            let children = node.children  // Optionalではないのでそのまま使える
            result.append(contentsOf: children)
            children.forEach { traverse(node: $0) }
        }
        
        traverse(node: folder)
        return result
    }
    
    private func visibleChildrenForExpand(of folder: Folder) -> [Folder] {
        let children = (folder.children?.allObjects as? [Folder])?.sorted { $0.sortIndex < $1.sortIndex } ?? []
        var result: [Folder] = []
        for child in children {
            result.append(child)
            if expandedState[child.id] == true {
                result.append(contentsOf: visibleChildrenForExpand(of: child))
            }
        }
        return result
    }
    
    private func indicesOfDescendantsInFlatData(startingAt folderIndex: Int, parentLevel: Int) -> [Int] {
        var indices: [Int] = []
        var i = folderIndex + 1
        while i < flatData.count {
            let level = flatData[i].level // タプルから直接 level を取得
            if level > parentLevel {
                indices.append(i)
                i += 1
            } else {
                break
            }
        }
        return indices
    }
    //***//基本プロパティ
    
    var context: NSManagedObjectContext!
    private var fetchedResultsController: NSFetchedResultsController<Folder>!
    /*private var flatData: [Folder] = []*/private var flatData: [(folder: Folder, level: Int)] = []
    //    private var expandedState: [UUID: Bool] = [:]
    
    private let tableView = UITableView()
    private var searchBar = UISearchBar()
    private var sortButton: UIButton!
    private var headerStackView: UIStackView!
    private let bottomToolbar = UIToolbar()
    
    enum SortType: Int {
        case order = 0
        case title = 1
        case createdAt = 2
        case currentDate = 3
    }
    private var currentSort: SortType = .createdAt {
        didSet { UserDefaults.standard.set(currentSort.rawValue, forKey: "currentSort") }
    }
    private var ascending: Bool = true {
        didSet { UserDefaults.standard.set(ascending, forKey: "ascending") }
    }
    
    
    var selectedFolders: Set<Folder> = []
    var bottomToolbarState: BottomToolbarState = .normal {
        didSet { updateToolbar() }
    }
    
    var suppressFRCUpdates = false
    
    enum BottomToolbarState {
        case normal, selecting, editing
    }
    
    //***
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


