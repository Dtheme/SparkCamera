//
//  SCCameraToolBar.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import UIKit
import SnapKit
import SwiftMessages

class SCCameraToolBar: UIView {
    
    // MARK: - Properties
    weak var delegate: SCCameraToolBarDelegate?
    private var items: [SCToolItem] = []
    private var expandedItem: SCToolItem?
    private var isAnimating = false
    
    private var optionsView: SCCameraToolOptionsView?
    
    private var isCollapsed = false
    private var activeItem: SCToolItem?
    
    private var originalFrame: CGRect = .zero
    private var originalCenter: CGPoint = .zero
    private var originalCellFrames: [IndexPath: CGRect] = [:]
    private var originalLayoutAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    
    // MARK: - UI Components
    private lazy var blurView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .dark)
        let view = UIVisualEffectView(effect: blurEffect)
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.showsHorizontalScrollIndicator = false
        collection.delegate = self
        collection.dataSource = self
        collection.register(SCCameraToolCell.self, forCellWithReuseIdentifier: SCCameraToolCell.reuseIdentifier)
        return collection
    }()
    
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
        addSubview(blurView)
        addSubview(collectionView)
        
        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if originalFrame.isEmpty {
            originalFrame = frame
            originalCenter = center
            
            collectionView.visibleCells.forEach { cell in
                if let indexPath = collectionView.indexPath(for: cell) {
                    originalCellFrames[indexPath] = cell.frame
                }
            }
        }
    }
    
    // MARK: - Public Methods
    func collapseToolBar(except item: SCToolItem) {
        guard !isCollapsed, !isAnimating else {
            return
        }
        
        // 找到选中的cell
        guard let selectedIndex = items.firstIndex(where: { $0.type == item.type }),
              let selectedCell = collectionView.cellForItem(at: IndexPath(item: selectedIndex, section: 0)) else {
            return
        }
        
        isAnimating = true
        isCollapsed = true
        activeItem = item
        
        // 保存原始状态
        originalFrame = frame
        
        // 保存所有cell的布局属性
        originalLayoutAttributes.removeAll()
        collectionView.visibleCells.forEach { cell in
            if let indexPath = collectionView.indexPath(for: cell),
               let attributes = collectionView.layoutAttributesForItem(at: indexPath)?.copy() as? UICollectionViewLayoutAttributes {
                originalLayoutAttributes[indexPath] = attributes
                originalCellFrames[indexPath] = cell.frame
            }
        }
        
        // 获取布局参数
        let layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        let cellWidth: CGFloat = 70
        let cellHeight: CGFloat = 80
        let sectionInset = layout.sectionInset
        
        // 计算最终的x偏移
        let safeAreaInsets = superview?.safeAreaInsets ?? .zero
        let finalX = -(frame.width - (cellWidth + sectionInset.right + sectionInset.left)) + safeAreaInsets.left
        
        // 计算选中cell的最终位置
        let rightEdgeX = collectionView.bounds.width - cellWidth - sectionInset.right
        let selectedCellTargetFrame = CGRect(x: rightEdgeX,
                                           y: 0,
                                           width: cellWidth,
                                           height: cellHeight)
        
        // 第一步：重置所有cell的尺寸并隐藏其他按钮
        UIView.animate(withDuration: 0.25, 
                      delay: 0, 
                      options: [.curveEaseInOut], 
                      animations: {
            // 重置 collectionView 的滚动位置
            self.collectionView.contentOffset = .zero
            self.collectionView.layoutIfNeeded()
            
            // 统一所有cell的尺寸
            self.collectionView.visibleCells.forEach { cell in
                if cell == selectedCell {
                    cell.frame = CGRect(x: cell.frame.origin.x,
                                      y: 0,
                                      width: cellWidth,
                                      height: cellHeight)
                    cell.isHidden = false
                    cell.alpha = 1
                } else {
                    cell.isHidden = true
                    cell.alpha = 0
                }
            }
        }) { _ in
            // 第二步：移动工具栏
            self.snp.remakeConstraints { make in
                make.left.equalToSuperview().offset(finalX)
                make.centerY.equalTo(self.originalFrame.midY)
                make.width.equalTo(self.originalFrame.width)
                make.height.equalTo(cellHeight)
            }
            
            UIView.animate(withDuration: 0.3, 
                          delay: 0, 
                          options: [.curveEaseOut], 
                          animations: {
                self.superview?.layoutIfNeeded()
                self.blurView.layer.cornerRadius = cellWidth / 2
                
                // 设置选中cell的最终位置
                selectedCell.frame = selectedCellTargetFrame
                selectedCell.superview?.bringSubviewToFront(selectedCell)
                
            }) { _ in
                // 最后确认选中cell的位置
                selectedCell.frame = selectedCellTargetFrame
                
                // 显示选项视图
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.showOptionsView(for: item, from: selectedCell)
                }
                
                self.isAnimating = false
            }
        }
    }
    
    func expandToolBar() {
        guard isCollapsed, !isAnimating else {
            return
        }
        
        isAnimating = true
        
        if let activeItem = activeItem {
            delegate?.toolBar(self, willAnimate: activeItem)
            delegate?.toolBar(self, didCollapse: activeItem)
        }
        
        optionsView?.hide { [weak self] in
            guard let self = self else { return }
            self.optionsView?.removeFromSuperview()
            self.optionsView = nil
            
            // 恢复工具栏位置约束
            self.snp.remakeConstraints { make in
                make.center.equalTo(self.originalCenter)
                make.width.equalTo(self.originalFrame.width)
                make.height.equalTo(self.originalFrame.height)
            }
            
            // 重新加载 collectionView
            self.collectionView.reloadData()
            self.collectionView.layoutIfNeeded()
            
            // 第一步：恢复工具栏位置
            UIView.animate(withDuration: 0.3,
                          delay: 0,
                          options: [.curveEaseOut],
                          animations: {
                self.superview?.layoutIfNeeded()
                self.blurView.layer.cornerRadius = 12
                
                // 恢复所有 cell 的位置
                for (indexPath, originalFrame) in self.originalCellFrames {
                    if let cell = self.collectionView.cellForItem(at: indexPath) {
                        if let activeItem = self.activeItem, 
                           let index = self.items.firstIndex(where: { $0.type == activeItem.type }),
                           indexPath.item == index {
                            cell.frame = originalFrame
                            cell.isHidden = false
                            cell.alpha = 1
                        } else {
                            cell.frame = originalFrame
                            cell.isHidden = true
                            cell.alpha = 0
                        }
                    }
                }
            }) { _ in
                // 第二步：显示所有 cells
                UIView.animate(withDuration: 0.25,
                              delay: 0,
                              options: [.curveEaseOut],
                              animations: {
                    // 显示所有 cells
                    for (indexPath, originalFrame) in self.originalCellFrames {
                        if let cell = self.collectionView.cellForItem(at: indexPath) {
                            cell.frame = originalFrame
                            cell.isHidden = false
                            UIView.animate(withDuration: 0.2,
                                         delay: 0,
                                         options: [.curveEaseOut],
                                         animations: {
                                cell.alpha = 1
                            })
                        }
                    }
                }) { _ in
                    // 清理状态
                    self.originalLayoutAttributes.removeAll()
                    self.originalCellFrames.removeAll()
                    self.isCollapsed = false
                    self.isAnimating = false
                    self.activeItem = nil
                }
            }
        }
    }
    
    private func showOptionsView(for item: SCToolItem, from cell: UICollectionViewCell) {
        let optionsView = SCCameraToolOptionsView(type: item.type, options: item.type.defaultOptions)
        optionsView.delegate = self
        superview?.addSubview(optionsView)
        
        optionsView.snp.makeConstraints { make in
            make.left.equalTo(self.snp.right).offset(10)
            make.right.equalToSuperview().offset(-10)
            make.centerY.equalTo(self)
            make.height.equalTo(80)
        }
        
        self.optionsView = optionsView
        optionsView.show(from: cell)
    }
    
    // MARK: - Item Management
    public func getItem(for type: SCToolType) -> SCToolItem? {
        return items.first(where: { $0.type == type })
    }
    
    public func setItems(_ newItems: [SCToolItem]) {
        items = newItems
        collectionView.reloadData()
    }
    
    public func updateItem(_ item: SCToolItem) {
        if let index = items.firstIndex(where: { $0.type == item.type }) {
            items[index] = item
            collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
        }
    }
}

