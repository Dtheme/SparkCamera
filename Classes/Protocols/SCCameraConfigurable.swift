import AVFoundation

protocol SCCameraConfigurable {
    // 基础配置
    var position: AVCaptureDevice.Position { get set }
    var quality: AVCaptureSession.Preset { get set }
    var flashMode: AVCaptureDevice.FlashMode { get set }
    
    // 曝光配置
    var exposureMode: AVCaptureDevice.ExposureMode { get set }
    var exposureBias: Float { get set }
    var iso: Float { get set }
    
    // 对焦配置
    var focusMode: AVCaptureDevice.FocusMode { get set }
    var focusPoint: CGPoint? { get set }
    
    // 白平衡配置
    var whiteBalanceMode: AVCaptureDevice.WhiteBalanceMode { get set }
    
    // 视频配置
    var videoStabilizationMode: AVCaptureVideoStabilizationMode { get set }
    var videoZoomFactor: CGFloat { get set }
} 