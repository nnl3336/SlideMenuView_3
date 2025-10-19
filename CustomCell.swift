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
    
    var chevronTapped: (() -> Void)? // タップ時のコールバック
    private var isSearching = false
    
    private var level: Int = 0
    private var hasChildren: Bool = false

    // Enumでセルタイプを管理
    enum CellType {
        case coreData(folder: Folder, level: Int, isExpanded: Bool)
        case normal(text: String)
    }
    
    // MARK: - init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default
        setupViews()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    // MARK: - UI setup
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
            chevronIcon.widthAnchor.constraint(equalToConstant: 20),
            chevronIcon.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        titleLabel.numberOfLines = 0
    }

    @objc private func chevronTappedAction() {
        guard !isSearching else { return }
        chevronTapped?()
    }
    
    func setSearching(_ searching: Bool) {
        self.isSearching = searching
        chevronIcon.alpha = searching ? 0.5 : 1.0
        chevronIcon.isUserInteractionEnabled = !searching
        chevronIcon.tintColor = searching ? .systemGray : .systemBlue
    }
    
    func rotateChevron(expanded: Bool, animated: Bool = true) {
        let angle: CGFloat = expanded ? .pi/2 : 0
        if animated {
            UIView.animate(withDuration: 0.25) {
                self.chevronIcon.transform = CGAffineTransform(rotationAngle: angle)
            }
        } else {
            self.chevronIcon.transform = CGAffineTransform(rotationAngle: angle)
        }
    }
    
    // MARK: - Configure
    func configure(cellType: CellType) {
        switch cellType {
        case .coreData(let folder, let level, let isExpanded):
            let name = folder.folderName ?? "無題"
            let hasChildren = (folder.children?.count ?? 0) > 0
            configureCell(name: name, level: level, isExpanded: isExpanded, hasChildren: hasChildren, systemName: "folder", tintColor: .systemBlue)
        case .normal(let text):
            configureCell(name: text, level: 0, isExpanded: false, hasChildren: false, systemName: "circle.fill", tintColor: .systemGray)
        }
    }
    
    func configureCell(name: String, level: Int, isExpanded: Bool, hasChildren: Bool, systemName: String, tintColor: UIColor) {
        titleLabel.text = name
        self.level = level
        self.hasChildren = hasChildren

        folderIcon.image = UIImage(systemName: systemName)?.withRenderingMode(.alwaysTemplate)
        folderIcon.tintColor = .systemBlue

        chevronIcon.isHidden = !hasChildren
        chevronIcon.tintColor = tintColor
        let imageName = isExpanded ? "chevron.down" : "chevron.right"
        chevronIcon.image = UIImage(systemName: imageName)?.withRenderingMode(.alwaysTemplate)

        leadingConstraint.constant = 16 + CGFloat(level * 20)
    }
    /*func configureCell(name: String, level: Int, isExpanded: Bool, hasChildren: Bool, systemName: String, tintColor: UIColor) {
        titleLabel.text = name
        self.level = level
        self.hasChildren = hasChildren

        folderIcon.image = UIImage(systemName: systemName)?.withRenderingMode(.alwaysTemplate)
        folderIcon.tintColor = .systemBlue

        chevronIcon.isHidden = !hasChildren
        chevronIcon.tintColor = tintColor
        let imageName = isExpanded ? "chevron.down" : "chevron.right"
        chevronIcon.image = UIImage(systemName: imageName)?.withRenderingMode(.alwaysTemplate)

        leadingConstraint.constant = 16 + CGFloat(level * 20)

        // ←追加
        chevronIcon.transform = .identity
        if isExpanded {
            chevronIcon.transform = CGAffineTransform(rotationAngle: .pi/2)
        }
    }*/

}
