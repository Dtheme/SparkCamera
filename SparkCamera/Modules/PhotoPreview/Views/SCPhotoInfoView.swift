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
    
    // MARK: - Initialization
    init(image: UIImage, photoInfo: SCPhotoInfo) {
        self.image = image
        self.photoInfo = photoInfo
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // 设置容器样式
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        layer.cornerRadius = 15
        
        // 创建主堆栈视图
        mainStack = UIStackView()
        mainStack.axis = .horizontal
        mainStack.spacing = 20
        mainStack.alignment = .center
        mainStack.distribution = .equalSpacing
        addSubview(mainStack)
        
        // 1. 分辨率信息
        let resolutionStack = createInfoStack(
            icon: "photo",
            title: "分辨率",
            value: String(format: "%.0f × %.0f", photoInfo.width, photoInfo.height)
        )
        
        // 2. 宽高比信息
        let ratio = photoInfo.aspectRatio
        let ratioText: String
        if abs(ratio - 1.0) < 0.01 {
            ratioText = "1:1"
        } else if abs(ratio - 4.0/3.0) < 0.01 {
            ratioText = "4:3"
        } else if abs(ratio - 16.0/9.0) < 0.01 {
            ratioText = "16:9"
        } else {
            ratioText = String(format: "%.2f:1", ratio)
        }
        let ratioStack = createInfoStack(
            icon: "aspectratio",
            title: "比例",
            value: ratioText
        )
        
        // 3. 方向信息
        let orientationStack = createInfoStack(
            icon: "rotate.right",
            title: "方向",
            value: photoInfo.isLandscape ? "横向" : "竖向"
        )
        
        // 4. 文件大小信息
        let imageData = image.jpegData(compressionQuality: 1.0)
        let fileSizeText: String
        if let size = imageData?.count {
            if size < 1024 * 1024 {
                fileSizeText = String(format: "%.1f KB", Double(size) / 1024.0)
            } else {
                fileSizeText = String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0))
            }
        } else {
            fileSizeText = "未知"
        }
        let sizeStack = createInfoStack(
            icon: "doc",
            title: "大小",
            value: fileSizeText
        )
        
        // 添加所有信息堆栈到主堆栈
        [resolutionStack, ratioStack, orientationStack, sizeStack].forEach {
            mainStack.addArrangedSubview($0)
        }
        
        // 设置约束
        mainStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20))
        }
    }
    
    private func createInfoStack(icon: String, title: String, value: String) -> UIStackView {
        // 创建垂直堆栈
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        
        // 创建标题行
        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.spacing = 4
        titleRow.alignment = .center
        
        // 创建图标
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        imageView.image = UIImage(systemName: icon, withConfiguration: config)
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        
        // 创建标题标签
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 12)
        
        // 添加图标和标题到标题行
        titleRow.addArrangedSubview(imageView)
        titleRow.addArrangedSubview(titleLabel)
        
        // 创建值标签
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.textColor = .white
        valueLabel.font = .systemFont(ofSize: 12, weight: .medium)
        valueLabel.textAlignment = .center
        
        // 添加到主堆栈
        stack.addArrangedSubview(titleRow)
        stack.addArrangedSubview(valueLabel)
        
        return stack
    }
} 