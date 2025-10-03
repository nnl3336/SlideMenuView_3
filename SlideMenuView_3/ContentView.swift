//
//  ContentView.swift
//  SlideMenuView_3
//
//  Created by Yuki Sasaki on 2025/10/03.
//

import SwiftUI
import CoreData
import UIKit

class FolderTableViewController: UITableViewController {
    
    var context: NSManagedObjectContext!
    
    var rootFolders: [Folder] = []
    var flatData: [Folder] = []
    var expandedState: [NSManagedObjectID: Bool] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(CustomCell.self, forCellReuseIdentifier: "cell")
        title = "Folders"
        
        // 追加ボタン
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                            target: self,
                                                            action: #selector(addFolder))
        
        fetchRootFolders()
        flatData = flatten(folders: rootFolders)
    }
    
    // MARK: - Fetch
    private func fetchRootFolders() {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.predicate = NSPredicate(format: "parent == nil")
        request.sortDescriptors = [NSSortDescriptor(key: "sortIndex", ascending: true)]
        
        do {
            rootFolders = try context.fetch(request)
        } catch {
            print("Fetch error: \(error)")
        }
    }
    
    private func flatten(folders: [Folder]) -> [Folder] {
        var result: [Folder] = []
        for folder in folders {
            result.append(folder)
            if expandedState[folder.objectID] == true {
                let children = (folder.children as? Set<Folder>)?
                    .sorted { $0.sortIndex < $1.sortIndex } ?? []
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
    
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let folder = flatData[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! CustomCell
        
        let level = getLevel(of: folder)
        cell.indentationLevel = level
        cell.indentationWidth = 20
        cell.titleLabel.text = folder.folderName
        
        if let children = folder.children, children.count > 0 {
            let arrow = UIImageView()
            arrow.image = expandedState[folder.objectID] == true ?
                UIImage(named: "arrow_open") :
                UIImage(named: "arrow_closed")
            arrow.isUserInteractionEnabled = true
            arrow.tag = indexPath.row
            arrow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleFolder(_:))))
            cell.accessoryView = arrow
            cell.iconView.image = UIImage(systemName: "folder.fill")
        } else {
            cell.accessoryView = nil
            cell.iconView.image = UIImage(systemName: "doc.fill")
        }
        
        return cell
    }
    
    // MARK: - Toggle Folder
    @objc private func toggleFolder(_ sender: UITapGestureRecognizer) {
        guard let row = sender.view?.tag else { return }
        let folder = flatData[row]
        let isExpanded = expandedState[folder.objectID] ?? false
        expandedState[folder.objectID] = !isExpanded
        
        flatData = flatten(folders: rootFolders)
        tableView.reloadData()
    }
    
    // MARK: - Add Folder
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
            newFolder.sortIndex = (self.rootFolders.last?.sortIndex ?? -1) + 1
            
            do { try self.context.save() } catch { print(error) }
            
            // 再読み込み
            self.fetchRootFolders()
            self.flatData = self.flatten(folders: self.rootFolders)
            self.tableView.reloadData()
        }))
        
        present(alert, animated: true)
    }
}

class CustomCell: UITableViewCell {
    let iconView = UIImageView()
    let titleLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
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


