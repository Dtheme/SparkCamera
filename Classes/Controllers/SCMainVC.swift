import UIKit
import SnapKit
import Then
import RxSwift
import RxCocoa

class SCMainVC: UIViewController {
    
    private let disposeBag = DisposeBag()
    
    // MARK: - UI Components
    private lazy var cameraButton = UIButton().then {
        $0.backgroundColor = .systemBlue
        $0.setTitle("打开相机", for: .normal)
        $0.setTitleColor(.white, for: .normal)
        $0.layer.cornerRadius = 8
    }
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .white
        title = "Spark Camera"
        
        view.addSubview(cameraButton)
        cameraButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(200)
            make.height.equalTo(44)
        }
    }
    
    private func setupBindings() {
        cameraButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.openCamera()
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Actions
    private func openCamera() {
        let cameraVC = SCCameraVC()
        cameraVC.modalPresentationStyle = .fullScreen
        present(cameraVC, animated: true)
    }
} 