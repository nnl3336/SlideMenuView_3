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

class FolderViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate, UISearchBarDelegate, UITextFieldDelegate {
    
    //***//イニシャライズ
    
    //***

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchFolders()
        setupSearchAndSortHeader()
        
        //loadExpandedState()
        
        // 取得後に展開状態を反映して flattenedFolders を作る
        buildFlattenedFolders()
        
        //
        
        // テーブルビューをリロード
        tableView.reloadData()
        
    }
    
    //***
    
    // MARK: - コンテキストメニュー
    func tableView(_ tableView: UITableView,
                   contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {

        // Folder 自体を取得
        let folderIndex = indexPath.row - normalBefore.count
        guard folderIndex >= 0 && folderIndex < visibleFlattenedFolders.count else { return nil }
        let folder = visibleFlattenedFolders[folderIndex]

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self = self else {
                return UIMenu(title: "", children: [])
            }

            // フォルダ追加アクション
            let addFolder = UIAction(title: "フォルダ追加", image: UIImage(systemName: "folder.badge.plus")) { _ in
                self.presentAddFolderAlert(parent: folder)
            }

            // 選択/トグルアクション
            let selectAction = UIAction(
                title: self.selectedFolders.contains(folder) ? "選択解除" : "選択",
                image: UIImage(systemName: self.selectedFolders.contains(folder) ? "checkmark.circle.fill" : "checkmark.circle")
            ) { _ in
                guard let index = self.visibleFlattenedFolders.firstIndex(of: folder) else { return }
                let indexPath = IndexPath(row: index, section: 0)

                if self.selectedFolders.contains(folder) {
                    self.selectedFolders.remove(folder)
                } else {
                    self.selectedFolders.insert(folder)
                }

                self.isSelecting = true
                self.bottomToolbarState = .selecting
                self.updateToolbar()

                // ✅ 該当セルだけ更新（reloadData()禁止！）
                tableView.reloadRows(at: [indexPath], with: .none)
                
                tableView.reloadData()
            }

            // 削除アクション
            let delete = UIAction(title: "削除", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.delete(folder)
            }

            return UIMenu(title: "", children: [addFolder, selectAction, delete])
        }
    }

    func addChildFolder(to parent: Folder, name: String) {
        let newFolder = Folder(context: context)
        newFolder.folderName = name
        newFolder.parent = parent
        newFolder.sortIndex = Int64((parent.children?.count ?? 0))
        
        // 親がいれば親の level + 1、親がいなければ 0
        newFolder.level = (parent.level) + 1
        
        do {
            try context.save()
            buildVisibleFlattenedFolders() // これで level が反映された状態で表示
            tableView.reloadData()
        } catch {
            print("Failed to add child folder:", error)
        }
    }

    
    // 選択処理
    func selectFolder(_ folder: Folder, at indexPath: IndexPath) {
        // 選択済みなら削除、未選択なら追加（トグル）
        if selectedFolders.contains(folder) {
            selectedFolders.remove(folder)
        } else {
            selectedFolders.insert(folder)
        }

        // この行だけ更新
        tableView.reloadRows(at: [indexPath], with: .none)
    }
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
            self.addChildFolder(to: parent, name: folderName)
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
    
    // MARK: - スワイプアクション
    
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
                   -> UISwipeActionsConfiguration? {

        let row = indexPath.row
        let folderStartIndex = normalBefore.count
        let folderEndIndex = folderStartIndex + visibleFlattenedFolders.count

        // CoreData フォルダ以外（normalBefore, normalAfter）はスワイプ不可
        guard row >= folderStartIndex && row < folderEndIndex else { return nil }

        // タプルではなく Folder そのもの
        let folder = visibleFlattenedFolders[row - folderStartIndex]

        // 削除アクション
        let deleteAction = UIContextualAction(style: .destructive, title: "削除") { action, view, completion in
            self.deleteFolder(folder)
            completion(true)
        }

        // 非表示アクション
        let hideAction = UIContextualAction(style: .normal, title: "非表示") { action, view, completion in
            self.hideFolder(folder)
            completion(true)
        }
        hideAction.backgroundColor = .gray

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, hideAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }



    // フォルダを削除する
    private func deleteFolder(_ folder: Folder) {
        // Folder 自体を検索
        guard let index = visibleFlattenedFolders.firstIndex(of: folder) else { return }

        // 子フォルダのインデックスも取得
        let rowsToDelete = [index] + childIndexes(of: folder)

        // 大きい順に削除（インデックスずれ防止）
        for row in rowsToDelete.sorted(by: >) {
            visibleFlattenedFolders.remove(at: row)
        }

        tableView.deleteRows(at: rowsToDelete.map { IndexPath(row: $0, section: 0) }, with: .automatic)

        // Core Data からも削除
        context.delete(folder)
        try? context.save()
    }

    // フォルダを非表示にする
    private func hideFolder(_ folder: Folder) {
        guard let index = visibleFlattenedFolders.firstIndex(of: folder) else { return }

        let rowsToHide = [index] + childIndexes(of: folder)

        for row in rowsToHide.sorted(by: >) {
            visibleFlattenedFolders.remove(at: row)
        }

        tableView.deleteRows(at: rowsToHide.map { IndexPath(row: $0, section: 0) }, with: .automatic)
    }



    // 子フォルダの index を取得
    private func childIndexes(of folder: Folder) -> [Int] {
        var indexes: [Int] = []

        for (i, f) in visibleFlattenedFolders.enumerated() {
            // f の parent が folder なら子
            if f.parent == folder {
                indexes.append(i)
                // 再帰的に孫も含める場合
                indexes.append(contentsOf: childIndexes(of: f))
            }
        }

        return indexes
    }



    
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
    
    // MARK: - 並べ替えメニュー生成　並び替えメニュー
    func makeSortMenu() -> UIMenu {
        return UIMenu(title: "並び替え", children: [
            // 作成日
            UIAction(title: "作成日", image: UIImage(systemName: "calendar"),
                     state: currentSort == .createdAt ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentSort = .createdAt
                self.fetchFolders()
                self.tableView.setEditing(false, animated: true)
                self.sortButton?.menu = self.makeSortMenu()
            },
            
            // 名前
            UIAction(title: "名前", image: UIImage(systemName: "textformat"),
                     state: currentSort == .title ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentSort = .title
                self.fetchFolders()
                self.tableView.setEditing(false, animated: true)
                self.sortButton?.menu = self.makeSortMenu()
            },
            
            // 追加日
            UIAction(title: "追加日", image: UIImage(systemName: "clock"),
                     state: currentSort == .currentDate ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentSort = .currentDate
                self.fetchFolders()
                self.tableView.setEditing(false, animated: true)
                self.sortButton?.menu = self.makeSortMenu()
            },
            
            // 順番（ドラッグで並べ替え）
            UIAction(title: "順番", image: UIImage(systemName: "list.number"),
                     state: currentSort == .order ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentSort = .order
                self.tableView.setEditing(true, animated: true)
                self.tableView.allowsSelectionDuringEditing = true
                         self.fetchFolders()
                self.sortButton?.menu = self.makeSortMenu()
            },
            
            // 昇順/降順切替
            UIAction(title: ascending ? "昇順 (A→Z)" : "降順 (Z→A)",
                     image: UIImage(systemName: "arrow.up.arrow.down")) { [weak self] _ in
                guard let self = self else { return }
                self.ascending.toggle()
                self.fetchFolders()
                self.sortButton?.menu = self.makeSortMenu()
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
    
    private var textField: UITextField!
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // 🔹 Navigation Bar に + ボタンを追加
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                            target: self,
                                                            action: #selector(addButtonTapped))
        
        // 🔹 TableView 設置
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        
        // 通常セル用
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        // カスタムセル用
        tableView.register(CustomCell.self, forCellReuseIdentifier: CustomCell.reuseID)
        
        view.addSubview(tableView)
    }
    
    // MARK: - ＋ボタン押下でアラート表示
    @objc private func addButtonTapped() {
        let alert = UIAlertController(title: "新しいフォルダ", message: "フォルダ名を入力してください", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "フォルダ名"
        }

        let addAction = UIAlertAction(title: "追加", style: .default) { [weak self] _ in
            guard let self = self,
                  let name = alert.textFields?.first?.text,
                  !name.isEmpty else { return }
            self.addParentFolder(named: name)
        }

        let cancelAction = UIAlertAction(title: "キャンセル", style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        alert.addAction(addAction)

        present(alert, animated: true)
    }
    
    // MARK: - フォルダ追加処理
    private func addParentFolder(named name: String) {
        // 同名チェック
        if visibleFlattenedFolders.contains(where: { $0.folderName == name }) {
            print("❌ 同名フォルダが既に存在します")
            return
        }

        let newFolder = Folder(context: context)
        newFolder.folderName = name
        newFolder.parent = nil
        newFolder.sortIndex = (visibleFlattenedFolders.map { $0.sortIndex }.max() ?? 0) + 1

        do {
            try context.save()  // Core Data に保存
            
            // 表示用配列にも追加（タプルではなく Folder 自体）
            visibleFlattenedFolders.append(newFolder)

            // テーブルに挿入
            let newIndexPath = IndexPath(row: visibleFlattenedFolders.count - 1, section: 0)
            tableView.insertRows(at: [newIndexPath], with: .automatic)

            print("📁 保存成功: \(name)")
        } catch {
            print("保存エラー:", error)
        }
    }


    // MARK: - ボタンアクション
    @objc private func addParentFolder() {
        let newFolder = Folder(context: context)
        newFolder.folderName = "新しいフォルダ"
        newFolder.sortIndex = (visibleFlattenedFolders.map { $0.sortIndex }.max() ?? 0) + 1
        newFolder.level = 0

        try? context.save()
        buildVisibleFlattenedFolders()
        tableView.reloadData()
    }




    // MARK: - Fetch　frc
    
    private func fetchFolders(predicate: NSPredicate? = nil) {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        
        // sortDescriptors のキーを currentSort に応じて決定
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

        // sortDescriptors 設定
        if currentSort == .order {
            // 順番モードは sortIndex でソート
            request.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: ascending)]
        } else {
            // その他モードは sortKey のみでソート
            request.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: ascending)]
        }

        // 検索条件があれば設定
        if let predicate = predicate {
            request.predicate = predicate
        }

        // FRC 設定
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
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

        // ルートフォルダだけ抽出
        var rootFolders = allFolders.filter { $0.parent == nil }

        /*if currentSort == .order {
            // order モードのときは sortIndex で並び替え
            rootFolders.sort { $0.sortIndex < $1.sortIndex }
        }*/

        // visibleFlattenedFolders を再構築
        visibleFlattenedFolders = []
        buildVisibleFolders(from: rootFolders)
    }

    // 再帰的に展開して visibleFlattenedFolders に追加
    private func buildVisibleFolders(from folders: [Folder]) {
        // まず現在の並び順で folders をソート
        let sortedFolders: [Folder] = {
            switch currentSort {
            case .order:
                return folders.sorted { ascending ? $0.sortIndex < $1.sortIndex : $0.sortIndex > $1.sortIndex }
            case .title:
                return folders.sorted { ascending ? ($0.folderName ?? "") < ($1.folderName ?? "") : ($0.folderName ?? "") > ($1.folderName ?? "") }
            case .createdAt:
                return folders.sorted { ascending ? ($0.folderMadeTime ?? Date.distantPast) < ($1.folderMadeTime ?? Date.distantPast) : ($0.folderMadeTime ?? Date.distantPast) > ($1.folderMadeTime ?? Date.distantPast) }
            case .currentDate:
                return folders.sorted { ascending ? ($0.currentDate ?? Date.distantPast) < ($1.currentDate ?? Date.distantPast) : ($0.currentDate ?? Date.distantPast) > ($1.currentDate ?? Date.distantPast) }
            }
        }()

        for folder in sortedFolders {
            visibleFlattenedFolders.append(folder)

            // 展開状態のフォルダだけ子フォルダを追加
            if expandedState[folder.uuid] == true,
               let children = folder.children as? Set<Folder> {
                buildVisibleFolders(from: Array(children))
            }
        }
    }

    /*private func flattenWithLevel(nodes: [Folder], level: Int = 0) -> [(folder: Folder, level: Int)] {
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
    }*/

    private func buildVisibleFlattenedFolders() {
        var result: [Folder] = []

        func addChildren(of folder: Folder) {
            result.append(folder)

            // 展開状態のフォルダだけ子フォルダを追加
            if expandedState[folder.uuid] == true,
               let children = folder.children as? Set<Folder> {
                // currentSort と ascending に応じて並び替え
                let sortedChildren: [Folder] = {
                    switch currentSort {
                    case .order:
                        return children.sorted { ascending ? $0.sortIndex < $1.sortIndex : $0.sortIndex > $1.sortIndex }
                    case .title:
                        return children.sorted { ascending ? ($0.folderName ?? "") < ($1.folderName ?? "") : ($0.folderName ?? "") > ($1.folderName ?? "") }
                    case .createdAt:
                        return children.sorted { ascending ? ($0.folderMadeTime ?? Date.distantPast) < ($1.folderMadeTime ?? Date.distantPast) : ($0.folderMadeTime ?? Date.distantPast) > ($1.folderMadeTime ?? Date.distantPast) }
                    case .currentDate:
                        return children.sorted { ascending ? ($0.currentDate ?? Date.distantPast) < ($1.currentDate ?? Date.distantPast) : ($0.currentDate ?? Date.distantPast) > ($1.currentDate ?? Date.distantPast) }
                    }
                }()

                for child in sortedChildren {
                    addChildren(of: child)
                }
            }
        }

        // Core Data から直接ルートフォルダを取得
        guard let allFolders = fetchedResultsController.fetchedObjects else { return }
        let rootFolders = allFolders.filter { $0.parent == nil }

        let sortedRoots: [Folder] = {
            switch currentSort {
            case .order:
                return rootFolders.sorted { ascending ? $0.sortIndex < $1.sortIndex : $0.sortIndex > $1.sortIndex }
            case .title:
                return rootFolders.sorted { ascending ? ($0.folderName ?? "") < ($1.folderName ?? "") : ($0.folderName ?? "") > ($1.folderName ?? "") }
            case .createdAt:
                return rootFolders.sorted { ascending ? ($0.folderMadeTime ?? Date.distantPast) < ($1.folderMadeTime ?? Date.distantPast) : ($0.folderMadeTime ?? Date.distantPast) > ($1.folderMadeTime ?? Date.distantPast) }
            case .currentDate:
                return rootFolders.sorted { ascending ? ($0.currentDate ?? Date.distantPast) < ($1.currentDate ?? Date.distantPast) : ($0.currentDate ?? Date.distantPast) > ($1.currentDate ?? Date.distantPast) }
            }
        }()

        for root in sortedRoots {
            addChildren(of: root)
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
        let coreDataEnd = coreDataStart + visibleFlattenedFolders.count - 1

        // Core Dataセル範囲外なら何もしない
        if sourceIndexPath.row < coreDataStart || sourceIndexPath.row > coreDataEnd ||
           destinationIndexPath.row < coreDataStart || destinationIndexPath.row > coreDataEnd {
            tableView.reloadData()
            return
        }

        // visibleFlattenedFoldersインデックスに変換
        let from = sourceIndexPath.row - coreDataStart
        let to = destinationIndexPath.row - coreDataStart

        // 並べ替え処理
        let moved = visibleFlattenedFolders.remove(at: from)
        visibleFlattenedFolders.insert(moved, at: to)

        // sortIndex更新
        for (i, folder) in visibleFlattenedFolders.enumerated() {
            folder.sortIndex = Int64(i)
        }

        // Core Data 保存
        do {
            try context.save()
            print("✅ 並び順を保存しました")
        } catch {
            print("❌ 保存失敗: \(error)")
        }

        // 即fetchし直すと順序がリセットされるので不要
    }
    func saveFolderOrder() {
        for (index, folder) in visibleFlattenedFolders.enumerated() {
            folder.sortIndex = Int64(index)  // Core Data の順番用プロパティ
        }

        do {
            try context.save()
            print("✅ フォルダ順を保存しました")
        } catch {
            print("❌ フォルダ順の保存に失敗:", error)
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

        // normalBefore セルは移動不可
        if indexPath.row < normalBefore.count { return false }

        // CoreDataセル範囲
        let coreDataStart = normalBefore.count
        let coreDataEnd = coreDataStart + visibleFlattenedFolders.count - 1

        // normalAfter セルは移動不可
        if indexPath.row > coreDataEnd { return false }

        // Core Data フォルダのみ移動可能
        return true
    }

    
    
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
    
    //基本プロパティ
    
    let normalBefore = ["Apple", "Orange"]
    let normalAfter = ["Banana"]

    //セル表示
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isSearching {
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
            
            // 選択状態の反映
            cell.contentView.backgroundColor = selectedFolders.contains(folder)
                ? UIColor.systemBlue.withAlphaComponent(0.3)
                : .clear

            return cell
        } else {
            let row = indexPath.row

            // normalBefore
            if row < normalBefore.count {
                let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
                cell.textLabel?.text = normalBefore[row]
                return cell
            }

            // Core Data フォルダ
            let folderStartIndex = normalBefore.count
            let folderEndIndex = folderStartIndex + visibleFlattenedFolders.count

            if row >= folderStartIndex && row < folderEndIndex {
                let folder = visibleFlattenedFolders[row - folderStartIndex]
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

                // 選択状態の反映
                cell.selectionStyle = .none
                cell.contentView.backgroundColor = selectedFolders.contains(folder)
                    ? UIColor.systemBlue.withAlphaComponent(0.3)
                    : .clear

                // 矢印タップのハンドリング
                cell.chevronTapped = { [weak self] in
                    self?.toggleFolder(folder)
                }

                return cell
            }

            // normalAfter
            let afterIndex = row - folderEndIndex
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.textLabel?.text = normalAfter[afterIndex]
            return cell
        }
    }


    
    
    // MARK: - 開閉
    
    //基本プロパティ
    
    //var expandedState: [NSManagedObjectID: Bool] = [:]
    var visibleFlattenedFolders: [Folder] = []
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
        // インデックスを取得
        guard let index = visibleFlattenedFolders.firstIndex(of: folder),
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

        // 挿入位置
        let insertIndex = index + 1
        visibleFlattenedFolders.insert(contentsOf: children, at: insertIndex)

        // 展開済みなら孫も再帰的に追加
        for child in children where expandedState[child.uuid] == true {
            showChildren(of: child)
        }
    }
    func hideDescendants(of folder: Folder) {
        guard let children = folder.children?.allObjects as? [Folder] else { return }

        // 再帰的に子孫を隠す
        for child in children {
            hideDescendants(of: child)
        }

        // visibleFlattenedFolders から子フォルダを削除
        visibleFlattenedFolders.removeAll { child in
            children.contains(child)
        }
    }

    
    // MARK: - Toggle Folder（展開／折りたたみ）　トグル
    func toggleFolder(_ folder: Folder) {
        let currently = expandedState[folder.uuid] ?? false
        expandedState[folder.uuid] = !currently

        // visibleFlattenedFolders を再構築
        let oldVisible = visibleFlattenedFolders
        buildVisibleFlattenedFolders()  // ここで [Folder] に再構築
        let newVisible = visibleFlattenedFolders
        let startRow = normalBefore.count

        // 削除行
        var deleteIndexPaths: [IndexPath] = []
        for (i, f) in oldVisible.enumerated() {
            if !newVisible.contains(f) {
                deleteIndexPaths.append(IndexPath(row: startRow + i, section: 0))
            }
        }

        // 追加行
        var insertIndexPaths: [IndexPath] = []
        for (i, f) in newVisible.enumerated() {
            if !oldVisible.contains(f) {
                insertIndexPaths.append(IndexPath(row: startRow + i, section: 0))
            }
        }

        tableView.beginUpdates()
        tableView.deleteRows(at: deleteIndexPaths, with: .fade)
        tableView.insertRows(at: insertIndexPaths, with: .fade)
        tableView.endUpdates()

        // 矢印回転
        if let index = newVisible.firstIndex(of: folder),
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

    var isSelecting: Bool = false

    //セルタップ
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !isSearching else { return }

        let row = indexPath.row
        let coreDataStartIndex = normalBefore.count
        let coreDataEndIndex = coreDataStartIndex + visibleFlattenedFolders.count

        if row < normalBefore.count {
            // normalBefore
            tableView.deselectRow(at: indexPath, animated: true)

        } else if row < coreDataEndIndex {
            // CoreData フォルダ
            let folder = visibleFlattenedFolders[row - coreDataStartIndex]

            if isSelecting {
                // トグル選択
                if selectedFolders.contains(folder) {
                    selectedFolders.remove(folder)
                    if selectedFolders.isEmpty {
                        isSelecting = false
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
                toggleFolder(folder)
            }

        } else {
            // normalAfter
            let afterIndex = row - coreDataEndIndex
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    

    
    
    
    
    

    // MARK: - UISearchBarDelegate　デリゲート
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // テーブルビューのスクロール開始時にキーボードを閉じる
        view.endEditing(true)
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
    // var flattenedFolders: [(folder: Folder, level: Int)] = []
//     var visibleFlattenedFolders: [(folder: Folder, level: Int)] = []
    
    // 検索時: 階層ごとの分類
    var groupedByLevel: [Int64: [Folder]] = [:]
    var sortedLevels: [Int64] = []

    // 状態管理
    var expandedFolders: Set<Folder> = []
    var isSearching: Bool = false
}


//




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
