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
    private let collectionView: UICollectionView
    private let templates: [SCFilterTemplate]
    weak var delegate: SCFilterOptionViewDelegate?
    
    // MARK: - Constants
    private enum Constants {
        static let itemSize = CGSize(width: 60, height: 80)
        static let minimumLineSpacing: CGFloat = 10
        static let minimumInteritemSpacing: CGFloat = 10
        static let sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    }
    
    // MARK: - Initialization
    init(templates: [SCFilterTemplate]) {
        self.templates = templates
        
        // 创建布局
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = Constants.itemSize
        layout.minimumLineSpacing = Constants.minimumLineSpacing
        layout.minimumInteritemSpacing = Constants.minimumInteritemSpacing
        layout.sectionInset = Constants.sectionInset
        
        // 初始化集合视图
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.init(frame: .zero)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // 设置背景
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        // 配置集合视图
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(SCFilterOptionCell.self, forCellWithReuseIdentifier: "FilterCell")
        
        // 添加集合视图
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
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
        let template = templates[indexPath.item]
        delegate?.filterOptionView(self, didSelectTemplate: template)
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
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 12)
        label.textAlignment = .center
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
    
    // MARK: - UI Setup
    private func setupUI() {
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
    
    override var isSelected: Bool {
        didSet {
            contentView.alpha = isSelected ? 0.6 : 1.0
        }
    }
}
