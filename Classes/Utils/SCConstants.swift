import UIKit
import AVFoundation

@available(iOS 15.0, *)
struct SCConstants {
    struct Screen {
        static let width = UIScreen.main.bounds.width
        static let height = UIScreen.main.bounds.height
        static let scale = UIScreen.main.scale
        static var statusBarHeight: CGFloat {
            if #available(iOS 13.0, *) {
                let window = UIApplication.shared.windows.first
                return window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
            } else {
                return UIApplication.shared.statusBarFrame.height
            }
        }
    }
    
    struct Camera {
        // 基础参数
        static let photoAspectRatio: CGFloat = 4.0 / 3.0
        static let videoAspectRatio: CGFloat = 16.0 / 9.0
        
        // 曝光参数范围
        struct Exposure {
            // 曝光补偿
            static let minEV: Float = -2.0
            static let maxEV: Float = 2.0
            static let evStep: Float = 1.0/3.0  // 1/3 EV steps
            static let autoEVTarget: Float = 0.0 // 自动模式目标曝光值
            
            // ISO
            static let minISO: Float = 100
            static let maxISO: Float = 3200
            static let recommendedMaxISO: Float = 1600  // 建议最大ISO，避免噪点
            static let isoSteps: [Float] = [100, 200, 400, 800, 1600, 3200]
            static let autoISOTarget: Float = 400  // 自动模式目标ISO
            
            // 快门速度
            static let minShutterSpeed: Double = 1.0/8000.0
            static let maxShutterSpeed: Double = 30.0
            static let defaultShutterSpeed: Double = 1.0/60.0
            static let shutterSpeedSteps: [Double] = [
                1/8000, 1/6400, 1/5000, 1/4000, 1/3200, 1/2500, 1/2000,
                1/1600, 1/1250, 1/1000, 1/800, 1/640, 1/500, 1/400,
                1/320, 1/250, 1/200, 1/160, 1/125, 1/100, 1/80,
                1/60, 1/50, 1/40, 1/30, 1/25, 1/20, 1/15,
                1/13, 1/10, 1/8, 1/6, 1/5, 1/4, 0.3, 0.4,
                0.5, 0.6, 0.8, 1, 1.3, 1.6, 2, 2.5,
                3.2, 4, 5, 6, 8, 10, 13, 15, 20, 25, 30
            ]
            
            // 场景建议值
            struct ScenePresets {
                static let daylight = (iso: Float(100), shutterSpeed: 1/125.0, ev: Float(0.0))
                static let cloudy = (iso: Float(200), shutterSpeed: 1/60.0, ev: Float(0.3))
                static let sunset = (iso: Float(400), shutterSpeed: 1/60.0, ev: Float(0.7))
                static let night = (iso: Float(1600), shutterSpeed: 1/15.0, ev: Float(1.0))
                static let action = (iso: Float(400), shutterSpeed: 1/1000.0, ev: Float(0.0))
                static let portrait = (iso: Float(100), shutterSpeed: 1/125.0, ev: Float(-0.3))
            }
        }
        
        // 白平衡参数范围
        struct WhiteBalance {
            // 白平衡增益范围
            static let minGain: Float = 1.0
            static let maxGain: Float = 4.0
            static let defaultGain: Float = 1.0
            
            // 场景建议值
            struct ScenePresets {
                static let daylight = AVCaptureDevice.WhiteBalanceGains(redGain: 1.0, greenGain: 1.0, blueGain: 1.0)
                static let cloudy = AVCaptureDevice.WhiteBalanceGains(redGain: 1.2, greenGain: 1.0, blueGain: 0.9)
                static let shade = AVCaptureDevice.WhiteBalanceGains(redGain: 1.3, greenGain: 1.0, blueGain: 0.8)
                static let tungsten = AVCaptureDevice.WhiteBalanceGains(redGain: 0.8, greenGain: 1.0, blueGain: 1.4)
                static let fluorescent = AVCaptureDevice.WhiteBalanceGains(redGain: 0.9, greenGain: 1.0, blueGain: 1.2)
            }
        }
        
        // 对焦参数
        struct Focus {
            static let minimumFocusDistance: Float = 0.0
            static let focusAnimationDuration: TimeInterval = 0.3
            static let focusViewSize = CGSize(width: 80, height: 80)
            static let focusViewBorderWidth: CGFloat = 1.0
            static let focusViewDisappearDelay: TimeInterval = 1.0
            
            // 对焦步长
            static let manualFocusSteps: Int = 20  // 手动对焦的步进数
            static let focusRampRate: Float = 0.1  // 对焦渐变速率
            
            // 场景建议值
            struct ScenePresets {
                static let landscape = 0.0  // 风景
                static let portrait = 0.3   // 人像
                static let macro = 0.8      // 微距
            }
        }
        
        // 视频参数
        struct Video {
            static let supportedFrameRates = [30, 60, 120, 240]
            static let defaultFrameRate = 30
            static let slowMotionFrameRate = 240
            
            static let minimumZoom: CGFloat = 1.0
            static let maximumZoom: CGFloat = 10.0
            static let smoothZoomRate: CGFloat = 0.5  // 平滑变焦速率
            static let zoomSteps: [CGFloat] = [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0]
            
            // 场景建议值
            struct ScenePresets {
                static let normal = (fps: 30, stabilization: true)
                static let action = (fps: 60, stabilization: true)
                static let slowMotion = (fps: 240, stabilization: false)
                static let cinematic = (fps: 24, stabilization: true)
            }
        }
        
        // 图像处理参数
        struct Processing {
            static let filterStrength: Float = 0.8  // 滤镜强度
            static let filterStrengthStep: Float = 0.1
            
            static let portraitEffectStrength: Float = 0.7  // 人像模式虚化强度
            static let portraitEffectSteps: [Float] = [0.3, 0.5, 0.7, 0.9]
            
            static let nightModeThreshold: Float = 0.1  // 夜间模式触发阈值
            static let nightModeExposureSteps: [Double] = [1/4, 1/2, 1, 2, 3]
            
            // HDR参数
            static let hdrStrength: Float = 0.5
            static let hdrStrengthStep: Float = 0.1
            
            // 场景建议值
            struct ScenePresets {
                static let standard = (filter: "none", hdr: true)
                static let vivid = (filter: "vivid", hdr: true)
                static let portrait = (filter: "portrait", hdr: false)
                static let bw = (filter: "mono", hdr: false)
            }
        }
        
        // 拍摄模式参数
        struct Capture {
            static let burstMaxCount: Int = 10  // 连拍最大张数
            static let timerOptions = [3, 5, 10]  // 定时器可选秒数
            static let maxVideoRecordingDuration: TimeInterval = 60 * 60  // 最大录制时长（1小时）
        }
        
        // 文件参数
        struct File {
            static let photoQuality: CGFloat = 0.9  // JPEG压缩质量
            static let maxPhotoSize: CGFloat = 4096  // 最大照片尺寸
            static let videoBitRate: Int = 10_000_000  // 视频比特率 (10 Mbps)
            static let audioSampleRate: Int = 44100  // 音频采样率
            static let audioBitRate: Int = 128_000  // 音频比特率 (128 kbps)
        }
        
        // 设备能力检查
        struct Capability {
            static var isDepthCaptureSupported: Bool {
                return AVCaptureDevice.default(.builtInDualCamera,
                                             for: .video,
                                             position: .back) != nil
            }
            
            static var isPortraitModeSupported: Bool {
                return AVCaptureDevice.default(.builtInDualCamera,
                                             for: .video,
                                             position: .back) != nil
            }
            
            static var isNightModeSupported: Bool {
                return true
            }
            
            static var isRAWSupported: Bool {
                let output = AVCapturePhotoOutput()
                return !output.availableRawPhotoPixelFormatTypes.isEmpty
            }
        }
        
        // 场景智能系统
        struct SceneIntelligence {
            enum SceneType {
                case auto
                case custom
                case portrait
                case landscape
                case night
                case action
                case macro
                case document
            }
            
            struct SceneParameter {
                let type: SceneType
                let exposureSettings: (iso: Float, shutterSpeed: Double, ev: Float)
                let whiteBalanceSettings: AVCaptureDevice.WhiteBalanceGains
                let focusSettings: Double
                let processingSettings: (filter: String, hdr: Bool)
            }
        }
    }
} 