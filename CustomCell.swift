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
    let arrowTapArea = UIView()
    let arrowImageView = UIImageView()
    var leadingConstraint: NSLayoutConstraint!
    var arrowTapAction: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        arrowTapArea.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false

        arrowImageView.tintColor = .systemGray
        // ミラーを確実に防ぐ（初期化時に固定）
        arrowImageView.semanticContentAttribute = .forceLeftToRight
        arrowImageView.contentMode = .scaleAspectFit

        arrowTapArea.isUserInteractionEnabled = true
        arrowTapArea.backgroundColor = .clear

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

            arrowTapArea.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            arrowTapArea.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            arrowTapArea.widthAnchor.constraint(equalToConstant: 44),
            arrowTapArea.heightAnchor.constraint(equalToConstant: 44),

            arrowImageView.centerXAnchor.constraint(equalTo: arrowTapArea.centerXAnchor),
            arrowImageView.centerYAnchor.constraint(equalTo: arrowTapArea.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 20),
            arrowImageView.heightAnchor.constraint(equalToConstant: 20)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapArrow))
        arrowTapArea.addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        // 再利用時に状態をクリア（transform や semantic を確実に初期化）
        arrowImageView.transform = .identity
        arrowImageView.semanticContentAttribute = .forceLeftToRight
        arrowImageView.image = nil
    }

    @objc private func didTapArrow() {
        arrowTapAction?()
    }

    func configure(with folder: Folder, level: Int, isExpanded: Bool) {
        titleLabel.text = folder.folderName
        leadingConstraint.constant = 16 + CGFloat(level) * 20

        let hasChildren = (folder.children?.count ?? 0) > 0
        arrowTapArea.isHidden = !hasChildren

        // ここでは「画像そのもの」を切り替える（回転はしない）
        if hasChildren {
            let imageName = isExpanded ? "chevron.down" : "chevron.right"
            arrowImageView.image = UIImage(systemName: imageName)?.withRenderingMode(.alwaysTemplate)
            // 方向固定（念のため）
            arrowImageView.semanticContentAttribute = .forceLeftToRight
        } else {
            arrowImageView.image = nil
        }
    }
}
