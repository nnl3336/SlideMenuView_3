//
//  CustomCell.swift
//  SlideMenuView_3
//
//  Created by Yuki Sasaki on 2025/10/03.
//

import SwiftUI

// MARK: - CustomCell
class CustomCell: UITableViewCell {

    static let reuseID = "CustomCell"

    private let nameLabel = UILabel()
    private let iconImageView = UIImageView()
    private let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.right"))

    var chevronTapped: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapChevron))
        chevronImageView.isUserInteractionEnabled = true
        chevronImageView.addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        contentView.addSubview(iconImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(chevronImageView)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),

            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 10),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            chevronImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            chevronImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    func configureCell(name: String, level: Int, isExpanded: Bool, hasChildren: Bool, systemName: String) {
        nameLabel.text = name
        iconImageView.image = UIImage(systemName: systemName)

        // 階層ごとのインデント
        contentView.layoutMargins = UIEdgeInsets(top: 0, left: CGFloat(level * 20), bottom: 0, right: 0)

        // 親フォルダだけ矢印表示
        chevronImageView.isHidden = !hasChildren
        rotateChevron(expanded: isExpanded, animated: false)
    }

    @objc private func didTapChevron() {
        chevronTapped?()
    }

    // 回転アニメーション
    func rotateChevron(expanded: Bool, animated: Bool = true) {
        let angle: CGFloat = expanded ? .pi / 2 : 0
        if animated {
            UIView.animate(withDuration: 0.25) {
                self.chevronImageView.transform = CGAffineTransform(rotationAngle: angle)
            }
        } else {
            chevronImageView.transform = CGAffineTransform(rotationAngle: angle)
        }
    }
}
