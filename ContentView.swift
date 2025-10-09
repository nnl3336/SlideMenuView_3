//
//  ContentView.swift
//  SlideMenuView_3
//
//  Created by Yuki Sasaki on 2025/10/03.
//

import SwiftUI
import CoreData
import UIKit

class FolderViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate, UISearchBarDelegate {
    
    //***
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupTableView()
        
        setupSearchAndSortHeader()
        setupToolbar()
        
        setupFRC()
        
        /*navigationItem.rightBarButtonItem = UIBarButtonItem(
         barButtonSystemItem: .add, target: self, action: #selector(addFolder)
         )*/
        
        if let objects = fetchedResultsController.fetchedObjects {
            flatData = flatten(folders: objects.filter { $0.parent == nil })
        }
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        bottomToolbar.translatesAutoresizingMaskIntoConstraints = false
        
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
    
    // MARK: - 階層Folder
    
    // MARK: - Step 1: モデル定義　基本プロパティ
    class FolderNode {
        let name: String
        var children: [FolderNode]
        var level: Int = 0  // 第n階層を表す
        
        init(name: String, children: [FolderNode] = []) {
            self.name = name
            self.children = children
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
    func flattenWithLevel(nodes: [FolderNode], level: Int = 0) -> [FolderNode] {
        var result: [FolderNode] = []
        for node in nodes {
            node.level = level
            result.append(node)
            result.append(contentsOf: flattenWithLevel(nodes: node.children, level: level + 1))
        }
        return result
    }
    
    
    // MARK: - Step 4: 検索して階層ごとに分類
    func search(nodes: [FolderNode], query: String) -> [Int: [FolderNode]] {
        let all = flattenWithLevel(nodes: nodes)
        let filtered = all.filter { $0.name.localizedCaseInsensitiveContains(query) }
        let grouped = Dictionary(grouping: filtered, by: { $0.level })
        return grouped
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            isSearching = false
            groupedCoreData = [:]
        } else {
            isSearching = true
            groupedCoreData = search(nodes: rootNodes, query: searchText)
            sortedLevels = groupedCoreData.keys.sorted()
        }
        tableView.reloadData()
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
            
            // 新しいフォルダを作成
            let newFolder = Folder(context: self.context)
            newFolder.folderName = name
            newFolder.sortIndex = (self.flatData.last?.sortIndex ?? -1) + 1
            
            do { try self.context.save() } catch { print(error) }
            
            // FRC から再取得
            if let objects = self.fetchedResultsController.fetchedObjects {
                self.flatData = self.flatten(folders: objects.filter { $0.parent == nil })
                self.tableView.reloadData()
            }
        }))
        
        present(alert, animated: true)
    }
    
    // MARK: - Setup TableView
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(CustomCell.self, forCellReuseIdentifier: CustomCell.reuseID)
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
                         if let button = self.sortButton { button.menu = self.makeSortMenu() }
                     },
            UIAction(title: "名前", image: UIImage(systemName: "textformat"),
                     state: currentSort == .title ? .on : .off) { [weak self] _ in
                         guard let self = self else { return }
                         self.currentSort = .title
                         self.setupFRC()
                         if let button = self.sortButton { button.menu = self.makeSortMenu() }
                     },
            UIAction(title: "追加日", image: UIImage(systemName: "clock"),
                     state: currentSort == .currentDate ? .on : .off) { [weak self] _ in
                         guard let self = self else { return }
                         self.currentSort = .currentDate
                         self.setupFRC()
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
        case .order: request.sortDescriptors = [NSSortDescriptor(key: "sortIndex", ascending: ascending)]
        case .title: request.sortDescriptors = [NSSortDescriptor(key: "folderName", ascending: ascending)]
        case .createdAt: request.sortDescriptors = [NSSortDescriptor(key: "folderMadeTime", ascending: ascending)]
        case .currentDate: request.sortDescriptors = [NSSortDescriptor(key: "currentDate", ascending: ascending)]
        }
        request.predicate = NSPredicate(format: "parent == nil")
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
            tableView.reloadData()
        } catch {
            print("❌ Fetch error: \(error)")
        }
    }
    
    // MARK: - UITableView DataSource
    // MARK: - セル個数
    func numberOfSections(in tableView: UITableView) -> Int {
        if isSearching {
            return sortedLevels.count
        } else {
            return 3 // normalBefore, coreData, normalAfter
        }
    }
    
    // MARK: - セル表示
    // MARK: - 通常時（検索なし）
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CustomCell.reuseID, for: indexPath) as! CustomCell

        if isSearching {
            let level = sortedLevels[indexPath.section]
            if let node = groupedCoreData[level]?[indexPath.row] {
                cell.textLabel?.text = node.name
            }
            return cell
        }
        
        // 通常表示時
        switch indexPath.section {
        case 0:
            cell.textLabel?.text = normalBefore[indexPath.row]
        case 1:
            let all = flattenWithLevel(nodes: rootNodes)
            cell.textLabel?.text = all[indexPath.row].name
        case 2:
            cell.textLabel?.text = normalAfter[indexPath.row]
        default:
            break
        }
        return cell
    }
    // MARK: - 検索時
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard isSearching else { return nil }
        let level = sortedLevels[section]
        return "第\(level + 1)階層"
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearching {
            // 🔍 検索中 → 階層ごとに CoreData を表示
            let level = sortedLevels[section]
            return groupedCoreData[level]?.count ?? 0
        } else {
            // 🧱 通常時 → 前（Apple, Orange） + CoreData + 後（Banana）
            switch section {
            case 0:
                return normalBefore.count
            case 1:
                let all = flattenWithLevel(nodes: rootNodes)
                return all.count
            case 2:
                return normalAfter.count
            default:
                return 0
            }
        }
    }
    
    // MARK: - セルタップ
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if isSearching {
            // 🔍 検索モード
            let level = sortedLevels[indexPath.section]
            if let items = groupedCoreData[level] {
                let folder = items[indexPath.row]
                // 検索中のCoreDataセルタップ時の動作（例：詳細画面へ遷移）
                openFolder(folder)
            }
        } else {
            // 🧱 通常モード
            switch indexPath.section {
            case 0:
                // ノーマルセル（Apple, Orange）
                handleNormalTap(normalBefore[indexPath.row])

            case 1:
                // CoreData階層セル
                let folder = flatData[indexPath.row]
                toggleFolder(for: folder)

            case 2:
                // ノーマルセル（Banana）
                handleNormalTap(normalAfter[indexPath.row])

            default:
                break
            }
        }
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
    
    // MARK: - Toggle Folder
    func toggleFolder(for folder: Folder) {
        guard let row = flatData.firstIndex(of: folder) else { return }
        let isExpanded = expandedState[folder.objectID] ?? false
        let parentLevel = getLevel(of: folder)
        
        if !isExpanded {
            let itemsToInsert = visibleChildrenForExpand(of: folder)
            guard !itemsToInsert.isEmpty else {
                expandedState[folder.objectID] = true
                return
            }
            let startIndex = row + 1
            let indexPaths = itemsToInsert.enumerated().map { IndexPath(row: startIndex + $0.offset, section: 0) }
            flatData.insert(contentsOf: itemsToInsert, at: startIndex)
            expandedState[folder.objectID] = true
            tableView.beginUpdates()
            tableView.insertRows(at: indexPaths, with: .fade)
            tableView.endUpdates()
        } else {
            let indicesToDelete = indicesOfDescendantsInFlatData(startingAt: row, parentLevel: parentLevel)
            guard !indicesToDelete.isEmpty else {
                expandedState[folder.objectID] = false
                return
            }
            let indexPaths = indicesToDelete.map { IndexPath(row: $0, section: 0) }
            expandedState[folder.objectID] = false
            for idx in indicesToDelete.sorted(by: >) { flatData.remove(at: idx) }
            tableView.beginUpdates()
            tableView.deleteRows(at: indexPaths, with: .fade)
            tableView.endUpdates()
        }
    }
    
    private func visibleChildrenForExpand(of folder: Folder) -> [Folder] {
        let children = (folder.children?.allObjects as? [Folder])?.sorted { $0.sortIndex < $1.sortIndex } ?? []
        var result: [Folder] = []
        for child in children {
            result.append(child)
            if expandedState[child.objectID] == true {
                result.append(contentsOf: visibleChildrenForExpand(of: child))
            }
        }
        return result
    }
    
    private func indicesOfDescendantsInFlatData(startingAt folderIndex: Int, parentLevel: Int) -> [Int] {
        var indices: [Int] = []
        var i = folderIndex + 1
        while i < flatData.count {
            let level = getLevel(of: flatData[i])
            if level > parentLevel { indices.append(i); i += 1 } else { break }
        }
        return indices
    }
    
    
    
    
    //***//基本プロパティ
    
    var context: NSManagedObjectContext!
    private var fetchedResultsController: NSFetchedResultsController<Folder>!
    private var flatData: [Folder] = []
    private var expandedState: [NSManagedObjectID: Bool] = [:]
    
    private let tableView = UITableView()
    private var searchBar = UISearchBar()
    private var sortButton: UIButton!
    private var headerStackView: UIStackView!
    private let bottomToolbar = UIToolbar()
    
    enum SortType { case order, title, createdAt, currentDate }
    private var currentSort: SortType = .title
    private var ascending: Bool = true
    
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


