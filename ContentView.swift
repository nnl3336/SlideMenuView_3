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

class FolderViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate, UISearchBarDelegate {

    var tableView: UITableView!
    var searchBar: UISearchBar!

    var context: NSManagedObjectContext!
    var fetchedResultsController: NSFetchedResultsController<Folder>!

    var groupedByLevel: [Int64: [Folder]] = [:]
    var sortedLevels: [Int64] = []
    var expandedFolders: Set<Folder> = []

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
    }

    private func fetchFolders(predicate: NSPredicate? = nil) {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "level", ascending: true),
                                   NSSortDescriptor(key: "sortIndex", ascending: true)]

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
            groupFoldersByLevel()
        } catch {
            print("Fetch failed: \(error)")
        }
    }

    private func groupFoldersByLevel() {
        guard let folders = fetchedResultsController.fetchedObjects else { return }

        groupedByLevel = Dictionary(grouping: folders, by: { Int64($0.level) })
        sortedLevels = groupedByLevel.keys.sorted()
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return sortedLevels.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let level = sortedLevels[section]
        return "第\(level + 1)階層"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let level = sortedLevels[section]
        return groupedByLevel[level]?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let level = sortedLevels[indexPath.section]
        if let folder = groupedByLevel[level]?[indexPath.row] {
            cell.textLabel?.text = folder.folderName ?? "(no name)"
            cell.accessoryType = expandedFolders.contains(folder) ? .detailDisclosureButton : .disclosureIndicator
        }
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let level = sortedLevels[indexPath.section]
        guard let folder = groupedByLevel[level]?[indexPath.row] else { return }

        if expandedFolders.contains(folder) {
            expandedFolders.remove(folder)
        } else {
            expandedFolders.insert(folder)
        }

        tableView.reloadRows(at: [indexPath], with: .automatic)
    }

    // MARK: - UISearchBarDelegate

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            fetchFolders()
        } else {
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


