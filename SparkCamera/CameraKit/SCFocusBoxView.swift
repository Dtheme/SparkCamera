import UIKit

class SCFocusBoxView: UIView {
    
    // MARK: - Properties
    private let focusBox = UIView()
    private let animationDuration: TimeInterval = 0.3
    private let boxSize: CGFloat = 80
    private let borderWidth: CGFloat = 1
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    private func setupView() {
        focusBox.frame = CGRect(x: 0, y: 0, width: boxSize, height: boxSize)
        focusBox.layer.borderWidth = borderWidth
        focusBox.layer.borderColor = UIColor.white.cgColor
        focusBox.backgroundColor = .clear
        focusBox.isHidden = true
        addSubview(focusBox)
    }
    
    // MARK: - Public Methods
    func animate(for state: SCFocusState) {
        switch state {
        case .focusing:
            animateFocusing()
        case .focused:
            animateFocused()
        case .failed:
            animateFailed()
        case .locked:
            animateLocked()
        }
    }
    
    // MARK: - Private Methods
    private func animateFocusing() {
        focusBox.isHidden = false
        focusBox.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        focusBox.layer.borderColor = UIColor.yellow.cgColor
        
        UIView.animate(withDuration: self.animationDuration) {
            self.focusBox.transform = .identity
        }
    }
    
    private func animateFocused() {
        focusBox.layer.borderColor = UIColor.green.cgColor
        
        UIView.animate(withDuration: self.animationDuration, delay: 0.5) {
            self.focusBox.alpha = 0
        } completion: { _ in
            self.focusBox.isHidden = true
            self.focusBox.alpha = 1
        }
    }
    
    private func animateFailed() {
        focusBox.layer.borderColor = UIColor.red.cgColor
        
        UIView.animate(withDuration: self.animationDuration) {
            self.focusBox.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        } completion: { _ in
            UIView.animate(withDuration: self.animationDuration) {
                self.focusBox.transform = .identity
            }
        }
    }
    
    private func animateLocked() {
        focusBox.layer.borderColor = UIColor.white.cgColor
        focusBox.isHidden = false
        focusBox.alpha = 1
        
        UIView.animate(withDuration: self.animationDuration) {
            self.focusBox.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }
    }
    
    func reset() {
        focusBox.isHidden = true
        focusBox.transform = .identity
        focusBox.alpha = 1
        focusBox.layer.borderColor = UIColor.white.cgColor
    }
} 
