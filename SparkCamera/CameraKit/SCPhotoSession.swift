//
//  SCPhotoSession.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import UIKit
import AVFoundation
import CoreMotion

// MARK: - Focus Enums
public enum SCFocusMode: Int {
    case auto = 0          // 单次自动对焦
    case continuous = 1    // 连续自动对焦
    case locked = 2        // 锁定对焦
    case manual = 3        // 手动对焦
}

public enum SCFocusState {
    case focusing       // 正在对焦
    case focused        // 对焦成功
    case failed        // 对焦失败
    case locked        // 对焦已锁定
}

extension SCSession.FlashMode {
    
    var captureFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: return .off
        case .on: return .on
        case .auto: return .auto
        }
    }
}

@objc public class SCPhotoSession: SCSession, AVCapturePhotoCaptureDelegate, AVCaptureMetadataOutputObjectsDelegate {
    
    @objc public enum CameraDetection: UInt {
        case none, faces
    }
    
    @objc public var cameraPosition: CameraPosition = .back {
        didSet {
            if cameraPosition == oldValue {
                return
            }
            
            configureInputs()
        }
    }
    
    @objc public var cameraDetection = CameraDetection.none {
        didSet {
            if oldValue == self.cameraDetection { return }
            
            for output in self.session.outputs {
                if output is AVCaptureMetadataOutput {
                    self.session.removeOutput(output)
                }
            }
            
            self.faceDetectionBoxes.forEach({ $0.removeFromSuperview() })
            self.faceDetectionBoxes = []
            
            if self.cameraDetection == .faces {
                let metadataOutput = AVCaptureMetadataOutput()
                self.session.addOutput(metadataOutput)
                
                metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
                if metadataOutput.availableMetadataObjectTypes.contains(.face) {
                    metadataOutput.metadataObjectTypes = [.face]
                }
            }
        }
    }
    
    @objc public var flashMode = SCSession.FlashMode.off
    
    var captureDeviceInput: AVCaptureDeviceInput? {
        didSet {
            if let device = captureDeviceInput?.device {
                try? device.lockForConfiguration()
                device.videoZoomFactor = CGFloat(zoom)
                device.unlockForConfiguration()
            }
        }
    }
    
    private var photoOutput: AVCapturePhotoOutput?
    
    var faceDetectionBoxes: [UIView] = []
    
    private var isPreviewLayerSetup = false
    private var isSessionRunning = false
    
    @objc public var resolution: CGSize = .zero {
        didSet {
            print("  [Photo Session] 设置分辨率: \(resolution.width) x \(resolution.height)")
            
            // 防止递归设置
            guard resolution != oldValue else { return }
            
            // 如果分辨率为零且有可用设备，使用设备最大分辨率
            if (resolution.width == 0 || resolution.height == 0),
               let device = videoInput?.device {
                let maxResolution = device.activeFormat.highResolutionStillImageDimensions
                let size = min(CGFloat(maxResolution.width), CGFloat(maxResolution.height))
                print("  [Photo Session] 使用设备最大分辨率: \(size) x \(size)")
                self.resolution = CGSize(width: size, height: size)
                return
            }
            
            // 开始配置会话
            session.beginConfiguration()
            
            // 计算目标比例
            let targetAspectRatio = resolution.width / resolution.height
            print("  [Photo Session] 目标比例: \(targetAspectRatio)")
            
            // 根据目标比例选择合适的预设
            if abs(targetAspectRatio - 3.0/4.0) < 0.01 {
                session.sessionPreset = .photo
                print("  [Photo Session] 设置会话预设为: photo (3:4)")
            } else if abs(targetAspectRatio - 9.0/16.0) < 0.01 {
                session.sessionPreset = .hd1920x1080
                print("  [Photo Session] 设置会话预设为: 1920x1080 (16:9)")
            } else if abs(targetAspectRatio - 1.0) < 0.01 {
                session.sessionPreset = .high
                print("  [Photo Session] 设置会话预设为: high (1:1)")
            }
            
            // 配置照片输出
            if let photoOutput = self.photoOutput,
               let connection = photoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            session.commitConfiguration()
            
            print("  [Photo Session] 会话配置完成")
            print("  [Photo Session] - 会话预设: \(session.sessionPreset.rawValue)")
            if let photoOutput = self.photoOutput {
                print("  [Photo Session] - 高分辨率拍摄: \(photoOutput.isHighResolutionCaptureEnabled)")
            }
        }
    }
    
    @objc public init(position: CameraPosition = .back, detection: CameraDetection = .none) {
        super.init()
        
        // 初始化照片输出
        let photoOutput = AVCapturePhotoOutput()
        self.photoOutput = photoOutput
        
        // 配置照片输出
        photoOutput.isHighResolutionCaptureEnabled = true
        print("  [Photo Session] 初始化照片输出:")
        print("  [Photo Session] - 高分辨率拍摄: \(photoOutput.isHighResolutionCaptureEnabled)")
        
        // 添加照片输出
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            print("  [Photo Session] 照片输出已添加到会话")
        } else {
            print("⚠️ [Photo Session] 无法添加照片输出到会话")
        }
        
