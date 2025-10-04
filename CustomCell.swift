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
    let arrowImageView = UIImageView()
    let arrowTapArea = UIView()
    var leadingConstraint: NSLayoutConstraint!
    
    var arrowTapAction: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        arrowTapArea.translatesAutoresizingMaskIntoConstraints = false

        arrowImageView.tintColor = .gray
        arrowImageView.isUserInteractionEnabled = false
        arrowTapArea.isUserInteractionEnabled = true

        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(arrowTapArea)
        arrowTapArea.addSubview(arrowImageView)

        leadingConstraint = iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)

        NSLayoutConstraint.activate([
            leadingConstraint,
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            // 🔸 矢印タップエリアを大きく確保（ヒットエリア）
            arrowTapArea.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            arrowTapArea.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            arrowTapArea.widthAnchor.constraint(equalToConstant: 44),
            arrowTapArea.heightAnchor.constraint(equalToConstant: 44),

            // 🔸 矢印を少し大きめに（例: 20pt）
            arrowImageView.centerXAnchor.constraint(equalTo: arrowTapArea.centerXAnchor),
            arrowImageView.centerYAnchor.constraint(equalTo: arrowTapArea.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 20),
            arrowImageView.heightAnchor.constraint(equalToConstant: 20)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapArrow))
        arrowTapArea.addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func didTapArrow() {
        arrowTapAction?()
    }
    
    override func prepareForReuse() {
            super.prepareForReuse()
            arrowImageView.transform = .identity // ← 再利用時に反転解除
        }

    func configure(with folder: Folder, level: Int, isExpanded: Bool) {
        titleLabel.text = folder.folderName
        leadingConstraint.constant = 16 + CGFloat(level) * 20
        
        let hasChildren = (folder.children?.count ?? 0) > 0
        arrowTapArea.isHidden = !hasChildren
        arrowImageView.image = UIImage(systemName: isExpanded ? "chevron.down" : "chevron.right")
    }

}
