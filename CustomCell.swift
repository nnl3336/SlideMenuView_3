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
    /*private*/ let titleLabel = UILabel()
    let chevronIcon = UIImageView()
    private var leadingConstraint: NSLayoutConstraint!
    
    var chevronTapped: (() -> Void)?
    private var level: Int = 0
    private var hasChildren: Bool = false

    //private let hideSwitch = UISwitch()
    //var hideSwitchChanged: ((Bool) -> Void)?
    
    /*var isHide: Bool = false {
        didSet { hideSwitch.isOn = isHide }
    }*/

    //***
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }
    
    //***
    
    /*@objc private func switchChanged() {
        isHide = hideSwitch.isOn
        hideSwitchChanged?(isHide)  // 🔹 ここで ViewController に通知
    }*/

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
        chevronTapped?()
    }

    func configureCell(name: String, level: Int, isExpanded: Bool, hasChildren: Bool, systemName: String, tintColor: UIColor) {
        titleLabel.text = name
        self.level = level
        self.hasChildren = hasChildren

        folderIcon.image = UIImage(systemName: systemName)?.withRenderingMode(.alwaysTemplate)
        folderIcon.tintColor = .systemBlue

        chevronIcon.isHidden = !hasChildren
        chevronIcon.tintColor = tintColor
        chevronIcon.image = UIImage(systemName: "chevron.right")?.withRenderingMode(.alwaysTemplate)
        
        // 展開状態に応じて transform
        chevronIcon.transform = isExpanded ? CGAffineTransform(rotationAngle: .pi/2) : .identity

        leadingConstraint.constant = 16 + CGFloat(level * 20)
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
}
