import UIKit
import SnapKit

class SCCameraToolCell: UICollectionViewCell {
    
    static let reuseIdentifier = "SCCameraToolCell"
    
    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.layer.cornerRadius = 25
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 12)
        return label
    }()
    
    private lazy var selectedIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = .yellow
        view.layer.cornerRadius = 2
        view.isHidden = true
        return view
    }()
    
    // MARK: - Properties
    var item: SCCameraToolItem? {
        didSet {
            updateUI()
        }
    }
    
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
        contentView.addSubview(containerView)
        containerView.addSubview(iconView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(selectedIndicator)
        
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 50, height: 50))
        }
        
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 24, height: 24))
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(containerView.snp.bottom).offset(4)
            make.left.right.equalToSuperview()
        }
        
        selectedIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(containerView).offset(-4)
            make.width.equalTo(20)
            make.height.equalTo(4)
        }
    }
    
    private func updateUI() {
        guard let item = item else { return }
        
        iconView.image = item.icon
        titleLabel.text = item.title
        selectedIndicator.isHidden = !item.isSelected
        
        // 更新启用/禁用状态
        alpha = item.isEnabled ? 1.0 : 0.5
        isUserInteractionEnabled = item.isEnabled
    }
    
    // MARK: - Animation
    func animateSelection() {
        UIView.animate(withDuration: 0.2, animations: {
            self.containerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.containerView.transform = .identity
            }
        }
    }
} 