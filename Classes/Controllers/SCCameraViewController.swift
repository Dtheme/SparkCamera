import UIKit
import RxSwift
import RxCocoa
import SnapKit
import Then
import AVFoundation

@available(iOS 15.0, *)
class SCCameraViewController: UIViewController {
    
    private let disposeBag = DisposeBag()
    private var cameraManager: SCCameraManager!
    
    // MARK: - UI Components
    private lazy var previewView = SCCameraPreviewV().then {
        $0.backgroundColor = .black
    }
    
    private lazy var captureButton = UIButton().then {
        $0.backgroundColor = .white
        $0.layer.cornerRadius = 30
        $0.layer.borderWidth = 4
        $0.layer.borderColor = UIColor.white.cgColor
    }
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        checkCameraPermission()
        setupUI()
        setupBindings()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraManager.startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraManager.stopSession()
    }
    
    // MARK: - Setup
    private func setupCamera() {
        let config = SCCameraConfiguration()
        cameraManager = SCCameraManager(configuration: config)
        previewView.session = cameraManager.session
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        view.addSubview(previewView)
        view.addSubview(captureButton)
        
        previewView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        captureButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-30)
            make.size.equalTo(CGSize(width: 60, height: 60))
        }
    }
    
    private func setupBindings() {
        // 拍照按钮点击
        captureButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.cameraManager.capturePhoto()
            })
            .disposed(by: disposeBag)
        
        // 照片捕获回调
        cameraManager.capturePhotoSubject
            .subscribe(onNext: { [weak self] imageData in
                // 处理拍摄的照片
                self?.handleCapturedPhoto(imageData)
            })
            .disposed(by: disposeBag)
        
        // 错误处理
        cameraManager.errorSubject
            .subscribe(onNext: { [weak self] error in
                self?.handleError(error)
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Status Bar
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: - Helper Methods
    private func handleCapturedPhoto(_ imageData: Data) {
        // 处理拍摄的照片
        guard let image = UIImage(data: imageData) else {
            handleError(CameraError.captureFailed)
            return
        }
        
        // 保存到相册
        UIImageWriteToSavedPhotosAlbum(image, 
                                     self, 
                                     #selector(image(_:didFinishSavingWithError:contextInfo:)), 
                                     nil)
    }
    
    private func handleError(_ error: Error) {
        // 在主线程显示错误提示
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: "错误",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            self?.present(alert, animated: true)
        }
    }
    
    // MARK: - Image Saving Callback
    @objc private func image(_ image: UIImage, 
                            didFinishSavingWithError error: Error?, 
                            contextInfo: UnsafeRawPointer) {
        if let error = error {
            handleError(error)
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // 已授权，继续设置相机
            setupCamera()
        case .notDetermined:
            // 尚未决定，询问用户授权
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCamera()
                    }
                } else {
                    self.showPermissionAlert()
                }
            }
        case .denied, .restricted:
            // 用户拒绝或受限，显示提示
            showPermissionAlert()
        @unknown default:
            break
        }
    }
    
    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "相机权限被拒绝",
            message: "请在设置中启用相机权限以使用此功能。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
} 