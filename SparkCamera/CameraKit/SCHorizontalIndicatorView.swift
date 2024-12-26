import UIKit

class SCHorizontalIndicatorView: UIView {
    
    private let indicatorLine: UIView = {
        let line = UIView()
        line.backgroundColor = .systemGreen
        line.layer.cornerRadius = 2
        line.layer.shadowColor = UIColor.black.cgColor
        line.layer.shadowOpacity = 0.3
        line.layer.shadowOffset = CGSize(width: 0, height: 2)
        line.layer.shadowRadius = 4
        return line
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        self.addSubview(indicatorLine)
        indicatorLine.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            indicatorLine.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            indicatorLine.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            indicatorLine.widthAnchor.constraint(equalTo: self.widthAnchor, multiplier: 0.8),
            indicatorLine.heightAnchor.constraint(equalToConstant: 4)
        ])
    }
    
    func updateRotation(angle: CGFloat) {
        self.transform = CGAffineTransform(rotationAngle: angle)
    }
} 