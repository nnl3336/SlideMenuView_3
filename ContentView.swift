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

final class FolderViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, NSFetchedResultsControllerDelegate {
    
    var context: NSManagedObjectContext!
    var tableView = UITableView()
    var searchBar = UISearchBar()
    
    // 通常モード用
    var normalFRC: NSFetchedResultsController<Folder>!
    var flatData: [FolderNode] = []
    
    // 検索モード用
    var searchFRC: NSFetchedResultsController<Folder>!
    var isSearching = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Folders"
        view.backgroundColor = .systemBackground
        
        setupTableView()
        setupSearchBar()
        setupNormalFRC()
        setupSearchFRC()
        
        try? normalFRC.performFetch()
        if let objects = normalFRC.fetchedObjects {
            flatData = flattenFolders(objects.filter { $0.parent == nil })
        }
    }
    
    // MARK: - Setup
    
    func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func setupSearchBar() {
        searchBar.delegate = self
        searchBar.placeholder = "Search folders"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchBar.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    func setupNormalFRC() {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "folderMadeTime", ascending: true)]
        normalFRC = NSFetchedResultsController(fetchRequest: request,
                                               managedObjectContext: context,
                                               sectionNameKeyPath: nil,
                                               cacheName: nil)
        normalFRC.delegate = self
    }
    
    func setupSearchFRC() {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "folderMadeTime", ascending: true)]
        searchFRC = NSFetchedResultsController(fetchRequest: request,
                                               managedObjectContext: context,
                                               sectionNameKeyPath: nil,
                                               cacheName: nil)
        searchFRC.delegate = self
    }
    
    // MARK: - Search
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            isSearching = false
        } else {
            isSearching = true
            let predicate = NSPredicate(format: "folderName CONTAINS[cd] %@", searchText)
            searchFRC.fetchRequest.predicate = predicate
            try? searchFRC.performFetch()
        }
        tableView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        isSearching = false
        try? normalFRC.performFetch()
        if let objects = normalFRC.fetchedObjects {
            flatData = flattenFolders(objects.filter { $0.parent == nil })
        }
        tableView.reloadData()
    }
    
    // MARK: - TableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearching {
            return searchFRC.fetchedObjects?.count ?? 0
        } else {
            return flatData.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        
        if isSearching {
            if let folder = searchFRC.fetchedObjects?[indexPath.row] {
                cell.textLabel?.text = folder.folderName
            }
        } else {
            let node = flatData[indexPath.row]
            cell.textLabel?.text = String(repeating: "　", count: Int(node.level)) + (node.folder.folderName ?? "")
            cell.accessoryType = node.folder.isExpanded ? .detailDisclosureButton : .none
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !isSearching else { return } // 検索中は開閉なし
        
        let node = flatData[indexPath.row]
        toggleFolder(node.folder)
    }
    
    // MARK: - 展開・折りたたみ
    
    func toggleFolder(_ folder: Folder) {
        guard let startIndex = flatData.firstIndex(where: { $0.folder == folder }) else { return }
        
        folder.isExpanded.toggle()
        
        if folder.isExpanded {
            // 展開
            if let children = folder.children as? Set<Folder> {
                let nodes = flattenFolders(Array(children), level: Int64(folder.level + 1))
                flatData.insert(contentsOf: nodes, at: startIndex + 1)
            }
        } else {
            // 折りたたみ
            var removeCount = 0
            var i = startIndex + 1
            while i < flatData.count && flatData[i].level > folder.level {
                removeCount += 1
                i += 1
            }
            flatData.removeSubrange((startIndex + 1)...(startIndex + removeCount))
        }
        tableView.reloadData()
    }
    
    func flattenFolders(_ folders: [Folder], level: Int64 = 0) -> [FolderNode] {
        var result: [FolderNode] = []
        for folder in folders.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            result.append(FolderNode(folder: folder, level: level))
            if folder.isExpanded, let children = folder.children as? Set<Folder> {
                result += flattenFolders(Array(children), level: level + 1)
            }
        }
        return result
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


