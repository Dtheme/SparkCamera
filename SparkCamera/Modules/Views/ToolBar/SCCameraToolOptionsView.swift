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

class SCCameraToolOptionsView: UIView {
    
    // MARK: - Properties
    weak var delegate: SCCameraToolOptionsViewDelegate?
    private var type: SCToolType
    private var options: [SCToolOption]
    private var selectedIndex: Int = 0
    private var gradientLayer: CAGradientLayer?
    private var itemTitle: String
    
    // 添加滑块视图
    private lazy var scaleSlider: SCScaleSlider? = {
        if type == .exposure {
            let config = SCScaleSliderConfig(minValue: -2.0,
                                           maxValue: 2.0,
                                           step: 0.1,
                                           defaultValue: 0.0)
            let slider = SCScaleSlider(config: config)
            slider.style = .Style.vertical.style
            slider.valueChangedHandler = { [weak self] value in
                self?.handleSliderValueChanged(value)
            }
            return slider
        }
        return nil
    }()
    
    // MARK: - UI Components
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.textAlignment = .right
        label.text = itemTitle
        return label
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
    init(type: SCToolType, options: [SCToolOption], selectedIndex: Int = 0, itemTitle: String) {
        self.type = type
        self.options = options
        self.selectedIndex = selectedIndex
        self.itemTitle = itemTitle
        
        super.init(frame: .zero)
        setupUI()
        
        // 打印选项信息
        print("📸 [ToolOptions] 工具类型: \(type)")
        print("📸 [ToolOptions] 可用选项数量: \(options.count)")
        print("📸 [ToolOptions] 选项列表:")
        options.enumerated().forEach { index, option in
            print("  \(index + 1). \(option.title) (状态: \(String(describing: option.state)))")
        }
        print("📸 [ToolOptions] 当前选中索引: \(selectedIndex)")
        
        if selectedIndex < options.count {
            let selectedOption = options[selectedIndex]
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
        
        self.addSubview(collectionView)
        self.addSubview(titleLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.right.equalToSuperview().offset(-15)
            make.height.equalTo(20)
        }
        
        collectionView.snp.makeConstraints { make in
            make.left.right.bottom.top.equalToSuperview()
//            make.top.equalTo(titleLabel.snp.bottom).offset(8)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    // MARK: - Animation
    func show(from sourceView: UIView) {
        print("📸 [ToolOptions] 展开选项视图")
        print("📸 [ToolOptions] 当前选中索引: \(selectedIndex)")
        if selectedIndex < options.count {
            let selectedOption = options[selectedIndex]
            print("📸 [ToolOptions] 当前选中选项: \(selectedOption.title)")
            print("📸 [ToolOptions] 当前选中状态: \(String(describing: selectedOption.state))")
        }
        
        // 更新选中状态
        collectionView.reloadData()
        
        // 确保选中项可见
        if selectedIndex < options.count {
            let indexPath = IndexPath(item: selectedIndex, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
        }
        
        // 动画显示
        transform = CGAffineTransform(translationX: 0, y: -20)
        alpha = 0
        
        UIView.animate(withDuration: 0.3,
                      delay: 0,
                      usingSpringWithDamping: 0.8,
                      initialSpringVelocity: 0.5,
                      options: .curveEaseOut,
                      animations: {
            self.transform = .identity
            self.alpha = 1
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
    
    private func handleSliderValueChanged(_ value: Float) {
        // 创建一个自定义的 SCToolOption 来表示滑块值
        let option = SCDefaultToolOption(
            title: String(format: "%.1f", value),
            state: SCExposureState.custom(value: value),
            isSelected: true
        )
        delegate?.optionsView(self, didSelect: option, for: type)
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
