//
//  SCFilterOptionView.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/18.
//
//  滤镜选择器


import UIKit
import SnapKit

protocol SCFilterOptionViewDelegate: AnyObject {
    func filterOptionView(_ view: SCFilterOptionView, didSelectTemplate template: SCFilterTemplate)
}

class SCFilterOptionView: UIView {
    
    // MARK: - Properties
    weak var delegate: SCFilterOptionViewDelegate?
    var templates: [SCFilterTemplate] = SCFilterTemplate.templates {
        didSet {
            collectionView.reloadData()
        }
    }

    /// 追加更多模板（例如自定义模板）
    func appendTemplates(_ extra: [SCFilterTemplate]) {
        templates += extra
    }
    
    private var collectionView: UICollectionView!
    
    // MARK: - Constants
    private enum Constants {
        static let itemSize = CGSize(width: 60, height: 80)
        static let minimumLineSpacing: CGFloat = 10
        static let minimumInteritemSpacing: CGFloat = 10
        static let sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    }
    
    // MARK: - Initialization
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // 设置背景
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        isUserInteractionEnabled = true
        
        // 配置布局
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = Constants.itemSize
        layout.minimumLineSpacing = Constants.minimumLineSpacing
        layout.minimumInteritemSpacing = Constants.minimumInteritemSpacing
        layout.sectionInset = Constants.sectionInset
        
        // 配置集合视图
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(SCFilterOptionCell.self, forCellWithReuseIdentifier: "FilterCell")
        collectionView.isUserInteractionEnabled = true
        collectionView.allowsSelection = true
        collectionView.delaysContentTouches = false
        
        // 添加集合视图
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        print("[FilterOptionView] 设置 collectionView delegate: \(String(describing: collectionView.delegate))")
        
        // 添加调试手势
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        print("[FilterOptionView] Tap received at: \(location)")
        
        if let indexPath = collectionView.indexPathForItem(at: collectionView.convert(location, from: self)) {
            print("[FilterOptionView] Tapped cell at indexPath: \(indexPath)")
            collectionView(collectionView, didSelectItemAt: indexPath)
        }
    }
    
    // 添加触摸事件调试
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        print("[FilterOptionView] hitTest - point: \(point), resulting view: \(String(describing: type(of: view)))")
        return view
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let result = super.point(inside: point, with: event)
        print("[FilterOptionView] point(inside:) - point: \(point), result: \(result)")
        return result
    }
}

// MARK: - UICollectionViewDataSource
extension SCFilterOptionView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return templates.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FilterCell", for: indexPath) as! SCFilterOptionCell
        let template = templates[indexPath.item]
        cell.configure(with: template)
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension SCFilterOptionView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("[FilterOptionView] 选择了滤镜: indexPath=\(indexPath.item)")
        let template = templates[indexPath.item]
        print("[FilterOptionView] 滤镜模板: \(template.name), delegate=\(String(describing: delegate))")
        
        // 添加触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        delegate?.filterOptionView(self, didSelectTemplate: template)
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        print("[FilterOptionView] shouldSelectItemAt: \(indexPath.item)")
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        print("[FilterOptionView] shouldHighlightItemAt: \(indexPath.item)")
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        print("[FilterOptionView] didHighlightItemAt: \(indexPath.item)")
    }
}

// MARK: - UIGestureRecognizerDelegate
extension SCFilterOptionView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        print("[FilterOptionView] gestureRecognizer shouldReceive touch at: \(touch.location(in: self))")
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: - Filter Option Cell
class SCFilterOptionCell: UICollectionViewCell {
    
    // MARK: - Properties
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.backgroundColor = .darkGray
        view.isUserInteractionEnabled = false  // 图片视图不需要接收事件
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 12)
        label.textAlignment = .center
        label.isUserInteractionEnabled = false  // 标签不需要接收事件
        return label
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        
        // 确保 cell 可以接收点击
        isUserInteractionEnabled = true
        contentView.isUserInteractionEnabled = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .clear  // 设置背景色为透明
        contentView.backgroundColor = .clear  // 设置内容视图背景色为透明
        
        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        
        imageView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(60)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(4)
            make.left.right.equalToSuperview()
        }
    }
    
    // MARK: - Configuration
    func configure(with template: SCFilterTemplate) {
        imageView.image = template.thumbnail
        titleLabel.text = template.name
    }
    
    // MARK: - Touch Handling
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        print("[FilterCell] hitTest - point: \(point), resultView: \(String(describing: view))")
        return view
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let isInside = super.point(inside: point, with: event)
        print("[FilterCell] point(inside:) - point: \(point), isInside: \(isInside)")
        return isInside
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        print("[FilterCell] touchesBegan")
        contentView.alpha = 0.6
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        print("[FilterCell] touchesEnded")
        contentView.alpha = 1.0
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        print("[FilterCell] touchesCancelled")
        contentView.alpha = 1.0
    }
    
    override var isHighlighted: Bool {
        didSet {
            print("[FilterCell] isHighlighted: \(isHighlighted)")
            contentView.alpha = isHighlighted ? 0.6 : 1.0
        }
    }
    
    override var isSelected: Bool {
        didSet {
            print("[FilterCell] isSelected: \(isSelected)")
            contentView.alpha = isSelected ? 0.6 : 1.0
        }
    }
}