        // 开始监听设备方向变化
        startDeviceOrientationNotifier()
        
        // 配置相机位置和检测
            self.cameraPosition = position
            self.cameraDetection = detection
        
        // 配置输入设备并设置初始分辨率
        configureInputs()
    }
    
    // 添加设备方向监听
    private var deviceOrientationNotifier: Any?
    private var currentDeviceOrientation: UIDeviceOrientation = .portrait
    private let motionManager = CMMotionManager()
    
    private func startDeviceOrientationNotifier() {
        // 确保设备支持陀螺仪
        guard motionManager.isDeviceMotionAvailable else {
            print("⚠️ [Orientation] 设备不支持运动检测")
            return
        }
        
        // 设置更新频率
        motionManager.deviceMotionUpdateInterval = 0.5
        
        // 开始监听设备运动
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let self = self,
                  let motion = motion else {
                if let error = error {
                    print("⚠️ [Orientation] 运动更新错误: \(error.localizedDescription)")
                }
                return
            }
            
            // 获取重力向量
            let gravity = motion.gravity
            
            // 根据重力方向判断设备方向
            let orientation: UIDeviceOrientation
            if gravity.z < -0.75 {
                orientation = .faceUp
            } else if gravity.z > 0.75 {
                orientation = .faceDown
            } else {
                let x = gravity.x
                let y = gravity.y
                
                if abs(y) < 0.45 {
                    orientation = x < 0 ? .landscapeRight : .landscapeLeft
                } else {
                    orientation = y < 0 ? .portrait : .portraitUpsideDown
                }
            }
            
            // 如果方向发生变化，更新当前方向
            if orientation != self.currentDeviceOrientation {
                self.currentDeviceOrientation = orientation
                print("  [Orientation] 设备方向更新: \(orientation.rawValue)")
            }
        }
        
        print("  [Orientation] 开始监听设备方向")
    }
    
    deinit {
        // 停止运动更新
        motionManager.stopDeviceMotionUpdates()
        print("  [Orientation] 停止监听设备方向")
    }
    
    // 回调闭包
    public var captureCallback: ((UIImage, [String: Any]) -> Void)?
    public var errorCallback: ((Error) -> Void)?
    
    @objc public func capture(_ callback: @escaping (UIImage, [String: Any]) -> Void, _ error: @escaping (Error) -> Void) {
        self.captureCallback = callback
        self.errorCallback = error
        
        guard let photoOutput = self.photoOutput else {
            error(SCError.error("Photo output not available"))
            return
        }
        
        // 配置照片设置
        let photoSettings = AVCapturePhotoSettings()
        
        // 检查并设置闪光灯
        if let device = self.videoInput?.device,
           device.hasFlash {
            if device.isFlashAvailable {
                photoSettings.flashMode = AVCaptureDevice.FlashMode(rawValue: Int(self.flashMode.rawValue)) ?? .auto
            }
        }
        
        // 配置高质量捕获
        photoSettings.isHighResolutionPhotoEnabled = photoOutput.isHighResolutionCaptureEnabled
        
        // 开始拍照
        print("  [Photo Session] 开始拍照...")
        print("  [Photo Session] - 高分辨率拍摄: \(photoSettings.isHighResolutionPhotoEnabled)")
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    @objc public func togglePosition() {
        self.cameraPosition = self.cameraPosition == .back ? .front : .back
    }
    
    @objc public override var zoom: Double {
        didSet {
            guard let device = self.captureDeviceInput?.device else {
                return
            }
            
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = CGFloat(self.zoom)
                device.unlockForConfiguration()
            } catch {
                //
            }
            
            if let delegate = self.delegate {
                delegate.didChangeValue(session: self, value: self.zoom, key: "zoom")
            }
        }
    }
    
    @objc public override func focus(at point: CGPoint) {
        guard let device = captureDeviceInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            // 更新对焦状态
            focusState = .focusing
            
            // 设置对焦点
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                print("  [Focus] 设置对焦点：\(point)")
                // 通知 UI 对焦点（便于显示动画）
                delegate?.didChangeValue(session: self, value: point, key: "focusPoint")
            }
            
            // 根据当前模式设置对焦
            switch focusMode {
            case .auto:
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
            case .continuous:
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
            case .locked:
                if device.isFocusModeSupported(.locked) {
                    device.focusMode = .locked
                }
            case .manual:
                // 手动对焦模式将在后续实现
                break
            }
            
            // 添加对焦观察者
            NotificationCenter.default.addObserver(self,
                                                 selector: #selector(subjectAreaDidChange),
                                                 name: .AVCaptureDeviceSubjectAreaDidChange,
                                                 object: device)
            
            device.unlockForConfiguration()
            
            // 监听对焦状态变化或延迟回调 focused
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.focusState = .focused
            }
            
            print("  [Focus] 对焦模式：\(focusMode)")
            
        } catch {
            print("⚠️ [Focus] 设置对焦失败: \(error.localizedDescription)")
            focusState = .failed
        }
    }
    
    @objc private func subjectAreaDidChange(notification: NSNotification) {
        // 主体区域发生变化时，如果是连续对焦模式，更新对焦状态
        if focusMode == .continuous {
            focusState = .focusing
            
            // 延迟更新状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.focusState = .focused
            }
        }
    }
    
    // 设置对焦模式
    public func setFocusMode(_ mode: SCFocusMode) {
        focusMode = mode
        print("  [Focus] 切换对焦模式：\(mode)")
    }
    
    // 锁定当前对焦
    public func lockFocus() {
        setFocusMode(.locked)
        focusState = .locked
        print("  [Focus] 锁定对焦")
    }
    
    // 解锁对焦
    public func unlockFocus() {
        setFocusMode(.continuous)
        print("  [Focus] 解锁对焦")
    }
    
    @available(iOS 11.0, *)
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("❌ [Photo Session] 处理照片时出错: \(error.localizedDescription)")
            self.errorCallback?(error)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("❌ [Photo Session] 无法获取图片数据")
            self.errorCallback?(SCError.error("Cannot get photo file data representation"))
            return
        }
        
        print("  [Photo Session] 照片信息:")
        print("  [Photo Session] - 数据大小: \(Double(imageData.count) / 1024.0 / 1024.0) MB")
        
        // 获取照片分辨率
        if let cgImage = UIImage(data: imageData)?.cgImage {
            print("  [Photo Session] - 实际分辨率: \(cgImage.width) x \(cgImage.height)")
        }
        
        // 处理照片数据
        self.processPhotoData(imageData)
    }
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if let error = error {
            self.errorCallback?(error)
            return
        }

        guard
            let photoSampleBuffer = photoSampleBuffer,
            let previewPhotoSampleBuffer = previewPhotoSampleBuffer,
            let data = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer) else
        {
            self.errorCallback?(SCError.error("Cannot get photo file data representation"))
            return
        }

        self.processPhotoData(data)
    }
    
    func processPhotoData(_ data: Data) {
        print("  [Photo Session] ===== 处理照片数据 =====")
        print("  [Photo Session] - 数据大小: \(Double(data.count) / 1024.0 / 1024.0) MB")
        
        guard let image = UIImage(data: data) else {
            print("❌ [Photo Session] 无法从数据创建图像")
            self.errorCallback?(SCError.error("Cannot create image from data"))
            return
        }
        
        print("  [Photo Session] 原始图片信息:")
        print("  [Photo Session] - 尺寸: \(image.size.width) x \(image.size.height)")
        print("  [Photo Session] - 方向: \(image.imageOrientation.rawValue)")
        
        // 异步处理图像
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 获取当前设备方向
            let deviceOrientation = self.currentDeviceOrientation
            print("  [Photo Process] 设备方向: \(deviceOrientation.rawValue)")
            
            // 确定图片方向
            let imageOrientation: UIImage.Orientation = {
                // 如果是横屏拍摄（宽大于高），需要特殊处理
                let isLandscape = image.size.width > image.size.height
                
                switch deviceOrientation {
                case .portrait:
                    if isLandscape {
                        return self.cameraPosition == .front ? .leftMirrored : .left
                    }
                    return self.cameraPosition == .front ? .rightMirrored : .right
                case .portraitUpsideDown:
                    if isLandscape {
                        return self.cameraPosition == .front ? .rightMirrored : .right
                    }
                    return self.cameraPosition == .front ? .leftMirrored : .left
                case .landscapeLeft:
                    return self.cameraPosition == .front ? .downMirrored : .down
                case .landscapeRight:
                    return self.cameraPosition == .front ? .upMirrored : .up
                case .faceUp, .faceDown:
                    // 如果设备平放，使用预览层的方向
                    if let connection = self.previewLayer?.connection,
                       connection.isVideoOrientationSupported {
                        switch connection.videoOrientation {
                        case .portrait:
                            if isLandscape {
                                return self.cameraPosition == .front ? .leftMirrored : .left
                            }
                            return self.cameraPosition == .front ? .rightMirrored : .right
                        case .portraitUpsideDown:
                            if isLandscape {
                                return self.cameraPosition == .front ? .rightMirrored : .right
                            }
                            return self.cameraPosition == .front ? .leftMirrored : .left
                        case .landscapeLeft:
                            return self.cameraPosition == .front ? .upMirrored : .up
                        case .landscapeRight:
                            return self.cameraPosition == .front ? .downMirrored : .down
                        @unknown default:
                            if isLandscape {
                                return self.cameraPosition == .front ? .leftMirrored : .left
                            }
                            return self.cameraPosition == .front ? .rightMirrored : .right
                        }
                    }
                    if isLandscape {
                        return self.cameraPosition == .front ? .leftMirrored : .left
                    }
                    return self.cameraPosition == .front ? .rightMirrored : .right
                default:
                    if isLandscape {
                        return self.cameraPosition == .front ? .leftMirrored : .left
                    }
                    return self.cameraPosition == .front ? .rightMirrored : .right
                }
            }()
            
            print("  [Photo Process] 目标图片方向: \(imageOrientation.rawValue)")
            
            // 1. 创建正确方向的图片
            let cgImage = image.cgImage!
            let orientedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: imageOrientation)
            
            print("  [Photo Process] 调整方向后的图片尺寸: \(orientedImage.size.width) x \(orientedImage.size.height)")
            
            // 2. 确定目标裁剪比例
            enum CropAspectRatio: CGFloat {
                case ratio3x4 = 0.75      // 3:4
                case ratio9x16 = 0.5625   // 9:16
                case ratio1x1 = 1.0       // 1:1
                
                var description: String {
                    switch self {
                    case .ratio3x4: return "3:4"
                    case .ratio9x16: return "9:16"
                    case .ratio1x1: return "1:1"
                    }
                }
                
                var inverse: CGFloat {
                    switch self {
                    case .ratio3x4: return 4.0/3.0  // 1.333...
                    case .ratio9x16: return 16.0/9.0  // 1.777...
                    case .ratio1x1: return 1.0
                    }
                }
            }
            
            // 使用预览视图的比例
            let previewRatio = self.resolution.width / self.resolution.height
            let targetRatio: CropAspectRatio = {
                // 根据预览比例确定目标裁剪比例
                if abs(previewRatio - 1.0) < 0.01 {
                    return .ratio1x1
                } else if abs(previewRatio - 0.75) < 0.01 {
                    return .ratio3x4
                } else if abs(previewRatio - 0.5625) < 0.01 {
                    return .ratio9x16
        } else {
                    // 默认使用 1:1
                    return .ratio1x1
                }
            }()
            
            print("  [Photo Process] 预览比例: \(previewRatio) [resolution]:\(self.resolution)")
            print("  [Photo Process] 目标裁剪比例: \(targetRatio.description) (\(targetRatio.rawValue))")
            
            // 3. 计算裁剪区域
            let cropRect: CGRect = {
                let imageWidth = orientedImage.size.width
                let imageHeight = orientedImage.size.height
                
                // 根据图片方向调整宽高比计算
                let isRotated = orientedImage.imageOrientation == .right || orientedImage.imageOrientation == .left
                let effectiveWidth = isRotated ? imageHeight : imageWidth
                let effectiveHeight = isRotated ? imageWidth : imageHeight
                let currentRatio = effectiveWidth / effectiveHeight
                
                print("  [Photo Process] 图片信息:")
                print("  [Photo Process] - 原始尺寸: \(imageWidth) x \(imageHeight)")
                print("  [Photo Process] - 有效尺寸: \(effectiveWidth) x \(effectiveHeight)")
                print("  [Photo Process] - 当前比例: \(currentRatio)")
                
                // 检查是否需要裁剪
                let needsCrop: Bool = {
                    switch targetRatio {
                    case .ratio1x1:
                        // 1:1模式总是需要裁剪成正方形
                        return true
                    case .ratio9x16:
                        // 16:9模式，如果是16:9或9:16不裁剪
                        let ratio16_9 = 16.0/9.0
                        let ratio9_16 = 9.0/16.0
                        return !(abs(currentRatio - ratio16_9) < 0.01 || abs(currentRatio - ratio9_16) < 0.01)
                    case .ratio3x4:
                        // 4:3模式，如果是4:3或3:4不裁剪
                        let ratio4_3 = 4.0/3.0
                        let ratio3_4 = 3.0/4.0
                        return !(abs(currentRatio - ratio4_3) < 0.01 || abs(currentRatio - ratio3_4) < 0.01)
                    }
                }()
                
                if !needsCrop {
                    print("  [Photo Process] 图片比例已匹配目标比例 \(targetRatio.description)，无需裁剪")
                    return CGRect(origin: .zero, size: orientedImage.size)
                }
                
                var rect: CGRect
                
                // 计算目标比例
                let targetAspectRatio: CGFloat = {
                    switch targetRatio {
                    case .ratio1x1:
                        return 1.0
                    case .ratio9x16:
                        return currentRatio > 1.0 ? 16.0/9.0 : 9.0/16.0
                    case .ratio3x4:
                        return currentRatio > 1.0 ? 4.0/3.0 : 3.0/4.0
                    }
                }()
                
                // 居中裁剪
                if currentRatio > targetAspectRatio {
                    // 图片太宽，从两边裁剪
                    let targetWidth = effectiveHeight * targetAspectRatio
                    let xOffset = (effectiveWidth - targetWidth) / 2
                    if isRotated {
                        rect = CGRect(x: 0, y: xOffset, width: imageWidth, height: targetWidth)
            } else {
                        rect = CGRect(x: xOffset, y: 0, width: targetWidth, height: imageHeight)
                    }
                    } else {
                    // 图片太高，从上下裁剪
                    let targetHeight = effectiveWidth / targetAspectRatio
                    let yOffset = (effectiveHeight - targetHeight) / 2
                    if isRotated {
                        rect = CGRect(x: yOffset, y: 0, width: targetHeight, height: imageHeight)
                    } else {
                        rect = CGRect(x: 0, y: yOffset, width: imageWidth, height: targetHeight)
                    }
                }
                
                print("  [Photo Process] 裁剪信息:")
                print("  [Photo Process] - 目标比例: \(targetAspectRatio)")
                print("  [Photo Process] - 裁剪区域: \(rect)")
                
                return rect
            }()
            
            print("  [Photo Process] 裁剪区域: \(cropRect)")
            print("  [Photo Process] 裁剪后宽高比: \(cropRect.width / cropRect.height)")
