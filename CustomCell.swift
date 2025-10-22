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
    let titleLabel = UILabel()
    let chevronIcon = UIImageView()
    private var leadingConstraint: NSLayoutConstraint!

    // --- 新規追加 ---
    let hideSwitch = UISwitch()
    var switchChanged: ((Bool) -> Void)?  // 値変更時のコールバック

    var chevronTapped: (() -> Void)?
    private var level: Int = 0
    private var hasChildren: Bool = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        folderIcon.translatesAutoresizingMaskIntoConstraints = false
        folderIcon.contentMode = .scaleAspectFit
        folderIcon.tintColor = .systemBlue

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 20, weight: .medium)

        chevronIcon.translatesAutoresizingMaskIntoConstraints = false
        chevronIcon.contentMode = .scaleAspectFit
        chevronIcon.tintColor = .systemGray
        chevronIcon.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(chevronTappedAction))
        chevronIcon.addGestureRecognizer(tap)

        hideSwitch.translatesAutoresizingMaskIntoConstraints = false
        hideSwitch.isHidden = true // デフォルトは非表示

        contentView.addSubview(folderIcon)
        contentView.addSubview(titleLabel)
        contentView.addSubview(chevronIcon)
        contentView.addSubview(hideSwitch) // 追加

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

            chevronIcon.trailingAnchor.constraint(equalTo: hideSwitch.leadingAnchor, constant: -8),
            chevronIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronIcon.widthAnchor.constraint(equalToConstant: 20),
            chevronIcon.heightAnchor.constraint(equalToConstant: 20),

            hideSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            hideSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        titleLabel.numberOfLines = 0
    }

    @objc private func chevronTappedAction() {
        chevronTapped?()
    }
    
    // MARK: -　isHideスイッチ
    
    @objc private func switchToggled() {
        switchChanged?(hideSwitch.isOn)
    }

    //

    // --- 新規: 編集モード用 configure ---
    func configureCell(
        name: String,
        level: Int,
        isExpanded: Bool,
        hasChildren: Bool,
        systemName: String,
        tintColor: UIColor,
        isEditMode: Bool,
        isHide: Bool
    ) {
        titleLabel.text = name
        self.level = level
        self.hasChildren = hasChildren

        folderIcon.image = UIImage(systemName: systemName)?.withRenderingMode(.alwaysTemplate)
        folderIcon.tintColor = .systemBlue

        chevronIcon.isHidden = !hasChildren
        chevronIcon.tintColor = tintColor
        chevronIcon.image = UIImage(systemName: "chevron.right")?.withRenderingMode(.alwaysTemplate)
        chevronIcon.transform = isExpanded ? CGAffineTransform(rotationAngle: .pi/2) : .identity

        leadingConstraint.constant = 16 + CGFloat(level * 20)

        // 編集モードでスイッチ表示
        hideSwitch.isHidden = !isEditMode
        hideSwitch.isOn = isHide
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

    func updateSelectionAppearance(isSelected: Bool) {
        self.contentView.backgroundColor = isSelected ? UIColor.systemBlue.withAlphaComponent(0.2) : .systemBackground
    }
}
