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
    private var items: [SCCameraToolItem] = []
    private var expandedItem: SCCameraToolItem?
    private var isAnimating = false
    
    private var optionsView: SCCameraToolOptionsView?
    
    private var isCollapsed = false
    private var activeItem: SCCameraToolItem?
    
    private var originalFrame: CGRect = .zero
    private var originalCenter: CGPoint = .zero  // 添加记录原始中心点
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
        setupDefaultItems()
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
        
        // 添加宽度约束
        self.snp.makeConstraints { make in
            make.width.equalTo(UIScreen.main.bounds.width - 40)
        }
    }
    
    private func setupDefaultItems() {
        items = [
            SCCameraToolItem(type: .flash),
            SCCameraToolItem(type: .livePhoto),
            SCCameraToolItem(type: .ratio, options: ["4:3", "1:1", "16:9"]),
            SCCameraToolItem(type: .whiteBalance),
            SCCameraToolItem(type: .mute)
        ]
        collectionView.reloadData()
    }
    
    // MARK: - Public Methods
    func updateItem(_ item: SCCameraToolItem) {
        if let index = items.firstIndex(where: { $0.type == item.type }) {
            items[index] = item
            collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
        }
    }
    
    func expandItem(_ item: SCCameraToolItem) {
        guard !isAnimating, item.type.supportsExpansion else { return }
        
        isAnimating = true
        expandedItem = item
        delegate?.toolBar(self, willAnimate: item)
        
        // 创建并显示选项视图
        if let cell = collectionView.cellForItem(at: IndexPath(item: items.firstIndex(where: { $0.type == item.type }) ?? 0, section: 0)) {
            let optionsView = SCCameraToolOptionsView(type: item.type, options: item.options ?? [])
            optionsView.delegate = self
            addSubview(optionsView)
            
            // 设置选项视图的位置
            optionsView.snp.makeConstraints { make in
                make.centerX.equalTo(cell)
                make.bottom.equalTo(cell.snp.top).offset(-10)
                make.height.equalTo(50)
            }
            
            self.optionsView = optionsView
            optionsView.show(from: cell)
        }
        
        delegate?.toolBar(self, didExpand: item)
        delegate?.toolBar(self, didFinishAnimate: item)
        isAnimating = false
    }
    
    func collapseExpandedItem() {
        guard let item = expandedItem, !isAnimating else { return }
        
        isAnimating = true
        delegate?.toolBar(self, willAnimate: item)
        
        optionsView?.hide { [weak self] in
            self?.optionsView?.removeFromSuperview()
            self?.optionsView = nil
            self?.expandedItem = nil
            self?.isAnimating = false
            self?.delegate?.toolBar(self!, didCollapse: item)
            self?.delegate?.toolBar(self!, didFinishAnimate: item)
        }
    }
    
    func collapseToolBar(except item: SCCameraToolItem) {
        guard !isCollapsed, !isAnimating else { return }
        
        isAnimating = true
        isCollapsed = true
        activeItem = item
        
        // 保存原始状态
        originalFrame = frame
        
        // 获取选中的cell和索引
        guard let selectedCell = collectionView.visibleCells.first(where: { ($0 as? SCCameraToolCell)?.item?.type == item.type }),
              let selectedIndexPath = collectionView.indexPath(for: selectedCell) else {
            isAnimating = false
            return
        }
        
        // 保存所有cell的原始位置
        for section in 0..<collectionView.numberOfSections {
            for item in 0..<collectionView.numberOfItems(inSection: section) {
                let indexPath = IndexPath(item: item, section: section)
                if let cell = collectionView.cellForItem(at: indexPath) {
                    originalCellFrames[indexPath] = cell.frame
                    print("保存cell[\(indexPath.item)]的原始位置: \(cell.frame)")
                }
            }
        }
        
        // 计算目标位置
        let layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        let cellWidth = layout.itemSize.width
        let cellSpacing = layout.minimumInteritemSpacing
        let sectionInset = layout.sectionInset
        
        // 计算最终的x偏移：屏幕宽度 - (一个cell的宽度 + 右边距)
        let finalX = -(frame.width - (cellWidth + sectionInset.right + sectionInset.left))
        
        print("===== 动画开始 =====")
        print("原始frame: \(frame)")
        print("计算的finalX: \(finalX)")
        print("选中cell的原始frame: \(selectedCell.frame)")
        print("collectionView的bounds: \(collectionView.bounds)")
        print("cell宽度: \(cellWidth), 间距: \(cellSpacing), 右边距: \(sectionInset.right)")
        print("选中的工具类型: \(item.type)")
        print("选中的cell索引: \(selectedIndexPath.item)")
        
        // 第一步：隐藏其他工具按钮
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut], animations: {
            // 遍历所有cell
            for section in 0..<self.collectionView.numberOfSections {
                for item in 0..<self.collectionView.numberOfItems(inSection: section) {
                    let indexPath = IndexPath(item: item, section: section)
                    guard let cell = self.collectionView.cellForItem(at: indexPath) else { continue }
                    
                    if indexPath == selectedIndexPath {
                        cell.isHidden = false
                        cell.alpha = 1
                        print("保持选中cell[\(indexPath.item)]的alpha为1")
                    } else {
                        cell.isHidden = true
                        cell.alpha = 0
                        print("设置cell[\(indexPath.item)]的alpha为0")
                    }
                }
            }
        }) { _ in
            print("===== 第一步完成 =====")
            print("其他按钮已隐藏")
            print("选中cell[\(selectedIndexPath.item)]是否可见: \(selectedCell.isHidden)")
            print("选中cell[\(selectedIndexPath.item)]的alpha: \(selectedCell.alpha)")
            
            // 更新约束以实现位移动画
            self.snp.remakeConstraints { make in
                make.left.equalToSuperview().offset(finalX)
                make.centerY.equalTo(self.originalFrame.midY)
                make.width.equalTo(self.originalFrame.width)
                make.height.equalTo(self.originalFrame.height)
            }
            
            // 第二步：收缩工具栏并左移
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut, .allowUserInteraction], animations: {
                // 1. 强制布局更新以应用新的约束
                self.superview?.layoutIfNeeded()
                
                // 2. 更新模糊背景
                self.blurView.layer.cornerRadius = cellWidth / 2
                
                // 3. 调整选中的cell位置（移动到最右侧）
                let rightEdgeX = self.collectionView.bounds.width - cellWidth - sectionInset.right
                
                // 确保选中的cell状态正确
                selectedCell.isHidden = false
                selectedCell.alpha = 1
                selectedCell.frame = CGRect(x: rightEdgeX,
                                         y: selectedCell.frame.minY,
                                         width: cellWidth,
                                         height: selectedCell.frame.height)
                
                // 确保选中的cell在最上层
                selectedCell.superview?.bringSubviewToFront(selectedCell)
                
                print("设置选中cell[\(selectedIndexPath.item)]的新位置: x=\(rightEdgeX), width=\(cellWidth)")
                print("动画中 - 选中cell是否可见: \(selectedCell.isHidden)")
                print("动画中 - 选中cell的alpha: \(selectedCell.alpha)")
                
                // 强制刷新布局
                self.collectionView.layoutIfNeeded()
                
            }) { _ in
                print("===== 第二步完成 =====")
                print("工具栏已移动到位")
                
                // 最终确保所有cell状态正确
                for section in 0..<self.collectionView.numberOfSections {
                    for item in 0..<self.collectionView.numberOfItems(inSection: section) {
                        let indexPath = IndexPath(item: item, section: section)
                        guard let cell = self.collectionView.cellForItem(at: indexPath) else { continue }
                        
                        if indexPath == selectedIndexPath {
                            cell.isHidden = false
                            cell.alpha = 1
                            cell.superview?.bringSubviewToFront(cell)
                            print("保持选中cell[\(indexPath.item)]可见 - isHidden: \(cell.isHidden), alpha: \(cell.alpha)")
                        } else {
                            cell.isHidden = true
                            cell.alpha = 0
                            print("隐藏cell[\(indexPath.item)] - isHidden: \(cell.isHidden), alpha: \(cell.alpha)")
                        }
                    }
                }
                
                // 再次确认选中cell的状态
                selectedCell.isHidden = false
                selectedCell.alpha = 1
                selectedCell.superview?.bringSubviewToFront(selectedCell)
                
                print("最终检查 - 选中cell[\(selectedIndexPath.item)]是否可见: \(selectedCell.isHidden)")
                print("最终检查 - 选中cell[\(selectedIndexPath.item)]的alpha: \(selectedCell.alpha)")
                
                // 第三步：显示选项视图（延迟改为0.1秒）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("===== 第三步开始 =====")
                    print("准备显示选项视图")
                    print("显示选项前 - 选中cell[\(selectedIndexPath.item)]是否可见: \(selectedCell.isHidden)")
                    print("显示选项前 - 选中cell[\(selectedIndexPath.item)]的alpha: \(selectedCell.alpha)")
                    self.showOptionsView(for: item, from: selectedCell)
                }
                
                self.isAnimating = false
            }
        }
    }
    
    func expandToolBar() {
        guard isCollapsed, !isAnimating else { return }
        
        isAnimating = true
        
        // 隐藏选项视图
        optionsView?.hide { [weak self] in
            self?.optionsView?.removeFromSuperview()
            self?.optionsView = nil
        }
        
        // 获取当前选中的cell
        guard let selectedCell = collectionView.visibleCells.first(where: { !$0.isHidden }) else { return }
        
        // 恢复原始约束
        self.snp.remakeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalTo(originalFrame.midY)
            make.width.equalTo(originalFrame.width)
            make.height.equalTo(originalFrame.height)
        }
        
        // 第一步：展开工具栏（改为0.3秒）
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseOut, .allowUserInteraction], animations: {
            // 1. 强制布局更新以应用新的约束
            self.superview?.layoutIfNeeded()
            
            // 2. 恢复模糊背景
            self.blurView.layer.cornerRadius = 12
            
            // 3. 恢复选中cell的位置
            if let indexPath = self.collectionView.indexPath(for: selectedCell) {
                selectedCell.frame = self.originalCellFrames[indexPath] ?? selectedCell.frame
            }
            
        }) { _ in
            // 第二步：显示其他cell（改为0.2秒）
            self.collectionView.visibleCells.forEach { cell in
                if cell != selectedCell {
                    cell.isHidden = false
                    cell.alpha = 0
                    
                    if let indexPath = self.collectionView.indexPath(for: cell) {
                        cell.frame = self.originalCellFrames[indexPath] ?? cell.frame
                    }
                    
                    UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseOut], animations: {
                        cell.alpha = 1
                        cell.transform = .identity
                    }, completion: nil)
                }
            }
            
            self.isCollapsed = false
            self.isAnimating = false
            self.activeItem = nil
        }
    }
    
    private func showOptionsView(for item: SCCameraToolItem, from cell: UICollectionViewCell) {
        let optionsView = SCCameraToolOptionsView(type: item.type, options: self.getOptionsForType(item.type))
        optionsView.delegate = self
        self.superview?.addSubview(optionsView)
        
        // 设置选项视图的位置和大小
        optionsView.snp.makeConstraints { make in
            make.left.equalTo(self.snp.right)  // 紧贴工具栏右侧
            make.right.equalToSuperview().offset(-10)  // 距离屏幕右侧10点
            make.centerY.equalTo(self)  // 垂直居中对齐
            make.height.equalTo(self)  // 与工具栏等高
        }
        
        self.optionsView = optionsView
        optionsView.show(from: cell)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if originalFrame.isEmpty {
            originalFrame = frame
            originalCenter = center  // 保存原始中心点
            
            // 保存所有cell的初始frame
            collectionView.visibleCells.forEach { cell in
                if let indexPath = collectionView.indexPath(for: cell) {
                    originalCellFrames[indexPath] = cell.frame
                }
            }
        }
    }
    
    private func getOptionsForType(_ type: SCCameraToolType) -> [String] {
        switch type {
        case .flash:
            return ["自动", "打开", "闪光灯已关闭"]
        case .ratio:
            return ["4:3", "1:1", "16:9"]
        case .whiteBalance:
            return ["自动", "晴天", "阴天", "荧光灯", "白炽灯"]
        case .mute:
            return ["开启", "关闭"]
        default:
            return []
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
        cell.item = items[indexPath.item]
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension SCCameraToolBar: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.item]
        
        if let cell = collectionView.cellForItem(at: indexPath) as? SCCameraToolCell {
            cell.animateSelection()
        }
        
        // 如果工具栏已经收起，则展开
        if isCollapsed {
            expandToolBar()
            return
        }
        
        // 所有工具项都执行收起动画
        collapseToolBar(except: item)
        
        // 通知代理
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
    func optionsView(_ optionsView: SCCameraToolOptionsView, didSelect option: String, for type: SCCameraToolType) {
        // 第一步：更新选中的工具项
        guard let index = items.firstIndex(where: { $0.type == type }) else { return }
        
        // 暂存当前 item
        let currentItem = items[index]
        
        // TODO: 后续可以根据不同类型和选项设置不同的状态和样式
        // 目前仅更新标题，保留其他状态
        var updatedItem = currentItem
        updatedItem.title = option
        
        // 更新 items 数组
        items[index] = updatedItem
        
        // 第二步：更新 UI
        collectionView.performBatchUpdates({
            collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
        }) { [weak self] _ in
            guard let self = self else { return }
            
            // 第三步：隐藏选项视图
            optionsView.hide { [weak self] in
                guard let self = self else { return }
                
                // 第四步：展开工具栏
                self.expandToolBar()
                
                // 第五步：通知代理
                self.delegate?.toolBar(self, didSelect: updatedItem)
            }
        }
    }
} 

