import UIKit
import SnapKit
import Then

class SCNavigationController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        navigationBar.isTranslucent = false
        navigationBar.barTintColor = .black
        navigationBar.tintColor = .white
        navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
} 