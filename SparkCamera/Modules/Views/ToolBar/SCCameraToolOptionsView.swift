//
//  SCCameraToolOptionsView.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import UIKit
import SnapKit
import SwiftMessages
import AVFoundation

// MARK: - Cell
class SCCameraToolOptionCell: UICollectionViewCell {
    
    // MARK: - UI Components
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14)
        label.textColor = .white
        return label
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }
    }
    
    // MARK: - Configuration
    func configure(with title: String, isSelected: Bool) {
        titleLabel.text = title
        titleLabel.textColor = isSelected ? SCConstants.themeColor : .white
        titleLabel.font = isSelected ? .systemFont(ofSize: 14, weight: .medium) : .systemFont(ofSize: 14)
    }
}

// MARK: - 选项视图代理
protocol SCCameraToolOptionsViewDelegate: AnyObject {
    func optionsView(_ optionsView: SCCameraToolOptionsView, didSelect option: SCToolOption, for type: SCToolType)
    func optionsView(_ optionsView: SCCameraToolOptionsView, didChangeSliderValue value: Float, for type: SCToolType)
}

/// 工具栏选项视图类型
public enum SCCameraToolOptionsViewType {
    case normal
    case scale
}

class SCCameraToolOptionsView: UIView {
    
    // MARK: - Properties
    weak var delegate: SCCameraToolOptionsViewDelegate?
    public var type: SCCameraToolOptionsViewType = .normal
    private var options: [SCToolOption] = []
    private var selectedOption: SCToolOption?
    private var toolType: SCToolType?
    private var selectedIndex: Int = 0
    
    var didSelectOption: ((SCToolOption) -> Void)?
//    var didChangeValue: ((Float) -> Void)?
    
    // MARK: - UI Components
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(SCCameraToolOptionCell.self, forCellWithReuseIdentifier: "OptionCell")
        return collectionView
    }()
    
    private lazy var scaleSlider: SCScaleSlider = {
        // 使用固定的用户友好范围 -2 ~ 2
        let config = SCScaleSliderConfig(
            minValue: -2.0,
            maxValue: 2.0,
            step: 0.1,
            defaultValue: 0.0
        )
        
        print("📏 [ScaleSlider] 初始化配置：")
        print("📏 [ScaleSlider] 用户范围：[-2.0, 2.0]")
        print("📏 [ScaleSlider] 步长：\(config.step)")
        
        let slider = SCScaleSlider(config: config)
        var customStyle = SCScaleSliderStyle.Style.vertical.style
        customStyle.scaleWidth = 10
        slider.style = customStyle
        
        // 设置值变化回调
        slider.valueChangedHandler = { [weak self] value in
            guard let self = self,
                  let toolType = self.toolType else { return }
            
            print("📏 [ScaleSlider] 用户值：\(value)")
            
            // 通过代理传递值变化
            self.delegate?.optionsView(self, didChangeSliderValue: value, for: toolType)
        }
        
        return slider
    }()
    
    // MARK: - Initialization
    init(toolType: SCToolType, options: [SCToolOption], selectedIndex: Int, itemTitle: String) {
        super.init(frame: .zero)
        self.toolType = toolType
        self.options = options
        self.selectedIndex = selectedIndex
        
        // 根据工具类型决定视图类型
        self.type = toolType == .exposure ? .scale : .normal
        
        setupUI()
        configure(with: options)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(collectionView)
        addSubview(scaleSlider)
        
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        scaleSlider.snp.makeConstraints { make in
//            make.left.right.equalToSuperview()
//            make.centerY.equalToSuperview()
//            make.height.equalTo(80)
            make.edges.equalToSuperview()
        }
        
        // 默认隐藏 scaleSlider
        scaleSlider.isHidden = true


        // 设置 scaleSlider 的值变化回调
        scaleSlider.valueChangedHandler = { [weak self] value in
            guard let self = self,
                  let toolType = self.toolType else { return }

            print("📏 [ScaleSlider] 原始值：\(value)")
            if toolType == .exposure {
                let range = SCCameraSettingsManager.shared.exposureRange
                print("📏 [ScaleSlider] 设备支持范围：[\(range.min), \(range.max)]")
            }

            // 通过代理传递值变化
            self.delegate?.optionsView(self, didChangeSliderValue: value, for: toolType)
        }
    }
    
    // MARK: - Public Methods
    func configure(with options: [SCToolOption]) {
        self.options = options
        
        // 根据类型显示不同的视图
        switch type {
        case .normal:
            collectionView.isHidden = false
            scaleSlider.isHidden = true
            collectionView.reloadData()
        case .scale:
            collectionView.isHidden = true
            scaleSlider.isHidden = false
            
            // 如果是曝光调节，设置当前值
            if toolType == .exposure {
                let currentValue = SCCameraSettingsManager.shared.exposureValue
                scaleSlider.setValue(currentValue, animated: false)
            }
        }
    }
    
    func updateSelectedOption(_ option: SCToolOption) {
        self.selectedOption = option
        collectionView.reloadData()
    }
    
    /// 隐藏选项视图
    func hide() {
        // 重置状态
        selectedOption = nil
        selectedIndex = 0
        
        // 隐藏视图
        isHidden = true
        
        // 重置所有子视图状态
        collectionView.isHidden = true
        scaleSlider.isHidden = true
    }
    
    /// 显示选项视图
    func show() {
        isHidden = false
        
        // 根据类型显示对应的视图
        switch type {
        case .normal:
            collectionView.isHidden = false
            scaleSlider.isHidden = true
        case .scale:
            collectionView.isHidden = true
            scaleSlider.isHidden = false
        }
    }
}

// MARK: - UICollectionViewDataSource
extension SCCameraToolOptionsView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return options.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "OptionCell", for: indexPath) as! SCCameraToolOptionCell
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
        if let toolType = toolType {
            delegate?.optionsView(self, didSelect: selectedOption, for: toolType)
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension SCCameraToolOptionsView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let option = options[indexPath.item]
        let width = (option.title as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 14)]).width + 32
        return CGSize(width: width, height: collectionView.bounds.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    }
}
