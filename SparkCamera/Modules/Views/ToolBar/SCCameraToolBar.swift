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
    private var originalContentOffset: CGPoint = .zero
    
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
            
            // 遍历所有items而不是visibleCells
            for (index, _) in items.enumerated() {
                let indexPath = IndexPath(item: index, section: 0)
                if let attributes = collectionView.layoutAttributesForItem(at: indexPath)?.copy() as? UICollectionViewLayoutAttributes {
                    originalCellFrames[indexPath] = attributes.frame
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
        originalCellFrames.removeAll()
        
        for (index, _) in items.enumerated() {
            let indexPath = IndexPath(item: index, section: 0)
            if let attributes = collectionView.layoutAttributesForItem(at: indexPath)?.copy() as? UICollectionViewLayoutAttributes {
                originalLayoutAttributes[indexPath] = attributes
                originalCellFrames[indexPath] = attributes.frame
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
        
        // 计算选中cell的最终位置，考虑 contentOffset
        let rightEdgeX = collectionView.bounds.width - cellWidth - sectionInset.right
        let selectedCellTargetFrame = CGRect(x: rightEdgeX + collectionView.contentOffset.x,
                                           y: 0,
                                           width: cellWidth,
                                           height: cellHeight)
        
        // 第一步：重置所有cell的尺寸并隐藏其他按钮
        UIView.animate(withDuration: 0.25, 
                      delay: 0, 
                      options: [.curveEaseInOut], 
                      animations: {
            // 保存当前滚动位置
            self.originalContentOffset = self.collectionView.contentOffset
            
            // 停止滚动
            self.collectionView.setContentOffset(self.collectionView.contentOffset, animated: false)
            self.collectionView.layoutIfNeeded()
            
            // 遍历所有items处理cell
            for (index, _) in self.items.enumerated() {
                let indexPath = IndexPath(item: index, section: 0)
                if let cell = self.collectionView.cellForItem(at: indexPath) {
                    if cell == selectedCell {
                        // 设置选中cell的初始位置，考虑 contentOffset
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
        guard isCollapsed else { return }
        isAnimating = true
        
        // 隐藏选项视图
        if let optionsView = optionsView {
            optionsView.hide()
            optionsView.removeFromSuperview()
            self.optionsView = nil
        }
        
        if let activeItem = activeItem {
            // 重置 item 的选中状态
            var updatedItem = activeItem
            updatedItem.isSelected = false
            updateItem(updatedItem)

        }
        
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
            
            // 恢复 collectionView 的滚动位置
            self.collectionView.setContentOffset(self.originalContentOffset, animated: false)
            
            // 恢复所有 cell 的位置
            for (indexPath, originalFrame) in self.originalCellFrames {
                // 获取 cell 或创建新的 cell 如果不可见
                let cell = self.collectionView.cellForItem(at: indexPath) ?? {
                    let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: SCCameraToolCell.reuseIdentifier, for: indexPath)
                    cell.frame = originalFrame
                    return cell
                }()
                
                cell.frame = originalFrame
                if let activeItem = self.activeItem, 
                   let index = self.items.firstIndex(where: { $0.type == activeItem.type }),
                   indexPath.item == index {
                    cell.isHidden = false
                    cell.alpha = 1
                } else {
                    cell.isHidden = true
                    cell.alpha = 0
                }
            }
        }) { _ in
            // 第二步：显示所有 cells
            let totalCells = self.originalCellFrames.count
            var completedCells = 0
            
            UIView.animate(withDuration: 0.25,
                         delay: 0,
                         options: [.curveEaseOut],
                         animations: {
            // 显示所有 cells
            for (indexPath, originalFrame) in self.originalCellFrames {
                // 获取 cell 或创建新的 cell 如果不可见
                let cell = self.collectionView.cellForItem(at: indexPath) ?? {
                    let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: SCCameraToolCell.reuseIdentifier, for: indexPath)
                    cell.frame = originalFrame
                    return cell
                }()
                
                cell.frame = originalFrame
                cell.isHidden = false
                UIView.animate(withDuration: 0.2,
                             delay: 0,
                             options: [.curveEaseOut],
                             animations: {
                        cell.alpha = 1
                    }, completion: { _ in
                        completedCells += 1
                        // 当所有 cell 动画都完成时
                        if completedCells == totalCells {
                            // 清理状态
                            self.originalLayoutAttributes.removeAll()
                            self.originalCellFrames.removeAll()
                            self.isCollapsed = false
                            self.isAnimating = false
                            
                            // 通知代理动画完成
                            if let activeItem = self.activeItem {
                                // 根据工具类型确定选项类型
                                let optionType: SCCameraToolOptionsViewType
                                switch activeItem.type {
                                case .exposure, .iso:
                                    // 对于支持滑块的工具，使用 scale 类型
                                    optionType = .scale
                                default:
                                    // 对于其他工具，使用 normal 类型
                                    optionType = .normal
                                }
                                
                                // 通知代理动画完成，让代理根据工具类型和状态进行相应处理
                                self.delegate?.toolBar(self, didFinishAnimate: activeItem, optionType: optionType)
                                
                                // 最后清除 activeItem
                                self.activeItem = nil
                            }
                        }
                    })
            }
            }) { _ in
                // 这里不需要做任何事情，因为我们在每个 cell 的动画完成后处理
            }
        }
    }
    
    private func showOptionsView(for item: SCToolItem, from cell: UICollectionViewCell) {
        // 隐藏已存在的选项视图
        if let existingOptionsView = optionsView {
            existingOptionsView.hide()
            existingOptionsView.removeFromSuperview()
            self.optionsView = nil
        }
        
        // 获取选项列表
        let options = item.options
        let selectedIndex = options.firstIndex(where: { option in
            if let optionState = option.state as? SCToolState,
               let itemState = item.state {
                return String(describing: optionState) == String(describing: itemState)
            }
            return false
        }) ?? 0
        let itemTitle = item.title
        
        // 创建并显示选项视图
        let optionsView = SCCameraToolOptionsView(toolType: item.type, 
                                                options: options, 
                                                selectedIndex: selectedIndex,
                                                itemTitle: itemTitle)
        optionsView.delegate = self
        superview?.addSubview(optionsView)
        
        optionsView.snp.makeConstraints { make in
            make.left.equalTo(self.snp.right).offset(10)
            make.right.equalToSuperview().offset(-10)
            make.centerY.equalTo(self)
            make.height.equalTo(120)
        }
        
        self.optionsView = optionsView
        optionsView.show()
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
            
            // 如果工具栏处于收起状态，且更新的是当前激活的 item
            if isCollapsed && item.type == activeItem?.type {
                let indexPath = IndexPath(item: index, section: 0)
                if let cell = collectionView.cellForItem(at: indexPath) {
                    // 更新 cell 但保持其可见性
                    if let toolCell = cell as? SCCameraToolCell {
                        toolCell.configure(with: item)
                    }
                    cell.isHidden = false
                    cell.alpha = 1
                }
            } else {
                // 正常更新 cell
                collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
            }
            
            // 更新 activeItem
            if item.type == activeItem?.type {
                activeItem = item
            }
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
            let optionType: SCCameraToolOptionsViewType = (item.type == .exposure || item.type == .iso) ? .scale : .normal
            delegate?.toolBar(self, didToggleState: item, optionType: optionType)
            return
        }
        
        // 如果工具支持展开，收起工具栏并通知代理
        if item.type.supportsExpansion {
            collapseToolBar(except: item)
            let optionType: SCCameraToolOptionsViewType = (item.type == .exposure || item.type == .iso) ? .scale : .normal
            delegate?.toolBar(self, didExpand: item, optionType: optionType)
        }
        
        // 通知代理工具被选中
        let optionType: SCCameraToolOptionsViewType = (item.type == .exposure || item.type == .iso) ? .scale : .normal
        delegate?.toolBar(self, didSelect: item, optionType: optionType)
    }
}

// MARK: - SCCameraToolOptionsViewDelegate
extension SCCameraToolBar: SCCameraToolOptionsViewDelegate {
    func optionsView(_ optionsView: SCCameraToolOptionsView, didChangeSliderValue value: Float, for type: SCToolType) {
        // 只在 Scale 类型时响应滑块值变化
        let optionType: SCCameraToolOptionsViewType = .scale
        
        if let item = getItem(for: type) {
            // 先设置 item 的值
            item.setValue(value, for: optionType)
            // 再通知代理
            delegate?.toolBar(self, didChangeSlider: value, for: item, optionType: optionType)
        }
    }
    
    func optionsView(_ optionsView: SCCameraToolOptionsView, didSelect option: SCToolOption, for type: SCToolType) {
        // 只在 Normal 类型时响应选项选择
        let optionType: SCCameraToolOptionsViewType = .normal
        
        if let item = getItem(for: type) {
            // 先更新 item 的状态
            item.setState(option.state)
            updateItem(item)
            
            // 然后调用代理方法
            delegate?.toolBar(self, didSelect: option.title, for: item, optionType: optionType)
            
            // 如果工具栏处于收起状态，展开工具栏
            if isCollapsed {
                expandToolBar()
            }
        }
    }
}

// 添加缺失的协议定义
protocol SCToolItemDelegate: AnyObject {
    func toolItem(_ item: SCToolItem, didChangeState state: Any)
    func toolItem(_ item: SCToolItem, didTapWithState state: Any)
}

extension SCCameraToolBar: SCToolItemDelegate {
    func toolItem(_ item: SCToolItem, didChangeState state: Any) {
        let optionType: SCCameraToolOptionsViewType = (item.type == .exposure || item.type == .iso) ? .scale : .normal
        delegate?.toolBar(self, didToggleState: item, optionType: optionType)
        updateItem(item)
    }
    
    func toolItem(_ item: SCToolItem, didTapWithState state: Any) {
        let optionType: SCCameraToolOptionsViewType = (item.type == .exposure || item.type == .iso) ? .scale : .normal
        
        if item.isSelected {
            // 如果已经选中，则收起选项视图
            delegate?.toolBar(self, didCollapse: item, optionType: optionType)
            item.isSelected = false
            updateItem(item)
        } else {
            // 如果未选中，则展开选项视图
            delegate?.toolBar(self, didExpand: item, optionType: optionType)
            item.isSelected = true
            updateItem(item)
            
            // 通知代理即将开始动画
            delegate?.toolBar(self, willAnimate: item, optionType: optionType)
            
            // 获取对应的 cell
            if let index = items.firstIndex(where: { $0.type == item.type }),
               let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) {
                // 展开选项视图
                showOptionsView(for: item, from: cell)
            }
        }
    }
}
