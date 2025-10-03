//
//  CustomCell.swift
//  SlideMenuView_3
//
//  Created by Yuki Sasaki on 2025/10/03.
//

import SwiftUI

class CustomCell: UITableViewCell {
    let iconView = UIImageView()
    let titleLabel = UILabel()
    let arrowImageView = UIImageView() // ← 追加
    var leadingConstraint: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.tintColor = .gray

        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(arrowImageView) // ← 追加

        leadingConstraint = iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        NSLayoutConstraint.activate([
            leadingConstraint,
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            arrowImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            arrowImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 12),
            arrowImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with folder: Folder, isExpanded: Bool) {
        titleLabel.text = folder.folderName
        arrowImageView.isHidden = (folder.children?.count ?? 0) == 0
        arrowImageView.image = UIImage(systemName: isExpanded ? "chevron.down" : "chevron.right")
    }
}
