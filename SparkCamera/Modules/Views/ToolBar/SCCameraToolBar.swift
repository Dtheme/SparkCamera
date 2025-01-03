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
            print("⚠️ [ToolBar] 动画状态检查失败")
            print("- isCollapsed: \(isCollapsed)")
            print("- isAnimating: \(isAnimating)")
            print("- activeItem: \(String(describing: activeItem?.type))")
            return
        }
        
        print("\n📍 [ToolBar] 开始收起动画")
        print("当前状态:")
        print("- 工具栏frame: \(frame)")
        print("- 选中工具: \(item.type)")
        print("- 工具状态: \(item.state)")
        print("- 总工具数: \(items.count)")
        
        isAnimating = true
        isCollapsed = true
        activeItem = item
        
        // 保存原始状态
        originalFrame = frame
        
        // 获取选中的cell和索引
        guard let selectedCell = collectionView.visibleCells.first(where: { ($0 as? SCCameraToolCell)?.item?.type == item.type }),
              let selectedIndexPath = collectionView.indexPath(for: selectedCell) else {
            print("❌ [ToolBar] 未找到选中的cell")
            print("- 查找类型: \(item.type)")
            print("- 可见cell数: \(collectionView.visibleCells.count)")
            isAnimating = false
            return
        }
        
        print("\n🔍 [ToolBar] 找到选中cell")
        print("- 索引: \(selectedIndexPath.item)")
        print("- 位置: \(selectedCell.frame)")
        print("- 是否可见: \(selectedCell.isHidden ? "否" : "是")")
        print("- alpha: \(selectedCell.alpha)")
        
        // 保存所有cell的原始位置
        print("\n📝 [ToolBar] 保存cell位置")
        collectionView.visibleCells.forEach { cell in
            if let indexPath = collectionView.indexPath(for: cell) {
                originalCellFrames[indexPath] = cell.frame
                if let toolCell = cell as? SCCameraToolCell {
                    print("- cell[\(indexPath.item)]:")
                    print("  类型: \(String(describing: toolCell.item?.type))")
                    print("  位置: \(cell.frame)")
                    print("  状态: \(String(describing: toolCell.item?.state))")
                }
            }
        }
        
        // 获取布局参数
        let layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        let cellWidth: CGFloat = 70
        let cellHeight: CGFloat = 80
        let sectionInset = layout.sectionInset
        
        // 计算最终的x偏移
        let finalX = -(frame.width - (cellWidth + sectionInset.right + sectionInset.left))
        
        // 计算选中cell的最终位置
        let rightEdgeX = collectionView.bounds.width - cellWidth - sectionInset.right
        let selectedCellTargetFrame = CGRect(x: rightEdgeX,
                                           y: 0,
                                           width: cellWidth,
                                           height: cellHeight)
        
        print("\n📐 [ToolBar] 计算参数")
        print("- 工具栏宽度: \(frame.width)")
        print("- cell尺寸: \(cellWidth) x \(cellHeight)")
        print("- 边距: 左\(sectionInset.left) 右\(sectionInset.right)")
        print("- 最终偏移: \(finalX)")
        print("- 目标位置: \(selectedCellTargetFrame)")
        
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
                    print("✅ 重置选中cell[\(selectedIndexPath.item)]尺寸: \(cell.frame)")
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
                
                print("📍 选中cell动画中位置: \(selectedCell.frame)")
                
            }) { _ in
                // 最后确认选中cell的位置
                selectedCell.frame = selectedCellTargetFrame
                
                print("\n✅ [ToolBar] 动画完成")
                print("- 工具栏最终frame: \(self.frame)")
                print("- 选中cell最终frame: \(selectedCell.frame)")
                
                // 显示选项视图
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("\n🎯 [ToolBar] 显示选项视图")
                    print("- 工具类型: \(item.type)")
                    print("- 工具状态: \(item.state)")
                    self.showOptionsView(for: item, from: selectedCell)
                }
                
                self.isAnimating = false
                print("\n🏁 [ToolBar] 收起动画流程结束")
                print("- isCollapsed: \(self.isCollapsed)")
                print("- isAnimating: \(self.isAnimating)")
                print("- activeItem: \(String(describing: self.activeItem?.type))\n")
            }
        }
    }
    
    func expandToolBar() {
        guard isCollapsed, !isAnimating else {
            print("⚠️ [ToolBar] 展开动画状态检查失败")
            print("- isCollapsed: \(isCollapsed)")
            print("- isAnimating: \(isAnimating)")
            print("- activeItem: \(String(describing: activeItem?.type))")
            return
        }
        
        print("\n📍 [ToolBar] 开始展开动画")
        print("当前状态:")
        print("- 工具栏frame: \(frame)")
        print("- 活动工具: \(String(describing: activeItem?.type))")
        
        isAnimating = true
        
        if let activeItem = activeItem {
            print("\n🔔 [ToolBar] 通知代理")
            print("- 工具类型: \(activeItem.type)")
            print("- 工具状态: \(activeItem.state)")
            delegate?.toolBar(self, willAnimate: activeItem)
            delegate?.toolBar(self, didCollapse: activeItem)
        }
        
        print("\n🎬 [ToolBar] 隐藏选项视图")
        optionsView?.hide { [weak self] in
            self?.optionsView?.removeFromSuperview()
            self?.optionsView = nil
        }
        
        print("\n📐 [ToolBar] 恢复约束")
        print("- 原始center: \(originalCenter)")
        print("- 原始frame: \(originalFrame)")
        
        self.snp.remakeConstraints { make in
            make.center.equalTo(originalCenter)
            make.width.equalTo(originalFrame.width)
            make.height.equalTo(originalFrame.height)
        }
        
        print("\n🎬 [ToolBar] 开始展开动画")
        UIView.animate(withDuration: 0.3, animations: {
            self.superview?.layoutIfNeeded()
            self.blurView.layer.cornerRadius = 12
            
            print("\n📍 [ToolBar] 恢复所有cell")
            self.collectionView.visibleCells.forEach { cell in
                if let indexPath = self.collectionView.indexPath(for: cell),
                   let toolCell = cell as? SCCameraToolCell {
                    print("- cell[\(indexPath.item)]:")
                    print("  类型: \(String(describing: toolCell.item?.type))")
                    print("  原始位置: \(self.originalCellFrames[indexPath] ?? cell.frame)")
                    
                    cell.isHidden = false
                    cell.alpha = 1
                    
                    // 使用保存的原始位置，如果没有则使用布局计算的位置
                    if let originalFrame = self.originalCellFrames[indexPath] {
                        cell.frame = originalFrame
                    }
                }
            }
        }) { _ in
            self.isCollapsed = false
            self.isAnimating = false
            
            if let activeItem = self.activeItem {
                print("\n🔔 [ToolBar] 通知代理动画完成")
                print("- 工具类型: \(activeItem.type)")
                print("- 工具状态: \(activeItem.state)")
                self.delegate?.toolBar(self, didFinishAnimate: activeItem)
            }
            self.activeItem = nil
            
            print("\n🏁 [ToolBar] 展开动画流程结束")
            print("- isCollapsed: \(self.isCollapsed)")
            print("- isAnimating: \(self.isAnimating)")
            print("- activeItem: \(String(describing: self.activeItem?.type))\n")
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
    private func updateItem(_ item: SCToolItem) {
        if let index = items.firstIndex(where: { $0.type == item.type }) {
            items[index] = item
            if let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? SCCameraToolCell {
                cell.item = item
            }
        }
    }
    
    // 添加设置工具项的方法
    func setItems(_ items: [SCToolItem]) {
        self.items = items
        collectionView.reloadData()
    }
}

// MARK: - UICollectionViewDataSource & Delegate
extension SCCameraToolBar: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SCCameraToolCell.reuseIdentifier, for: indexPath) as! SCCameraToolCell
        cell.item = items[indexPath.item]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.item]
        
        if let cell = collectionView.cellForItem(at: indexPath) as? SCCameraToolCell {
            cell.animateSelection()
        }
        
        if isCollapsed {
            expandToolBar()
            return
        }
        
        collapseToolBar(except: item)
        delegate?.toolBar(self, didSelect: item)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension SCCameraToolBar: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 70, height: 80)
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

