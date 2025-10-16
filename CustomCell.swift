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
    private let chevronIcon = UIImageView() // 右端矢印
    private var leadingConstraint: NSLayoutConstraint!
    
    // ノーマルセル用フラグ
    private var isNormalCell = false
    // ...既存プロパティ
    var chevronTapped: (() -> Void)? // タップ時のコールバック
    
    //***
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default
        setupViews()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    //***
    
    private func setupViews() {
        folderIcon.translatesAutoresizingMaskIntoConstraints = false
        folderIcon.contentMode = .scaleAspectFit
        folderIcon.tintColor = .systemBlue

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .medium)

        chevronIcon.translatesAutoresizingMaskIntoConstraints = false
        chevronIcon.contentMode = .scaleAspectFit
        chevronIcon.tintColor = .systemGray
        chevronIcon.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(chevronTappedAction))
        chevronIcon.addGestureRecognizer(tap)

        contentView.addSubview(folderIcon)
        contentView.addSubview(titleLabel)
        contentView.addSubview(chevronIcon)

        leadingConstraint = folderIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)

        NSLayoutConstraint.activate([
            leadingConstraint,
            folderIcon.widthAnchor.constraint(equalToConstant: 32),
            folderIcon.heightAnchor.constraint(equalToConstant: 32),
            folderIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: folderIcon.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronIcon.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            chevronIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            chevronIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronIcon.widthAnchor.constraint(equalToConstant: 16),
            chevronIcon.heightAnchor.constraint(equalToConstant: 16)
        ])

        titleLabel.numberOfLines = 0
    }

    
    @objc private func chevronTappedAction() {
        // コールバックを呼ぶ
        chevronTapped?()
    }
    
    func rotateChevron(expanded: Bool, animated: Bool = true) {
        let angle: CGFloat = expanded ? .pi/2 : 0 // 右向き→下向き
        if animated {
            UIView.animate(withDuration: 0.25) {
                self.chevronIcon.transform = CGAffineTransform(rotationAngle: angle)
            }
        } else {
            self.chevronIcon.transform = CGAffineTransform(rotationAngle: angle)
        }
    }
    
    // CoreData用セル
    func configure(folder: Folder, level: Int, isExpanded: Bool) {
        isNormalCell = false
        let name = folder.folderName ?? "無題"
        let hasChildren = (folder.children?.count ?? 0) > 0
        configureCell(name: name, level: level, isExpanded: isExpanded, hasChildren: hasChildren, systemName: "folder")
    }
    
    // ノーマルセル用
    func configure(normalText: String) {
        isNormalCell = true
        configureCell(name: normalText, level: 0, isExpanded: false, hasChildren: false, systemName: "circle.fill")
    }
    
    // メイン設定
    func configureCell(name: String, level: Int, isExpanded: Bool, hasChildren: Bool, systemName: String) {
        titleLabel.text = name
        leadingConstraint.constant = CGFloat(16 + level * 24)
        folderIcon.image = UIImage(systemName: systemName)
        folderIcon.tintColor = isNormalCell ? .systemGray : .systemBlue
        
        // 右端矢印
        if hasChildren {
            chevronIcon.isHidden = false
            chevronIcon.image = UIImage(systemName: "chevron.right") // 常に右向き画像
            rotateChevron(expanded: isExpanded, animated: false)    // 回転で下向きにする
        } else {
            chevronIcon.isHidden = true
        }
    }
}
