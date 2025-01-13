import UIKit

class SCFocusBoxView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        self.layer.borderColor = SCConstants.themeColor.cgColor
        self.layer.borderWidth = 2
        self.layer.cornerRadius = 6
        self.alpha = 0
    }
    
    func animate(to point: CGPoint) {
        self.center = point
        self.bounds = CGRect(x: 0, y: 0, width: 80, height: 80)
        self.alpha = 1.0
        
        UIView.animate(withDuration: 0.5, animations: {
            self.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: 0.5, options: [], animations: {
                self.alpha = 0
                self.transform = .identity
            }, completion: nil)
        }
    }
} 
