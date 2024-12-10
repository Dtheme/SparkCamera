import UIKit
import AVFoundation

/// 相机配置模型
@available(iOS 15.0, *)
class SCCameraMd {
    
    // MARK: - 基础参数枚举
    enum SCPosition {
        case front, back
        var avPosition: AVCaptureDevice.Position {
            switch self {
            case .front: return .front
            case .back: return .back
            }
        }
    }
    
    enum SCFlashMode {
        case auto, on, off
        var avFlashMode: AVCaptureDevice.FlashMode {
            switch self {
            case .auto: return .auto
            case .on: return .on
            case .off: return .off
            }
        }
    }
    
    enum SCQuality {
        case photo4K    // 4K照片
        case photoHD    // 1080p照片
        case videoHD    // 1080p视频
        case video4K    // 4K视频
        
        var sessionPreset: AVCaptureSession.Preset {
            switch self {
            case .photo4K: return .photo
            case .photoHD: return .high
            case .videoHD: return .hd1920x1080
            case .video4K: return .hd4K3840x2160
            }
        }
    }
    
    // MARK: - 属性
    var position: SCPosition = .back
    var flashMode: SCFlashMode = .auto
    var quality: SCQuality = .photoHD
    
    // MARK: - 曝光参数
    var exposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure
    var exposureDuration: CMTime?
    var ISO: Float?
    var exposureTargetBias: Float = 0.0
    var exposurePointOfInterest: CGPoint?
    
    // MARK: - 对焦参数
    var focusMode: AVCaptureDevice.FocusMode = .continuousAutoFocus
    var focusPointOfInterest: CGPoint?
    
    // MARK: - 白平衡参数
    var whiteBalanceMode: AVCaptureDevice.WhiteBalanceMode = .continuousAutoWhiteBalance
    var whiteBalanceGains: AVCaptureDevice.WhiteBalanceGains?
    
    // MARK: - 视频参数
    var videoStabilizationMode: AVCaptureVideoStabilizationMode = .auto
    var videoZoomFactor: CGFloat = 1.0
    
    // MARK: - 图像处理参数
    var hdrEnabled: Bool = false
    var nightModeEnabled: Bool = false
    
    // MARK: - 初始化方法
    init() {
        // 使用默认值初始化
    }
    
    // MARK: - 场景预设
    enum SCPreset {
        case auto      // 自动
        case portrait  // 人像
        case landscape // 风景
        case night     // 夜景
        case action    // 运动
        case custom    // 自定义
    }
    
    func applyPreset(_ preset: SCPreset) {
        switch preset {
        case .auto:
            exposureMode = .continuousAutoExposure
            focusMode = .continuousAutoFocus
            whiteBalanceMode = .continuousAutoWhiteBalance
            
        case .portrait:
            exposureMode = .continuousAutoExposure
            focusMode = .continuousAutoFocus
            whiteBalanceMode = .continuousAutoWhiteBalance
            exposureTargetBias = -0.3 // 略微降低曝光以保留细节
            
        case .landscape:
            exposureMode = .continuousAutoExposure
            focusMode = .continuousAutoFocus
            whiteBalanceMode = .continuousAutoWhiteBalance
            exposureTargetBias = 0.0
            
        case .night:
            exposureMode = .custom
            ISO = 1600
            exposureDuration = CMTimeMake(value: 1, timescale: 15) // 1/15秒
            whiteBalanceMode = .locked
            nightModeEnabled = true
            
        case .action:
            exposureMode = .custom
            exposureDuration = CMTimeMake(value: 1, timescale: 1000) // 1/1000秒
            ISO = 400
            focusMode = .continuousAutoFocus
            whiteBalanceMode = .continuousAutoWhiteBalance
            
        case .custom:
            // 保持当前设置
            break
        }
    }
    
    // MARK: - 辅助方法
    func isSupported(device: AVCaptureDevice) -> Bool {
        // 检查设备是否支持当前配置
        let supportsExposureMode = device.isExposureModeSupported(exposureMode)
        let supportsFocusMode = device.isFocusModeSupported(focusMode)
        let supportsWhiteBalanceMode = device.isWhiteBalanceModeSupported(whiteBalanceMode)
        
        return supportsExposureMode && supportsFocusMode && supportsWhiteBalanceMode
    }
    
    // MARK: - 白平衡辅助方法
    func configureWhiteBalance(for device: AVCaptureDevice) {
        guard device.isLockingWhiteBalanceWithCustomDeviceGainsSupported else { return }
        
        do {
            try device.lockForConfiguration()
            
            // 设置白平衡模式
            if device.isWhiteBalanceModeSupported(whiteBalanceMode) {
                device.whiteBalanceMode = whiteBalanceMode
            }
            
            // 如果需要锁定白平衡并且有自定义增益值
            if whiteBalanceMode == .locked, let gains = whiteBalanceGains {
                device.setWhiteBalanceModeLocked(with: gains) { _ in
                    // 白平衡调整完成的回调
                }
            }
            
            device.unlockForConfiguration()
        } catch {
            print("配置白平衡失败: \(error)")
        }
    }
} 