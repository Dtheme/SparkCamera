//
//  SCCameraToolOptionsView.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import UIKit
import SnapKit
import SwiftMessages

protocol SCCameraToolOptionsViewDelegate: AnyObject {
    func optionsView(_ optionsView: SCCameraToolOptionsView, didSelect option: SCToolOption, for type: SCToolType)
}

// MARK: - Array Extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

class SCCameraToolOptionsView: UIView {
    
    // MARK: - Properties
    weak var delegate: SCCameraToolOptionsViewDelegate?
    private var type: SCToolType
    private var options: [SCToolOption]
    private var selectedIndex: Int = 0
    private var gradientLayer: CAGradientLayer?
    
    // MARK: - UI Components
    private lazy var blurView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .dark)
        let view = UIVisualEffectView(effect: blurEffect)
        view.clipsToBounds = true
        view.backgroundColor = .clear
        view.alpha = 0.5  // 降低模糊效果的不透明度
        return view
    }()
    
    private lazy var maskLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        return layer
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 15
        layout.minimumLineSpacing = 15
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize  // 使用自动大小
        layout.sectionInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.delegate = self
        collection.dataSource = self
        collection.showsHorizontalScrollIndicator = false
        collection.register(OptionCell.self, forCellWithReuseIdentifier: "OptionCell")
        collection.alwaysBounceHorizontal = true
        return collection
    }()
    
    // MARK: - Initialization
    init(type: SCToolType, options: [SCToolOption]) {
        self.type = type
        self.options = options
        
        // 找到选中的选项索引
        selectedIndex = options.firstIndex(where: { $0.isSelected }) ?? 0
        
        super.init(frame: .zero)
        setupUI()
        
        // 打印初始化时的选项信息
        print("📸 [ToolOptions] 工具类型: \(type)")
        print("📸 [ToolOptions] 可用选项数量: \(options.count)")
        print("📸 [ToolOptions] 选项列表:")
        options.enumerated().forEach { index, option in
            print("  \(index + 1). \(option.title) (状态: \(String(describing: option.state)))")
        }
        print("📸 [ToolOptions] 当前选中索引: \(selectedIndex)")
        if let selectedOption = options[safe: selectedIndex] {
            print("📸 [ToolOptions] 当前选中选项: \(selectedOption.title)")
            print("📸 [ToolOptions] 当前选中状态: \(String(describing: selectedOption.state))")
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(blurView)
        blurView.contentView.addSubview(collectionView)
        
        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 创建左直角右圆角的路径
        let path = UIBezierPath()
        let radius: CGFloat = 12 // 调整圆角大小与工具栏一致
        
        // 从左上角开始，顺时针绘制
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: bounds.width - radius, y: 0))
        path.addArc(withCenter: CGPoint(x: bounds.width - radius, y: radius),
                   radius: radius,
                   startAngle: -CGFloat.pi/2,
                   endAngle: 0,
                   clockwise: true)
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height - radius))
        path.addArc(withCenter: CGPoint(x: bounds.width - radius, y: bounds.height - radius),
                   radius: radius,
                   startAngle: 0,
                   endAngle: CGFloat.pi/2,
                   clockwise: true)
        path.addLine(to: CGPoint(x: 0, y: bounds.height))
        path.close()
        
        // 应用遮罩
        maskLayer.path = path.cgPath
        blurView.layer.mask = maskLayer
    }
    
    // MARK: - Animation
    func show(from sourceView: UIView) {
        // 打印展开时的选中状态
        print("📸 [ToolOptions] 展开选项视图")
        print("📸 [ToolOptions] 当前选中索引: \(selectedIndex)")
        if selectedIndex < options.count {
            let selectedOption = options[selectedIndex]
            print("📸 [ToolOptions] 当前选中选项: \(selectedOption.title)")
            print("📸 [ToolOptions] 当前选中状态: \(String(describing: selectedOption.state))")
        }
        
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut], animations: {
            self.alpha = 1
            self.transform = .identity
        })
    }
    
    func hide(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut], animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
}

// MARK: - UICollectionViewDataSource
extension SCCameraToolOptionsView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return options.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "OptionCell", for: indexPath) as! OptionCell
        let option = options[indexPath.item]
        cell.configure(with: option.title, isSelected: indexPath.item == selectedIndex)
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension SCCameraToolOptionsView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // 更新选中状态
        selectedIndex = indexPath.item
        collectionView.reloadData()
        
        // 获取选中的选项
        let selectedOption = options[indexPath.item]
        
        // 打印选择信息
        print("📸 [ToolOptions] 用户选择了新选项")
        print("📸 [ToolOptions] 选中索引: \(indexPath.item)")
        print("📸 [ToolOptions] 选中选项: \(selectedOption.title)")
        print("📸 [ToolOptions] 选中状态: \(String(describing: selectedOption.state))")
        
        // 通知代理
        delegate?.optionsView(self, didSelect: selectedOption, for: type)
    }
}

// MARK: - OptionCell
private class OptionCell: UICollectionViewCell {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 15)
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10))  // 添加水平内边距
            make.height.equalTo(80)  // 固定高度
        }
    }
    
    func configure(with title: String, isSelected: Bool = false) {
        titleLabel.text = title
        titleLabel.textColor = isSelected ? UIColor.yellow : .white
        titleLabel.font = isSelected ? .systemFont(ofSize: 15, weight: .medium) : .systemFont(ofSize: 15, weight: .regular)
    }
    
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let targetSize = CGSize(width: UIView.layoutFittingExpandedSize.width, height: 80)
        let size = contentView.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .fittingSizeLevel, verticalFittingPriority: .required)
        attributes.frame = CGRect(origin: attributes.frame.origin, size: size)
        return attributes
    }
}