// MARK: - UICollectionViewDataSource
extension SCCameraToolBar: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SCCameraToolCell.reuseIdentifier, for: indexPath) as! SCCameraToolCell
        let item = items[indexPath.item]
        cell.configure(with: item)
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension SCCameraToolBar: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 50, height: 70)
    }
}

// MARK: - UICollectionViewDelegate
extension SCCameraToolBar: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.item]
        
        // 如果工具栏正在动画中，不处理点击
        guard !isAnimating else { return }
        
        // 如果工具栏已收起，且点击的不是当前激活的工具，不处理点击
        if isCollapsed && item.type != activeItem?.type {
            return
        }
        
        // 如果工具栏已收起，且点击的是当前激活的工具，展开工具栏
        if isCollapsed && item.type == activeItem?.type {
            expandToolBar()
            return
        }
        
        // 如果工具支持状态切换，直接切换状态
        if item.type.supportsStateToggle {
            item.toggleState()
            if let cell = collectionView.cellForItem(at: indexPath) as? SCCameraToolCell {
                cell.animateStateChange()
            }
            delegate?.toolBar(self, didToggleState: item)
            return
        }
        
        // 如果工具支持展开，收起工具栏
        if item.type.supportsExpansion {
            collapseToolBar(except: item)
        }
        
        // 通知代理工具被选中
        delegate?.toolBar(self, didSelect: item)
    }
}

// MARK: - SCCameraToolOptionsViewDelegate
extension SCCameraToolBar: SCCameraToolOptionsViewDelegate {
    func optionsView(_ optionsView: SCCameraToolOptionsView, didSelect option: SCToolOption, for type: SCToolType) {
        if let item = items.first(where: { $0.type == type }) {
            var updatedItem = item
            updatedItem.setState(option.state)
            updateItem(updatedItem)
            
            // 如果工具栏已收起，更新 activeItem
            if isCollapsed {
                activeItem = updatedItem
            }
            
            // 隐藏选项视图
            optionsView.hide { [weak self] in
                guard let self = self else { return }
                // 展开工具栏
                self.expandToolBar()
                // 通知代理选项已选择
                self.delegate?.toolBar(self, didSelect: option.title, for: updatedItem)
            }
        }
    }
} 

