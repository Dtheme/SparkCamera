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
}

final class SCParameterListView: UIView, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    weak var delegate: SCParameterListViewDelegate?
    private var collectionView: UICollectionView!
    private let parameters: [SCFilterParameter]
    
    init(parameters: [SCFilterParameter] = SCFilterParameter.allCases) {
        self.parameters = parameters
        super.init(frame: .zero)
        setupUI()
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
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(Cell.self, forCellWithReuseIdentifier: "cell")
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in make.edges.equalToSuperview() }
    }
    
    // MARK: - DataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { parameters.count }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! Cell
        let param = parameters[indexPath.item]
        cell.configure(text: param.displayName)
        return cell
    }
    
    // MARK: - Delegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.parameterListView(self, didSelect: parameters[indexPath.item])
    }
    
    // MARK: - FlowLayout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let text = parameters[indexPath.item].displayName as NSString
        let width = max(52, text.size(withAttributes: [.font: UIFont.systemFont(ofSize: 13, weight: .medium)]).width + 20)
        return CGSize(width: width, height: 36)
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
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            contentView.backgroundColor = UIColor.white.withAlphaComponent(0.15)
            contentView.layer.cornerRadius = 8
            contentView.clipsToBounds = true
            contentView.addSubview(label)
            label.snp.makeConstraints { make in make.edges.equalToSuperview().inset(8) }
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        
        func configure(text: String) { label.text = text }
        
        override var isSelected: Bool {
            didSet {
                contentView.backgroundColor = isSelected ? SCConstants.themeColor.withAlphaComponent(0.9) : UIColor.white.withAlphaComponent(0.15)
            }
        }
    }
}


