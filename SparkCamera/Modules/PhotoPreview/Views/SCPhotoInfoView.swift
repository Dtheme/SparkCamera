//
//  SCPhotoInfoView.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/18.
//
//  图片预览界面的信息展示视图，显示图片的分辨率、比例、方向和文件大小等信息

import UIKit
import SnapKit

class SCPhotoInfoView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Properties
    private let photoInfo: SCPhotoInfo
    private let image: UIImage
    private var collectionView: UICollectionView!
    
    private struct InfoItem {
        var icon: String
        let title: String
        var value: String
        var valueColor: UIColor
    }
    private var items: [InfoItem] = []
    private var saveIndex: Int?
    private var formatIndex: Int?
    
    // MARK: - Initialization
    init(image: UIImage, photoInfo: SCPhotoInfo) {
        self.image = image
        self.photoInfo = photoInfo
        super.init(frame: .zero)
        setupUI()
        buildItems()
        
        // 添加通知监听
        NotificationCenter.default.addObserver(self, 
            selector: #selector(handlePhotoSaved(_:)),
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
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        layer.cornerRadius = 15
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 25
        layout.minimumInteritemSpacing = 0
        // 禁用自动尺寸，改为在 sizeForItemAt 中计算，避免无效布局导致崩溃
        layout.estimatedItemSize = .zero
        layout.itemSize = CGSize(width: 120, height: 44)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        // 上下留白由 contentInset 控制，左右居中改由 sectionInset 动态计算
        collectionView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        collectionView.register(InfoCell.self, forCellWithReuseIdentifier: "InfoCell")
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func buildItems() {
        items.removeAll()
        // 1. 分辨率
        items.append(InfoItem(icon: "photo",
            title: "分辨率",
                               value: String(format: "%.0f×%.0f", photoInfo.width, photoInfo.height),
                               valueColor: .white))
        // 2. 方向
        items.append(InfoItem(icon: "rotate.right",
            title: "方向",
                               value: photoInfo.isLandscape ? "横向" : "竖向",
                               valueColor: .white))
        // 3. 大小
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
        items.append(InfoItem(icon: "doc", title: "大小", value: fileSizeText, valueColor: .white))
        // 4. 原图保存状态
        saveIndex = items.count
        items.append(InfoItem(icon: photoInfo.isSavedToAlbum ? "checkmark.circle.fill" : "circle",
            title: "原图",
            value: photoInfo.isSavedToAlbum ? "已保存" : "未保存",
                               valueColor: photoInfo.isSavedToAlbum ? .systemGreen : .white))
        // 5. 格式
        formatIndex = items.count
        items.append(InfoItem(icon: "camera",
                               title: "格式",
                               value: photoInfo.captureFormat,
                               valueColor: .white))
        collectionView.reloadData()
    }
    
    // MARK: - Notification & Updates
    @objc private func handlePhotoSaved(_ note: Notification) {
        updateSaveState(isSaved: true)
        if let fmt = note.userInfo?["format"] as? String {
            photoInfo.captureFormat = fmt
            if let idx = formatIndex, idx < items.count {
                items[idx].value = fmt
                collectionView.reloadItems(at: [IndexPath(item: idx, section: 0)])
            }
        }
        if let id = note.userInfo?["assetLocalId"] as? String {
            print("[PhotoInfoView] Saved asset local id: \(id)")
        }
    }
    
    func updateSaveState(isSaved: Bool) {
        photoInfo.isSavedToAlbum = isSaved
        if let idx = saveIndex, idx < items.count {
            items[idx].icon = isSaved ? "checkmark.circle.fill" : "circle"
            items[idx].value = isSaved ? "已保存" : "未保存"
            items[idx].valueColor = isSaved ? .systemGreen : .white
            collectionView.reloadItems(at: [IndexPath(item: idx, section: 0)])
        } else {
            collectionView.reloadData()
        }
    }
    
    // MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "InfoCell", for: indexPath) as! InfoCell
        let item = items[indexPath.item]
        cell.configure(icon: item.icon, title: item.title, value: item.value, valueColor: item.valueColor)
        return cell
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let item = items[indexPath.item]
        let titleFont = UIFont.systemFont(ofSize: 11)
        let valueFont = UIFont.systemFont(ofSize: 11, weight: .medium)
        let titleWidth = (item.title as NSString).size(withAttributes: [.font: titleFont]).width
        let valueWidth = (item.value as NSString).size(withAttributes: [.font: valueFont]).width
        // 预估图标宽度与间距
        let iconWidth: CGFloat = 14
        let spacing: CGFloat = 2
        let horizontalPadding: CGFloat = 8
        let contentWidth = max(iconWidth + spacing + titleWidth, valueWidth)
        let width = ceil(contentWidth + horizontalPadding)
        return CGSize(width: max(64, width), height: 44)
    }

    // 当总内容不满一行宽度时，使其居中显示
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let baseSidePadding: CGFloat = 25
        let available = collectionView.bounds.width
        let total = totalItemsWidth(spacing: (collectionViewLayout as? UICollectionViewFlowLayout)?.minimumLineSpacing ?? 25)
        if total + baseSidePadding * 2 < available {
            let extra = (available - total) / 2.0
            return UIEdgeInsets(top: 0, left: extra, bottom: 0, right: extra)
        } else {
            return UIEdgeInsets(top: 0, left: baseSidePadding, bottom: 0, right: baseSidePadding)
        }
    }

    private func totalItemsWidth(spacing: CGFloat) -> CGFloat {
        var width: CGFloat = 0
        for i in 0..<items.count {
            let size = self.collectionView(self.collectionView, layout: self.collectionView.collectionViewLayout, sizeForItemAt: IndexPath(item: i, section: 0))
            width += size.width
            if i < items.count - 1 { width += spacing }
        }
        // 加上上下 padding 已由 contentInset 处理，这里只计算水平内容宽度
        return width
    }
    
    // MARK: - Cell
    private final class InfoCell: UICollectionViewCell {
        private let stack = UIStackView()
        private let titleRow = UIStackView()
        private let iconView = UIImageView()
        private let titleLabel = UILabel()
        private let valueLabel = UILabel()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            contentView.backgroundColor = .clear
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = 2
            contentView.addSubview(stack)
            stack.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            titleRow.axis = .horizontal
            titleRow.alignment = .center
            titleRow.spacing = 2
            stack.addArrangedSubview(titleRow)
            
            let config = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
            iconView.preferredSymbolConfiguration = config
            iconView.contentMode = .scaleAspectFit
            titleRow.addArrangedSubview(iconView)
            
            titleLabel.font = .systemFont(ofSize: 11)
            titleLabel.textColor = .white
            titleRow.addArrangedSubview(titleLabel)
            
            valueLabel.font = .systemFont(ofSize: 11, weight: .medium)
            valueLabel.textAlignment = .center
            stack.addArrangedSubview(valueLabel)
        }
        
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        
        func configure(icon: String, title: String, value: String, valueColor: UIColor) {
            iconView.image = UIImage(systemName: icon)
            iconView.tintColor = valueColor
            titleLabel.text = title
            valueLabel.text = value
            valueLabel.textColor = valueColor
        }
    }
} 