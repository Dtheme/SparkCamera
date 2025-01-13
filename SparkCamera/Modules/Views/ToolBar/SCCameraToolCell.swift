//
//  SCCameraToolCell.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/20.
//


import UIKit
import SnapKit

class SCCameraToolCell: UICollectionViewCell {
    
    static let reuseIdentifier = "SCCameraToolCell"
    
    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.layer.cornerRadius = 25
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 12)
        return label
    }()
    
    
    // MARK: - Properties
    var item: SCToolItem? {
        didSet {
            updateUI()
        }
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.addSubview(iconView)
        containerView.addSubview(titleLabel)
        
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 50, height: 50))
        }
        
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 24, height: 24))
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(containerView.snp.bottom).offset(4)
            make.left.right.equalToSuperview()
        }
        
//        selectedIndicator.snp.makeConstraints { make in
//            make.centerX.equalToSuperview()
//            make.bottom.equalTo(containerView).offset(-4)
//            make.width.equalTo(20)
//            make.height.equalTo(4)
//        }
    }
    
    private func updateUI() {
        guard let item = item else { return }
        
        iconView.image = item.icon
        titleLabel.text = item.title
//        selectedIndicator.isHidden = !item.isSelected
        
        // 更新启用/禁用状态
        containerView.alpha = item.isEnabled ? 1.0 : 0.5
        titleLabel.alpha = item.isEnabled ? 1.0 : 0.5
        isUserInteractionEnabled = item.isEnabled
    }
    
    // MARK: - Animation
    func animateSelection() {
        UIView.animate(withDuration: 0.3,
                      delay: 0,
                      usingSpringWithDamping: 0.6,
                      initialSpringVelocity: 0.2,
                      options: [.curveEaseOut],
                      animations: {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.2,
                          delay: 0,
                          usingSpringWithDamping: 0.6,
                          initialSpringVelocity: 0.2,
                          options: [.curveEaseOut],
                          animations: {
                self.transform = .identity
            })
        }
    }
    
    func animateStateChange() {
        guard let item = item else { return }
        
        // 图标缩放动画
        UIView.animate(withDuration: 0.2,
                      delay: 0,
                      usingSpringWithDamping: 0.6,
                      initialSpringVelocity: 0.2,
                      options: [.curveEaseOut],
                      animations: {
            self.iconView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            // 更新图标
            self.iconView.image = item.state?.icon
            
            // 恢复图标大小
            UIView.animate(withDuration: 0.2,
                          delay: 0,
                          usingSpringWithDamping: 0.6,
                          initialSpringVelocity: 0.2,
                          options: [.curveEaseOut],
                          animations: {
                self.iconView.transform = .identity
            })
        }
        
        // 标题渐变动画
        UIView.transition(with: titleLabel,
                         duration: 0.2,
                         options: .transitionCrossDissolve,
                         animations: {
            self.titleLabel.text = item.state?.title
        })
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 更新圆角
        layer.cornerRadius = 12
        contentView.layer.cornerRadius = 12
        
        // 更新阴影
        if item?.isSelected == true {
            layer.shadowColor = SCConstants.themeColor.cgColor
            layer.shadowOpacity = 0.3
            layer.shadowOffset = .zero
            layer.shadowRadius = 4
        } else {
            layer.shadowOpacity = 0
        }
    }
    
    // MARK: - Configuration
    func configure(with item: SCToolItem) {
        self.item = item
        
        iconView.image = item.icon
        titleLabel.text = item.title
//        selectedIndicator.isHidden = !item.isSelected
        
        // 更新启用/禁用状态
        containerView.alpha = item.isEnabled ? 1.0 : 0.5
        titleLabel.alpha = item.isEnabled ? 1.0 : 0.5
        isUserInteractionEnabled = item.isEnabled
        
        // 更新选中状态
        if item.isSelected {
            containerView.backgroundColor = UIColor(white: 1.0, alpha: 0.2)
            titleLabel.textColor = SCConstants.themeColor
        } else {
            containerView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            titleLabel.textColor = .white
        }
        
        setNeedsLayout()
    }
} 
