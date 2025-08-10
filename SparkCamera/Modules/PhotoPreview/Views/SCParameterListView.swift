//
//  SCParameterListView.swift
//  SparkCamera
//
//  横向参数列表：类似工具栏交互，单一职责：展示参数并发出选择事件
//

import UIKit
import SnapKit

protocol SCParameterListViewDelegate: AnyObject {
    func parameterListView(_ view: SCParameterListView, didSelect parameter: SCFilterParameter)
    func parameterListView(_ view: SCParameterListView, didLongPress parameter: SCFilterParameter)
}

final class SCParameterListView: UIView, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    weak var delegate: SCParameterListViewDelegate?
    private var collectionView: UICollectionView!
    private let parameters: [SCFilterParameter]
    private var selectedIndexPath: IndexPath?
    private var modifiedParameters = Set<SCFilterParameter>()
    
    init(parameters: [SCFilterParameter] = SCFilterParameter.allCases) {
        self.parameters = parameters
        super.init(frame: .zero)
        setupUI()
    }
    
    /// 编程选中某个参数
    func select(parameter: SCFilterParameter, animated: Bool = false) {
        guard let idx = parameters.firstIndex(of: parameter) else { return }
        let indexPath = IndexPath(item: idx, section: 0)
        // 更新内部选中态并刷新
        selectedIndexPath = indexPath
        collectionView.reloadData()
        collectionView.selectItem(at: indexPath, animated: animated, scrollPosition: .centeredHorizontally)
        // 主动触发本类的 didSelect，保证外部代理也收到事件
        print("[ParameterList] programmatic select -> index: \(idx), param: \(parameter.displayName)")
        self.collectionView(collectionView, didSelectItemAt: indexPath)
    }

    /// 批量标记哪些参数已修改
    func setModifiedParameters(_ set: Set<SCFilterParameter>) {
        modifiedParameters = set
        collectionView.reloadData()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.isUserInteractionEnabled = true
        collectionView.canCancelContentTouches = true
        collectionView.delaysContentTouches = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(Cell.self, forCellWithReuseIdentifier: "cell")
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in make.edges.equalToSuperview() }

        // 长按手势：恢复默认值
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPress)

        // 额外Tap手势保障：直接定位点击的indexPath并触发选择
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        collectionView.addGestureRecognizer(tap)
    }

    // 暴露内部手势，便于外部设置 require(toFail:)
    public func gesturesForConflictResolution() -> [UIGestureRecognizer] {
        return collectionView.gestureRecognizers ?? []
    }
    
    // MARK: - DataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { parameters.count }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! Cell
        let param = parameters[indexPath.item]
        let isSelected = (indexPath == selectedIndexPath)
        cell.configure(text: param.displayName, modified: modifiedParameters.contains(param), selected: isSelected)
        return cell
    }
    
    // MARK: - Delegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // 强制结束滚动状态，避免手势竞争导致 didSelect 被吞掉
        print("[ParameterList] didSelect start -> index: \(indexPath.item), param: \(parameters[indexPath.item].displayName), contentOffset: \(collectionView.contentOffset)")
        collectionView.setContentOffset(collectionView.contentOffset, animated: false)
        // 立即禁用自身的手势，防止重复触发
        collectionView.gestureRecognizers?.forEach { $0.isEnabled = false; $0.isEnabled = true }
        // 触发回调
        selectedIndexPath = indexPath
        collectionView.reloadData()
        print("[ParameterList] didSelect reload done. isUserInteractionEnabled=\(collectionView.isUserInteractionEnabled)")
        delegate?.parameterListView(self, didSelect: parameters[indexPath.item])
    }
    
    // MARK: - FlowLayout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let text = parameters[indexPath.item].displayName as NSString
        let width = max(52, text.size(withAttributes: [.font: UIFont.systemFont(ofSize: 13, weight: .medium)]).width + 20)
        return CGSize(width: width, height: 36)
    }

    // MARK: - Actions
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let location = gesture.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: location) {
            let parameter = parameters[indexPath.item]
            print("[ParameterList] longPress -> index: \(indexPath.item), param: \(parameter.displayName)")
            delegate?.parameterListView(self, didLongPress: parameter)
        }
    }

    // 调试命中路径
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let v = super.hitTest(point, with: event)
        #if DEBUG
        print("[ParameterList] hitTest point=\(point) -> \(String(describing: v))")
        #endif
        return v
    }
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let inside = super.point(inside: point, with: event)
        #if DEBUG
        print("[ParameterList] pointInside point=\(point) inside=\(inside)")
        #endif
        return inside
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: location) else { return }
        print("[ParameterList] tap recognizer -> index: \(indexPath.item), param: \(parameters[indexPath.item].displayName)")
        // 统一走 didSelect 逻辑
        collectionView(self.collectionView, didSelectItemAt: indexPath)
    }
    
    // MARK: - Cell
    private final class Cell: UICollectionViewCell {
        private let label: UILabel = {
            let l = UILabel()
            l.textColor = .white
            l.font = .systemFont(ofSize: 13, weight: .medium)
            l.textAlignment = .center
            return l
        }()
        private let tapOverlay = UIView()
        private let dotView: UIView = {
            let v = UIView()
            v.backgroundColor = SCConstants.themeColor
            v.layer.cornerRadius = 3
            v.isHidden = true
            return v
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            contentView.backgroundColor = UIColor.white.withAlphaComponent(0.15)
            contentView.layer.cornerRadius = 8
            contentView.clipsToBounds = true
            contentView.addSubview(label)
            label.snp.makeConstraints { make in make.edges.equalToSuperview().inset(8) }
            contentView.addSubview(dotView)
            dotView.snp.makeConstraints { make in
                make.width.height.equalTo(6)
                make.top.equalToSuperview().offset(4)
                make.right.equalToSuperview().offset(-4)
            }
            // 提高命中精度：覆盖透明区域
            contentView.addSubview(tapOverlay)
            tapOverlay.backgroundColor = .clear
            tapOverlay.isUserInteractionEnabled = false // 不拦截点击，交由 collectionView 处理选中
            tapOverlay.snp.makeConstraints { make in make.edges.equalToSuperview() }
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        
        func configure(text: String, modified: Bool, selected: Bool) {
            label.text = text
            dotView.isHidden = !modified
            contentView.backgroundColor = selected ? SCConstants.themeColor.withAlphaComponent(0.9) : UIColor.white.withAlphaComponent(0.15)
        }
        
        // 选中样式由外层传入，避免系统复用导致不同步
    }
}


