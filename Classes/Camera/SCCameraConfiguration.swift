import AVFoundation
import RxSwift

class SCCameraConfiguration: SCCameraConfigurable {
    // MARK: - Properties
    private let disposeBag = DisposeBag()
    
    // 基础配置
    var position: AVCaptureDevice.Position = .back {
        didSet { configurationChanged.onNext(()) }
    }
    
    var quality: AVCaptureSession.Preset = .photo {
        didSet { configurationChanged.onNext(()) }
    }
    
    var flashMode: AVCaptureDevice.FlashMode = .auto {
        didSet { configurationChanged.onNext(()) }
    }
    
    // 曝光配置
    var exposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure {
        didSet { configurationChanged.onNext(()) }
    }
    
    var exposureBias: Float = 0.0 {
        didSet { configurationChanged.onNext(()) }
    }
    
    var iso: Float = SCConstants.Camera.Exposure.autoISOTarget {
        didSet { configurationChanged.onNext(()) }
    }
    
    // 对焦配置
    var focusMode: AVCaptureDevice.FocusMode = .continuousAutoFocus {
        didSet { configurationChanged.onNext(()) }
    }
    
    var focusPoint: CGPoint? {
        didSet { configurationChanged.onNext(()) }
    }
    
    // 白平衡配置
    var whiteBalanceMode: AVCaptureDevice.WhiteBalanceMode = .continuousAutoWhiteBalance {
        didSet { configurationChanged.onNext(()) }
    }
    
    // 视频配置
    var videoStabilizationMode: AVCaptureVideoStabilizationMode = .auto {
        didSet { configurationChanged.onNext(()) }
    }
    
    var videoZoomFactor: CGFloat = 1.0 {
        didSet { configurationChanged.onNext(()) }
    }
    
    // MARK: - Observables
    let configurationChanged = PublishSubject<Void>()
    
    // MARK: - Initialization
    init() {
        setupDefaultConfiguration()
    }
    
    // MARK: - Setup
    private func setupDefaultConfiguration() {
        // 设置默认配置
        position = .back
        quality = .photo
        flashMode = .auto
        exposureMode = .continuousAutoExposure
        focusMode = .continuousAutoFocus
        whiteBalanceMode = .continuousAutoWhiteBalance
    }
    
    // MARK: - Scene Presets
    func applyScenePreset(_ preset: SCConstants.Camera.SceneIntelligence.SceneType) {
        switch preset {
        case .auto:
            exposureMode = .continuousAutoExposure
            focusMode = .continuousAutoFocus
            whiteBalanceMode = .continuousAutoWhiteBalance
            
        case .portrait:
            exposureMode = .continuousAutoExposure
            focusMode = .continuousAutoFocus
            iso = SCConstants.Camera.Exposure.ScenePresets.portrait.iso
            
        case .night:
            exposureMode = .custom
            iso = SCConstants.Camera.Exposure.ScenePresets.night.iso
            exposureBias = SCConstants.Camera.Exposure.ScenePresets.night.ev
            
        default:
            setupDefaultConfiguration()
        }
        
        configurationChanged.onNext(())
    }
    
    // MARK: - Validation
    func validateConfiguration() -> Bool {
        // 验证配置是否有效
        guard iso >= SCConstants.Camera.Exposure.minISO,
              iso <= SCConstants.Camera.Exposure.maxISO,
              videoZoomFactor >= SCConstants.Camera.Video.minimumZoom,
              videoZoomFactor <= SCConstants.Camera.Video.maximumZoom else {
            return false
        }
        return true
    }
} 