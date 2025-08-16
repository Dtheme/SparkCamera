//
//  SCAutoSaveSelectorView.swift
//  SparkCamera
//
//  Created by AI on 2025/08/16.
//

import UIKit
import SnapKit

final class SCAutoSaveSelectorView: UIView {
    enum Mode: Int {
        case off = 0
        case jpeg = 1
        case raw = 2
        
        var title: String {
            switch self {
            case .off: return "不自动保存"
            case .jpeg: return "保存 JPEG"
            case .raw: return "保存 RAW"
            }
        }
        
        var iconName: String {
            switch self {
            case .off: return "nosign"
            case .jpeg: return "photo.on.rectangle"
            case .raw: return "doc"
            }
        }
    }
    
    // MARK: - Properties
    var onSelect: ((Mode) -> Void)?
    var currentMode: Mode = .off { didSet { updateSelection() } }
    
    // UI
    private let container = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
    private let stack = UIStackView()
    private var rowViews: [Mode: UIView] = [:]
    
    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Public
    func present(anchor: UIView, in parent: UIView) {
        if superview == nil { parent.addSubview(self) }
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        
        // 布局在按钮上方（或下方，取可用空间）
        let anchorFrame = anchor.convert(anchor.bounds, to: parent)
        snp.remakeConstraints { make in
            make.centerX.equalTo(anchorFrame.midX)
            make.width.equalTo(220)
        }
        parent.layoutIfNeeded()
        
        // 计算在上方或下方的位置
        let margin: CGFloat = 12
        let preferredYAbove = anchorFrame.minY - 10 - 140
        let placeAbove = preferredYAbove > parent.safeAreaInsets.top + margin
        snp.updateConstraints { make in
            if placeAbove {
                make.bottom.equalTo(anchor.snp.top).offset(-10)
            } else {
                make.top.equalTo(anchor.snp.bottom).offset(10)
            }
        }
        parent.layoutIfNeeded()
        
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            self.alpha = 1
            self.transform = .identity
        }
    }
    
    // MARK: - Private
    private func setupUI() {
        backgroundColor = .clear
        layer.masksToBounds = false
        
        addSubview(container)
        container.layer.cornerRadius = 14
        container.clipsToBounds = true
        container.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let content = UIStackView()
        content.axis = .vertical
        content.alignment = .fill
        content.distribution = .fill
        content.spacing = 0
        container.contentView.addSubview(content)
        content.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 标题
        let titleLabel = UILabel()
        titleLabel.text = "自动保存"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        titleLabel.snp.makeConstraints { _ in }
        titleLabel.heightAnchor.constraint(equalToConstant: 36).isActive = true
        content.addArrangedSubview(titleLabel)
        
        // 选项区域
        let optionsContainer = UIStackView()
        optionsContainer.axis = .vertical
        optionsContainer.alignment = .fill
        optionsContainer.distribution = .fillEqually
        optionsContainer.spacing = 0
        content.addArrangedSubview(optionsContainer)
        
        func makeRow(_ mode: Mode) -> UIView {
            let row = UIControl()
            row.backgroundColor = .clear
            row.snp.makeConstraints { make in
                make.height.equalTo(48)
            }
            
            let icon = UIImageView(image: UIImage(systemName: mode.iconName))
            icon.tintColor = .white
            icon.contentMode = .scaleAspectFit
            row.addSubview(icon)
            icon.snp.makeConstraints { make in
                make.left.equalToSuperview().offset(14)
                make.centerY.equalToSuperview()
                make.width.height.equalTo(20)
            }
            
            let label = UILabel()
            label.text = mode.title
            label.textColor = .white
            label.font = .systemFont(ofSize: 15, weight: .medium)
            row.addSubview(label)
            label.snp.makeConstraints { make in
                make.left.equalTo(icon.snp.right).offset(10)
                make.centerY.equalToSuperview()
            }
            
            let check = UIImageView(image: UIImage(systemName: "checkmark"))
            check.tintColor = SCConstants.themeColor
            check.isHidden = true
            row.addSubview(check)
            check.snp.makeConstraints { make in
                make.right.equalToSuperview().offset(-14)
                make.centerY.equalToSuperview()
                make.width.height.equalTo(16)
            }
            
            row.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
            row.tag = mode.rawValue
            
            // 分隔线
            let sep = UIView()
            sep.backgroundColor = UIColor.white.withAlphaComponent(0.08)
            row.addSubview(sep)
            sep.snp.makeConstraints { make in
                make.left.equalTo(label)
                make.right.equalToSuperview()
                make.bottom.equalToSuperview()
                make.height.equalTo(0.5)
            }
            
            rowViews[mode] = row
            return row
        }
        
        optionsContainer.addArrangedSubview(makeRow(.off))
        optionsContainer.addArrangedSubview(makeRow(.jpeg))
        optionsContainer.addArrangedSubview(makeRow(.raw))
        
        // 底部安全留白
        let bottomSpacer = UIView()
        bottomSpacer.backgroundColor = .clear
        bottomSpacer.snp.makeConstraints { _ in }
        bottomSpacer.heightAnchor.constraint(equalToConstant: 6).isActive = true
        content.addArrangedSubview(bottomSpacer)
        
        updateSelection()
    }
    
    private func updateSelection() {
        for (mode, row) in rowViews {
            let isSelected = (mode == currentMode)
            if let check = row.subviews.compactMap({ $0 as? UIImageView }).last {
                check.isHidden = !isSelected
            }
            row.backgroundColor = isSelected ? UIColor.white.withAlphaComponent(0.06) : .clear
        }
    }
    
    @objc private func rowTapped(_ sender: UIControl) {
        guard let mode = Mode(rawValue: sender.tag) else { return }
        currentMode = mode
        onSelect?(mode)
    }
}


