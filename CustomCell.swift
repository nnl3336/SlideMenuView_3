//
//  CustomCell.swift
//  SlideMenuView_3
//
//  Created by Yuki Sasaki on 2025/10/03.
//

import SwiftUI

// MARK: - CustomCell
final class CustomCell: UITableViewCell {
    static let reuseID = "FolderCell"

    private let folderIcon = UIImageView()
    private let titleLabel = UILabel()
    private var leadingConstraint: NSLayoutConstraint!
    
    //***

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }
    
    //***
    
    func configure(with folder: Folder, level: Int, isExpanded: Bool) {
        let name = folder.folderName ?? "無題"
        let hasChildren = (folder.children?.count ?? 0) > 0
        let systemName = hasChildren ? (isExpanded ? "chevron.down" : "chevron.right") : "folder"
        configure(name: name, level: level, isExpanded: isExpanded, hasChildren: hasChildren, systemName: systemName)
    }


    private func setupViews() {
        // アイコン
        folderIcon.translatesAutoresizingMaskIntoConstraints = false
        folderIcon.contentMode = .scaleAspectFit
        folderIcon.tintColor = .systemBlue

        // ラベル
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .medium) // ← 文字大きめ

        contentView.addSubview(folderIcon)
        contentView.addSubview(titleLabel)

        leadingConstraint = folderIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)

        NSLayoutConstraint.activate([
            leadingConstraint,
            folderIcon.widthAnchor.constraint(equalToConstant: 32),   // ← アイコン大きめ
            folderIcon.heightAnchor.constraint(equalToConstant: 32),  // ← アイコン大きめ
            folderIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: folderIcon.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])

        titleLabel.numberOfLines = 0
    }

    func configure(name: String, level: Int, isExpanded: Bool, hasChildren: Bool, systemName: String) {
        titleLabel.text = name
        leadingConstraint.constant = CGFloat(16 + level * 24) // インデントも少し広め
        folderIcon.image = UIImage(systemName: systemName)
    }
}
