//
//  SCPhotoInfoView.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/18.
//
//  图片预览界面的信息展示视图，显示图片的分辨率、比例、方向和文件大小等信息

import UIKit
import SnapKit

class SCPhotoInfoView: UIView {
    
    // MARK: - Properties
    private var mainStack: UIStackView!
    private let photoInfo: SCPhotoInfo
    private let image: UIImage
    private var saveStack: UIStackView!  // 保存对保存状态视图的引用
    
    // MARK: - Initialization
    init(image: UIImage, photoInfo: SCPhotoInfo) {
        self.image = image
        self.photoInfo = photoInfo
        super.init(frame: .zero)
        setupUI()
        
        // 添加通知监听
        NotificationCenter.default.addObserver(self, 
            selector: #selector(handlePhotoSaved), 
            name: NSNotification.Name("PhotoSavedToAlbum"), 
            object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // 设置容器样式
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        layer.cornerRadius = 15
        
        // 创建主堆栈视图
        mainStack = UIStackView()
        mainStack.axis = .horizontal
        mainStack.spacing = 25
        mainStack.alignment = .center
        mainStack.distribution = .equalSpacing
        addSubview(mainStack)
        
        // 1. 分辨率信息
        let resolutionStack = createInfoStack(
            icon: "photo",
            title: "分辨率",
            value: String(format: "%.0f×%.0f", photoInfo.width, photoInfo.height)
        )
        
        // 2. 方向信息
        let orientationStack = createInfoStack(
            icon: "rotate.right",
            title: "方向",
            value: photoInfo.isLandscape ? "横向" : "竖向"
        )
        
        // 3. 文件大小信息
        let imageData = image.jpegData(compressionQuality: 1.0)
        let fileSizeText: String
        if let size = imageData?.count {
            if size < 1024 * 1024 {
                fileSizeText = String(format: "%.1fKB", Double(size) / 1024.0)
            } else {
                fileSizeText = String(format: "%.1fMB", Double(size) / (1024.0 * 1024.0))
            }
        } else {
            fileSizeText = "未知"
        }
        let sizeStack = createInfoStack(
            icon: "doc",
            title: "大小",
            value: fileSizeText
        )
        
        // 4. 保存状态信息
        saveStack = createInfoStack(
            icon: photoInfo.isSavedToAlbum ? "checkmark.circle.fill" : "circle",
            title: "原图",
            value: photoInfo.isSavedToAlbum ? "已保存" : "未保存",
            valueColor: photoInfo.isSavedToAlbum ? .systemGreen : .white
        )
        
        // 添加所有信息堆栈到主堆栈
        [resolutionStack, orientationStack, sizeStack, saveStack].forEach {
            mainStack.addArrangedSubview($0)
        }
        
        // 设置约束
        mainStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 25, bottom: 10, right: 25))
        }
    }
    
    private func createInfoStack(icon: String, title: String, value: String, valueColor: UIColor = .white) -> UIStackView {
        // 创建垂直堆栈
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        
        // 创建标题行
        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.spacing = 2
        titleRow.alignment = .center
        
        // 创建图标
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        imageView.image = UIImage(systemName: icon, withConfiguration: config)
        imageView.tintColor = valueColor
        imageView.contentMode = .scaleAspectFit
        
        // 创建标题标签
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 11)
        
        // 添加图标和标题到标题行
        titleRow.addArrangedSubview(imageView)
        titleRow.addArrangedSubview(titleLabel)
        
        // 创建值标签
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.textColor = valueColor
        valueLabel.font = .systemFont(ofSize: 11, weight: .medium)
        valueLabel.textAlignment = .center
        
        // 添加到主堆栈
        stack.addArrangedSubview(titleRow)
        stack.addArrangedSubview(valueLabel)
        
        return stack
    }
    
    // MARK: - State Update
    @objc private func handlePhotoSaved() {
        updateSaveState(isSaved: true)
    }
    
    func updateSaveState(isSaved: Bool) {
        // 更新数据模型
        photoInfo.isSavedToAlbum = isSaved
        
        // 获取图标和值标签
        guard let stack = saveStack else { return }
        
        // 更新图标
        if let titleRow = stack.arrangedSubviews.first as? UIStackView,
           let imageView = titleRow.arrangedSubviews.first as? UIImageView {
            let config = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
            imageView.image = UIImage(systemName: isSaved ? "checkmark.circle.fill" : "circle", 
                withConfiguration: config)
            imageView.tintColor = isSaved ? .systemGreen : .white
        }
        
        // 更新值标签
        if let valueLabel = stack.arrangedSubviews.last as? UILabel {
            valueLabel.text = isSaved ? "已保存" : "未保存"
            valueLabel.textColor = isSaved ? .systemGreen : .white
        }
        
        // 添加动画效果
        UIView.animate(withDuration: 0.2) {
            self.layoutIfNeeded()
        }
    }
} 