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

    var tableView: UITableView!
    var searchBar: UISearchBar!
    var context: NSManagedObjectContext!

    var fetchedResultsController: NSFetchedResultsController<Folder>!

    // 通常時: 展開ツリー
    var flattenedFolders: [Folder] = []

    // 検索時: 階層ごとの分類
    var groupedByLevel: [Int64: [Folder]] = [:]
    var sortedLevels: [Int64] = []

    // 状態管理
    var expandedFolders: Set<Folder> = []
    var isSearching: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchFolders()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        searchBar = UISearchBar()
        searchBar.delegate = self
        searchBar.placeholder = "フォルダ名を検索"
        navigationItem.titleView = searchBar

        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        
        tableView.register(CustomCell.self, forCellReuseIdentifier: CustomCell.reuseID)

        
    }

    // MARK: - Fetch

    private func fetchFolders(predicate: NSPredicate? = nil) {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortIndex", ascending: true)]

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
    }

    private func flatten(nodes: [Folder]) -> [Folder] {
        var result: [Folder] = []
        for node in nodes.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            result.append(node)
            if expandedFolders.contains(node),
               let children = node.children as? Set<Folder> {
                let sortedChildren = children.sorted(by: { $0.sortIndex < $1.sortIndex })
                result.append(contentsOf: flatten(nodes: sortedChildren))
            }
        }
        return result
    }

    // MARK: - UITableViewDataSource

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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearching {
            let level = sortedLevels[section]
            return groupedByLevel[level]?.count ?? 0
        } else {
            return flattenedFolders.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let folder = flattenedFolders[indexPath.row]

        // CustomCellを使う（systemName対応）
        let cell = tableView.dequeueReusableCell(withIdentifier: CustomCell.reuseID, for: indexPath) as! CustomCell

        // アイコンと名前を設定
        cell.configureCell(
            name: folder.folderName ?? "無題",
            level: Int(folder.level),
            isExpanded: expandedFolders.contains(folder),
            hasChildren: (folder.children?.count ?? 0) > 0,
            systemName: "folder"  // ここでSF Symbolを設定
        )

        // インデント
        let indent = Int(folder.level) * 20
        cell.separatorInset = UIEdgeInsets(top: 0, left: CGFloat(indent), bottom: 0, right: 0)

        // 矢印タップで開閉
        if let children = folder.children?.allObjects as? [Folder], !children.isEmpty {
            cell.chevronTapped = { [weak self, weak cell] in
                guard let self = self, let cell = cell else { return }

                let isExpanded = self.expandedFolders.contains(folder)

                tableView.beginUpdates()
                self.toggleFolder(folder)
                tableView.endUpdates()

                // アニメーションで矢印回転
                cell.rotateChevron(expanded: !isExpanded)
            }
        } else {
            cell.chevronTapped = nil
        }

        return cell
    }
    func toggleFolder(_ folder: Folder) {
        guard let startIndex = flattenedFolders.firstIndex(of: folder) else { return }
        let isExpanded = expandedFolders.contains(folder)

        tableView.beginUpdates()

        if isExpanded {
            // 折りたたむ
            var endIndex = startIndex + 1
            while endIndex < flattenedFolders.count,
                  flattenedFolders[endIndex].level > folder.level {
                endIndex += 1
            }
            flattenedFolders.removeSubrange((startIndex + 1)..<endIndex)
            let indexPaths = (startIndex + 1..<endIndex).map { IndexPath(row: $0, section: 0) }
            tableView.deleteRows(at: indexPaths, with: .fade)
            expandedFolders.remove(folder)
        } else {
            // 展開
            let children = (folder.children?.allObjects as? [Folder])?
                .sorted(by: { $0.sortIndex < $1.sortIndex }) ?? []
            flattenedFolders.insert(contentsOf: children, at: startIndex + 1)
            let indexPaths = (0..<children.count).map { IndexPath(row: startIndex + 1 + $0, section: 0) }
            tableView.insertRows(at: indexPaths, with: .fade)
            expandedFolders.insert(folder)
        }

        tableView.endUpdates()
    }


    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !isSearching else { return } // 検索時は開閉しない

        let folder = flattenedFolders[indexPath.row]

        if expandedFolders.contains(folder) {
            expandedFolders.remove(folder)
        } else {
            expandedFolders.insert(folder)
        }

        buildFlattenedFolders()
        tableView.reloadData()
    }

    // MARK: - UISearchBarDelegate

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