//#warning("测试代码")
//#if DEBUG//debug代码
//            let debugImageInfo: [String: Any] = [
//                "aspectRatio": image.size.width / image.size.height,
//                "isLandscape": image.size.width > image.size.height,
//                "width": image.size.width,
//                "height": image.size.height,
//                "orientation": image.imageOrientation.rawValue
//            ]
//            DispatchQueue.main.async {
//                if let callback = self.captureCallback {
//                    callback(image, debugImageInfo)
//                }
//            }
//            return
//#endif
            // 4. 执行裁剪
            if cropRect == CGRect(origin: .zero, size: orientedImage.size) {
                print("  [Photo Process] 无需裁剪，使用原始图片")
                let photoInfo = SCPhotoInfo(image: orientedImage)
                print(photoInfo.description)
                DispatchQueue.main.async {
                    self.captureCallback?(orientedImage, photoInfo.dictionary)
                }
                return
            }
            
            // 根据图片方向调整裁剪区域
            let adjustedCropRect: CGRect
            if orientedImage.imageOrientation == .right || orientedImage.imageOrientation == .left {
                // 对于旋转的图片，交换裁剪区域的宽高，并保持居中
                let xOffset = cropRect.minY
                let yOffset = cropRect.minX
                let width = cropRect.height
                let height = cropRect.width
                adjustedCropRect = CGRect(
                    x: xOffset,
                    y: yOffset,
                    width: width,
                    height: height
                )
                print("  [Photo Process] 调整后的裁剪区域: \(adjustedCropRect)")
                print("  [Photo Process] - x偏移: \(xOffset), y偏移: \(yOffset)")
                print("  [Photo Process] - 宽度: \(width), 高度: \(height)")
            } else {
                adjustedCropRect = cropRect
                print("  [Photo Process] 保持原始裁剪区域: \(adjustedCropRect)")
                print("  [Photo Process] - x偏移: \(cropRect.minX), y偏移: \(cropRect.minY)")
                print("  [Photo Process] - 宽度: \(cropRect.width), 高度: \(cropRect.height)")
            }
            
            guard let croppedCGImage = orientedImage.cgImage?.cropping(to: adjustedCropRect) else {
                print("⚠️ [Photo Process] 裁剪失败，使用原始图片")
                let photoInfo = SCPhotoInfo(image: orientedImage)
                print(photoInfo.description)
                DispatchQueue.main.async {
                    self.captureCallback?(orientedImage, photoInfo.dictionary)
                }
                return
            }
            
            // 5. 创建最终图片，保持原始方向
            let finalImage = UIImage(cgImage: croppedCGImage, scale: orientedImage.scale, orientation: orientedImage.imageOrientation)
            
            // 创建照片信息
            let photoInfo = SCPhotoInfo(image: finalImage)
            print(photoInfo.description)
            
            DispatchQueue.main.async {
                self.captureCallback?(finalImage, photoInfo.dictionary)
                print("  [Photo Session] ===== 照片处理完成 =====")
            }
        }
    }
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        let faceMetadataObjects = metadataObjects.filter({ $0.type == .face })
        
        if faceMetadataObjects.count > self.faceDetectionBoxes.count {
            for _ in 0..<faceMetadataObjects.count - self.faceDetectionBoxes.count {
                let view = UIView()
                view.layer.borderColor = UIColor.green.cgColor
                view.layer.borderWidth = 1
                self.overlayView?.addSubview(view)
                self.faceDetectionBoxes.append(view)
            }
        } else if faceMetadataObjects.count < self.faceDetectionBoxes.count {
            for _ in 0..<self.faceDetectionBoxes.count - faceMetadataObjects.count {
                self.faceDetectionBoxes.popLast()?.removeFromSuperview()
            }
        }
        
        for i in 0..<faceMetadataObjects.count {
            if let transformedMetadataObject = self.previewLayer?.transformedMetadataObject(for: faceMetadataObjects[i]) {
                self.faceDetectionBoxes[i].frame = transformedMetadataObject.bounds
            } else {
                self.faceDetectionBoxes[i].frame = CGRect.zero
            }
        }
    }
    
    private func configureInputs() {
        session.beginConfiguration()
        
        // 移除现有输入
        for input in session.inputs {
            session.removeInput(input)
        }
        
        // 移除现有输出
        for output in session.outputs {
            session.removeOutput(output)
        }
        
        // 重新创建和配置照片输出
        let newPhotoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(newPhotoOutput) {
            session.addOutput(newPhotoOutput)
            photoOutput = newPhotoOutput
            
            // 配置照片输出
            newPhotoOutput.isHighResolutionCaptureEnabled = true
            if let connection = newPhotoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            print("  [Photo Session] 照片输出已添加到会话")
            print("  [Photo Session] - 高分辨率拍摄: \(newPhotoOutput.isHighResolutionCaptureEnabled)")
        } else {
            print("⚠️ [Photo Session] 无法添加照片输出到会话")
        }
        
        do {
            let deviceInput = try SCSession.captureDeviceInput(type: cameraPosition.deviceType)
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
                self.captureDeviceInput = deviceInput
                
                // 获取设备支持的最大分辨率
                let maxResolution = deviceInput.device.activeFormat.highResolutionStillImageDimensions
                let maxSize = min(CGFloat(maxResolution.width), CGFloat(maxResolution.height))
                
                // 根据当前比例模式设置分辨率
                if self.resolution.width == 0 || self.resolution.height == 0 {
                    let ratioMode = SCCameraSettingsManager.shared.ratioMode
                    let targetSize: CGSize
                    
                    switch ratioMode {
                    case 0: // 4:3
                        targetSize = CGSize(width: maxSize * 0.75, height: maxSize)
                    case 1: // 1:1
                        targetSize = CGSize(width: maxSize, height: maxSize)
                    case 2: // 16:9
                        targetSize = CGSize(width: maxSize * 0.5625, height: maxSize)
                    default:
                        targetSize = CGSize(width: maxSize * 0.75, height: maxSize)
                    }
                    
                    print("  [Photo Session] 根据比例模式[\(ratioMode)]设置初始分辨率: \(targetSize.width) x \(targetSize.height)")
                    self.resolution = targetSize
                }
            }
        } catch {
            print("Error configuring camera input: \(error.localizedDescription)")
        }
        
        session.commitConfiguration()
    }

    override func setupPreviewLayer(in view: UIView, completion: (() -> Void)? = nil) {
        guard !isPreviewLayerSetup else { return }
        
        let startTime = Date()
        print("⏱️ [Preview Setup] Started at: \(startTime)")
        
        // 1. 创建预览层
        let previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        print("⏱️ [Preview Setup] Preview layer created: +\(Date().timeIntervalSince(startTime))s")
        
        // 2. 在主线程设置UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.bounds
            view.layer.insertSublayer(previewLayer, at: 0)
            self.previewLayer = previewLayer
            self.isPreviewLayerSetup = true
            print("⏱️ [Preview Setup] Preview layer configured: +\(Date().timeIntervalSince(startTime))s")
            
            // 3. 在后台线程启动会话
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                if !self.isSessionRunning {
                    print("⏱️ [Preview Setup] Starting session: +\(Date().timeIntervalSince(startTime))s")
                    self.session.startRunning()
                    self.isSessionRunning = true
                    print("⏱️ [Preview Setup] Session started: +\(Date().timeIntervalSince(startTime))s")
                    
                    // 确保会话启动后再次检查分辨率
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        if self.resolution.width == 0 || self.resolution.height == 0,
                           let device = self.videoInput?.device {
                            let maxResolution = device.activeFormat.highResolutionStillImageDimensions
                            let maxSize = min(CGFloat(maxResolution.width), CGFloat(maxResolution.height))
                            
                            // 根据当前比例模式设置分辨率
                            let ratioMode = SCCameraSettingsManager.shared.ratioMode
                            let targetSize: CGSize
                            
                            switch ratioMode {
                            case 0: // 4:3
                                targetSize = CGSize(width: maxSize * 0.75, height: maxSize)
                            case 1: // 1:1
                                targetSize = CGSize(width: maxSize, height: maxSize)
                            case 2: // 16:9
                                targetSize = CGSize(width: maxSize * 0.5625, height: maxSize)
                            default:
                                targetSize = CGSize(width: maxSize * 0.75, height: maxSize)
                            }
                            
                            print("  [Preview Setup] 根据比例模式[\(ratioMode)]设置分辨率: \(targetSize.width) x \(targetSize.height)")
                            self.resolution = targetSize
                        }
                        print("⏱️ [Preview Setup] Setup completed: +\(Date().timeIntervalSince(startTime))s")
                        completion?()
                    }
                }
            }
        }
    }

    // MARK: - Focus Methods
    private func loadFocusSettings() {
        let settings = SCCameraSettingsManager.shared
        focusMode = settings.focusMode
        
        if settings.isFocusLocked {
            lockFocus()
        }
    }

    // MARK: - Session Setup
    private func setupSession() {
        session.beginConfiguration()
        
        // 设置会话质量
        session.sessionPreset = .photo
        
        // 设置视频输入
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("无法获取相机设备")
            session.commitConfiguration()
            return
        }
        
        do {
            videoInput = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(videoInput!) {
                session.addInput(videoInput!)
            }
        } catch {
            print("设置视频输入失败: \(error)")
            session.commitConfiguration()
            return
        }
        
        // 设置照片输出
        photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput!) {
            session.addOutput(photoOutput!)
        }
        
        session.commitConfiguration()
    }
    
    // MARK: - Session Control
    func startSession() {
        // 确保在后台线程调用
        if Thread.isMainThread {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.startSession()
            }
            return
        }
        
        if !session.isRunning {
            session.startRunning()
        }
    }
    
    func stopSession() {
        // 确保在后台线程调用
        if Thread.isMainThread {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.stopSession()
            }
            return
        }
        
        if session.isRunning {
            session.stopRunning()
        }
    }

    // MARK: - Flash Control
    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) -> Bool {
        guard let device = captureDeviceInput?.device else { return false }
        
        do {
            try device.lockForConfiguration()
            if device.hasFlash && device.isFlashAvailable {
                device.flashMode = mode
                device.unlockForConfiguration()
                return true
            } else {
                device.unlockForConfiguration()
                return false
            }
            print("设置闪光灯模式为：\(mode)")
        } catch {
            print("设置闪光灯失败: \(error)")
            return false
        }
    }
    
    var isFlashAvailable: Bool {
        guard let device = captureDeviceInput?.device else { return false }
        return device.hasFlash && device.isFlashAvailable
    }
    
    var currentFlashMode: AVCaptureDevice.FlashMode? {
        return captureDeviceInput?.device.flashMode
    }

    public func setWhiteBalanceMode(_ state: SCWhiteBalanceState) -> Bool {
        guard let device = captureDeviceInput?.device else { return false }
        
        do {
            try device.lockForConfiguration()
            
            switch state {
            case .auto:
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                    print("设置自动白平衡模式成功")
                } else {
                    print("设备不支持自动白平衡模式")
                    device.unlockForConfiguration()
                    return false
                }
                
            case .sunny, .cloudy, .fluorescent, .incandescent:
                if device.isWhiteBalanceModeSupported(.locked) {
                    device.whiteBalanceMode = .locked
                    let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                        temperature: state.temperature,
                        tint: state.tint
                    )
                    let gains = device.deviceWhiteBalanceGains(for: temperatureAndTint)
                    let normalizedGains = self.normalizeWhiteBalanceGains(gains, for: device)
                    device.setWhiteBalanceModeLocked(with: normalizedGains)
                    print("设置白平衡模式成功：\(state.title)")
                } else {
                    print("设备不支持锁定白平衡模式")
                    device.unlockForConfiguration()
                    return false
                }
            }
            
            device.unlockForConfiguration()
            return true
        } catch {
            print("设置白平衡模式失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // 辅助方法：确保白平衡增益值在设备支持的范围内
    private func normalizeWhiteBalanceGains(_ gains: AVCaptureDevice.WhiteBalanceGains, for device: AVCaptureDevice) -> AVCaptureDevice.WhiteBalanceGains {
        var normalizedGains = gains
        
        // 确保每个增益值都在设备支持的范围内
        let minGain: Float = 1.0  // 最小增益值通常为 1.0
        let maxGain: Float = device.maxWhiteBalanceGain
        
        normalizedGains.redGain = min(max(gains.redGain, minGain), maxGain)
        normalizedGains.greenGain = min(max(gains.greenGain, minGain), maxGain)
        normalizedGains.blueGain = min(max(gains.blueGain, minGain), maxGain)
        
        return normalizedGains
    }

    // MARK: - Camera Settings
    public func setExposure(_ value: Float) -> Bool {
        guard let device = captureDeviceInput?.device else { return false }

        do {
            try device.lockForConfiguration()
            
            // 首先切换到自动曝光模式
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
                
                // 获取设备支持的曝光范围
                let minExposure = device.minExposureTargetBias
                let maxExposure = device.maxExposureTargetBias
                
                // 将输入值 (-2.0 到 +2.0) 映射到设备支持的范围
                let normalizedValue = (value + 2.0) / 4.0  // 将 -2.0~2.0 映射到 0~1
                let exposureValue = minExposure + (maxExposure - minExposure) * normalizedValue
                
                // 确保值在设备支持的范围内
                let clampedValue = min(max(exposureValue, minExposure), maxExposure)
                
                // 应用曝光值
                device.setExposureTargetBias(clampedValue)
                print("  [Exposure] 设置曝光值：\(clampedValue) (原始值：\(value))")
                print("  [Exposure] 设备支持范围：[\(minExposure), \(maxExposure)]")
                
                // 等待曝光调整生效
                device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
            } else {
                print("⚠️ [Exposure] 设备不支持自动曝光模式")
                device.unlockForConfiguration()
                return false
            }
            
            device.unlockForConfiguration()
            return true
        } catch {
            print("⚠️ [Exposure] 设置曝光值失败: \(error.localizedDescription)")
            return false
        }
    }
    
    public func setISO(_ value: Float) -> Bool {
        guard let device = captureDeviceInput?.device else { return false }
        
        do {
            try device.lockForConfiguration()
            
            if value == 0 {
                // Auto ISO
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                    print("设置 ISO 为自动模式")
                } else {
                    print("设备不支持自动 ISO 模式")
                    device.unlockForConfiguration()
                    return false
                }
            } else {
                // Manual ISO
                if device.isExposureModeSupported(.custom) {
                    device.exposureMode = .custom
                    let isoValue = min(max(value, device.activeFormat.minISO), device.activeFormat.maxISO)
                    device.setExposureModeCustom(duration: device.exposureDuration, iso: isoValue)
                    print("设置 ISO 值为：\(isoValue)")
                } else {
                    print("设备不支持自定义 ISO 模式")
                    device.unlockForConfiguration()
                    return false
                }
            }
            
            device.unlockForConfiguration()
            return true
        } catch {
            print("设置 ISO 失败: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Focus Mode
    public private(set) var focusMode: SCFocusMode = .continuous {
        didSet {
            updateFocusMode()
            // 保存设置
            SCCameraSettingsManager.shared.focusMode = focusMode
        }
    }
    
    public private(set) var focusState: SCFocusState = .focused {
        didSet {
            // 通知代理焦点状态变化
            if let delegate = self.delegate {
                delegate.didChangeValue(session: self, value: focusState, key: "focusState")
            }
            
            // 更新对焦锁定状态
            if focusState == .locked {
                SCCameraSettingsManager.shared.isFocusLocked = true
            } else if focusState == .focused && focusMode != .locked {
                SCCameraSettingsManager.shared.isFocusLocked = false
            }
        }
    }
    
    private func updateFocusMode() {
        guard let device = captureDeviceInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            switch focusMode {
            case .auto:
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
            case .continuous:
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
            case .locked:
                if device.isFocusModeSupported(.locked) {
                    device.focusMode = .locked
                }
            case .manual:
                // 手动对焦模式将在后续实现
                break
            }
            
            device.unlockForConfiguration()
        } catch {
            print("⚠️ [Focus] 更新对焦模式失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Shutter Speed Control
    public func setShutterSpeed(_ value: Float, completion: ((Bool) -> Void)? = nil) -> Bool {
        guard let device = videoInput?.device else {
            print("  [Shutter Speed] 无法获取相机设备")
            completion?(false)
            return false
        }
        
        do {
            try device.lockForConfiguration()
            
            // 检查设备是否支持自定义曝光模式
            if device.isExposureModeSupported(.custom) {
                if value == 0 {
                    // 值为0时，切换到自动曝光模式
                    device.exposureMode = .continuousAutoExposure
                    print("  [Shutter Speed] 切换到自动曝光模式")
                    device.unlockForConfiguration()
                    completion?(true)
                    return true
                } else {
                    // 设置自定义曝光模式
                    device.exposureMode = .custom
                    
                    // 禁用自动曝光补偿
                    if device.isExposurePointOfInterestSupported {
                        device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
                    }
                    
                    // 将快门速度值转换为 CMTime
                    // value 表示秒数，例如 value = 0.001 表示 1/1000 秒
                    let seconds = value
                    print("  [Shutter Speed] 设置快门速度：\(seconds)秒 (1/\(Int(1/seconds))秒)")
                    let shutterSpeed = CMTimeMakeWithSeconds(Float64(seconds), preferredTimescale: 1000000)
                    
                    // 获取设备支持的快门速度范围
                    let minDuration = device.activeFormat.minExposureDuration
                    let maxDuration = device.activeFormat.maxExposureDuration
                    print("  [Shutter Speed] 设备支持的快门速度范围：[\(CMTimeGetSeconds(minDuration))秒, \(CMTimeGetSeconds(maxDuration))秒]")
                    
                    // 确保快门速度在有效范围内
                    let clampedDuration = min(max(shutterSpeed, minDuration), maxDuration)
                    
                    // 使用固定的 ISO 值
                    let baseISO = device.activeFormat.minISO
                    print("  [Shutter Speed] 使用固定 ISO 值：\(baseISO)")
                    
                    // 设置曝光时间和 ISO
                    device.setExposureModeCustom(duration: clampedDuration, iso: baseISO) { _ in
                        print("  [Shutter Speed] 设置完成 - 快门速度: \(CMTimeGetSeconds(clampedDuration))秒, ISO: \(baseISO)")
                        completion?(true)
                    }
                }
                
                device.unlockForConfiguration()
                return true
            } else {
                print("⚠️ [Shutter Speed] 设备不支持自定义曝光模式")
                device.unlockForConfiguration()
                completion?(false)
                return false
            }
        } catch {
            print("  [Shutter Speed] 设置失败: \(error.localizedDescription)")
            completion?(false)
            return false
        }
    }

}
