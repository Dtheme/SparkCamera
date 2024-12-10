import UIKit
import AVFoundation
import SnapKit
import Then

class SCCameraPreviewV: UIView {
    
    // MARK: - Properties
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    var session: AVCaptureSession? {
        get { videoPreviewLayer.session }
        set { videoPreviewLayer.session = newValue }
    }
    
    // MARK: - UI Components
    private lazy var focusView = UIView().then {
        $0.layer.borderWidth = 1.0
        $0.layer.borderColor = UIColor.yellow.cgColor
        $0.isHidden = true
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupGestures()
    }
    
    // MARK: - Setup
    private func setupUI() {
        videoPreviewLayer.videoGravity = .resizeAspectFill
        
        addSubview(focusView)
        focusView.snp.makeConstraints { make in
            make.size.equalTo(CGSize(width: 80, height: 80))
            make.center.equalToSuperview()
        }
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinchGesture)
    }
    
    // MARK: - Gesture Handlers
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        showFocusViewAtPoint(point)
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        // 处理缩放手势
    }
    
    // MARK: - Helper Methods
    func showFocusViewAtPoint(_ point: CGPoint) {
        focusView.center = point
        focusView.isHidden = false
        focusView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        
        UIView.animate(withDuration: 0.3, animations: {
            self.focusView.transform = .identity
        }) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.focusView.isHidden = true
            }
        }
    }
    
    func convertToDevicePoint(_ point: CGPoint) -> CGPoint {
        return videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
    }
} 