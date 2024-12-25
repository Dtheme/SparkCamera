import UIKit
import SnapKit

class SCLensSelectorView: UIView {
    
    private var lensOptions: [SCLensModel] = []
    private var buttons: [UIButton] = []
    private let stackView = UIStackView()
    
    var onLensSelected: ((String) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        self.backgroundColor = UIColor(white: 1.0, alpha: 0.3)
        self.layer.cornerRadius = 20
        self.clipsToBounds = true
        
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        stackView.spacing = 10
        addSubview(stackView)
        
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(10)
        }
    }
    
    func updateLensOptions(_ options: [SCLensModel]) {
        buttons.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        
        for option in options {
            let button = UIButton(type: .system)
            button.setTitle(option.name, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = .clear
            button.layer.cornerRadius = 15
            button.addTarget(self, action: #selector(lensButtonTapped(_:)), for: .touchUpInside)
            buttons.append(button)
            stackView.addArrangedSubview(button)
        }
    }
    
    @objc private func lensButtonTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        
        // 触觉反馈
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.impactOccurred()
        
        // 高亮选中按钮
        buttons.forEach { $0.setTitleColor(.white, for: .normal) }
        sender.setTitleColor(.yellow, for: .normal)
        
        onLensSelected?(title)
    }
} 