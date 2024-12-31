//
//  SCSession.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import AVFoundation
import UIKit

public extension UIDeviceOrientation {
    
    var videoOrientation: AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return .portrait
        }
    }
}

private extension SCSession.DeviceType {
    
    var captureDeviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .frontCamera, .backCamera:
            return .builtInWideAngleCamera
        case .microphone:
            return .builtInMicrophone
        }
    }
    
    var captureMediaType: AVMediaType {
        switch self {
        case .frontCamera, .backCamera:
            return .video
        case .microphone:
            return .audio
        }
    }
    
    var capturePosition: AVCaptureDevice.Position {
        switch self {
        case .frontCamera:
            return .front
        case .backCamera:
            return .back
        case .microphone:
            return .unspecified
        }
    }
}

extension SCSession.CameraPosition {
    var deviceType: SCSession.DeviceType {
        switch self {
        case .back:
            return .backCamera
        case .front:
            return .frontCamera
        }
    }
}

@objc public protocol SCSessionDelegate: class {
    @objc func didChangeValue(session: SCSession, value: Any, key: String)
}

@objc public class SCSession: NSObject {
    
    @objc public enum DeviceType: UInt {
        case frontCamera, backCamera, microphone
    }
    
    @objc public enum CameraPosition: UInt {
        case front, back
    }
    
    @objc public enum FlashMode: UInt {
        case off, on, auto
    }
    
    @objc public let session: AVCaptureSession
    
    @objc public var previewLayer: AVCaptureVideoPreviewLayer?
    @objc public var overlayView: UIView?
    
    @objc public weak var delegate: SCSessionDelegate?
    
    @objc public private(set) var isWideAngleAvailable: Bool = false
    
    @objc public var videoInput: AVCaptureDeviceInput?
    internal var currentLens: SCLensModel? {
        didSet {
            // 这里可以添加一些逻辑来处理镜头切换后的操作
        }
    }
    
    @objc override init() {
        self.session = AVCaptureSession()
        super.init()
        setupCamera()
        
        // 初始化时设置 currentLens
        if let defaultLens = getAvailableLensOptions().first(where: { $0.name == "1x" }) {
            self.currentLens = defaultLens
            print("Initial lens set to \(defaultLens.name)")
        }
    }
    
    @objc deinit {
        DispatchQueue.main.async {  
            self.session.stopRunning()
        }
    }
    
    @objc public func start() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
    
    @objc public func stop() {
        DispatchQueue.main.async {
            self.session.stopRunning()
        }
    }
    
    @objc public func focus(at point: CGPoint) {
        guard let device = videoInput?.device else {
            print("Error: No video input device available.")
            return
        }
        
        do {
            try device.lockForConfiguration()
            print("Device locked for configuration.")
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
                print("Focus point set to: \(point)")
            } else {
                print("Focus point of interest not supported.")
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
                print("Exposure point set to: \(point)")
            } else {
                print("Exposure point of interest not supported.")
            }
            
            device.unlockForConfiguration()
            print("Device unlocked after configuration.")
        } catch {
            print("Error setting focus: \(error.localizedDescription)")
            device.unlockForConfiguration() // 确保设备解锁
        }
    }
    
    @objc public static func captureDeviceInput(type: DeviceType) throws -> AVCaptureDeviceInput {
        let captureDevices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [type.captureDeviceType],
            mediaType: type.captureMediaType,
            position: type.capturePosition)
        
        guard let captureDevice = captureDevices.devices.first else {
            throw SCError.captureDeviceNotFound
        }
        
        return try AVCaptureDeviceInput(device: captureDevice)
    }
    
    @objc public static func deviceInputFormat(input: AVCaptureDeviceInput, width: Int, height: Int, frameRate: Int = 30) -> AVCaptureDevice.Format? {
        for format in input.device.formats {
            let dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            if dimension.width >= width && dimension.height >= height {
                for range in format.videoSupportedFrameRateRanges {
                    if Int(range.maxFrameRate) >= frameRate && Int(range.minFrameRate) <= frameRate {
                        return format
                    }
                }
            }
        }
        
        return nil
    }
    
    private func setupCamera() {
        // 开始配置前先移除所有现有输入
        session.beginConfiguration()
        for input in session.inputs {
            session.removeInput(input)
        }
        
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            do {
                videoInput = try AVCaptureDeviceInput(device: device)
                if let videoInput = videoInput {
                    if session.canAddInput(videoInput) {
                        session.addInput(videoInput)
                    }
                }
                
                try device.lockForConfiguration()
                device.videoZoomFactor = 1.0
                device.unlockForConfiguration()
                
            } catch {
                print("Error setting up camera: \(error.localizedDescription)")
            }
        }
        
        session.commitConfiguration()
    }
    
    @objc public var zoom: Double = 1.0 {
        didSet {
            guard let device = videoInput?.device else { return }
            
            do {
                try device.lockForConfiguration()
                
                if currentLens?.name == "0.5x" {
                    device.videoZoomFactor = CGFloat(max(1.0, min(2.0, zoom)))
                    print("0.5x lens zoom factor set to \(device.videoZoomFactor)")
                } else if currentLens?.name == "1x" {
                    device.videoZoomFactor = CGFloat(max(1.0, min(2.96, zoom)))
                    print("1x lens zoom factor set to \(device.videoZoomFactor)")
                } else if currentLens?.name == "3x" {
                    device.videoZoomFactor = CGFloat(max(1.0, min(15.0, zoom)))
                    print("3x lens zoom factor set to \(device.videoZoomFactor)")
                } else {
                    device.videoZoomFactor = CGFloat(max(1.0, min(15.0, zoom)))
                }

                device.unlockForConfiguration()
            } catch {
                print("Error setting zoom: \(error.localizedDescription)")
            }
        }
    }
    
    func getAvailableLensOptions() -> [SCLensModel] {
        return [
            SCLensModel(name: "0.5x", type: .builtInUltraWideCamera),
            SCLensModel(name: "1x", type: .builtInWideAngleCamera),
            SCLensModel(name: "3x", type: .builtInTelephotoCamera)
        ]
    }
    
    func setupPreviewLayer(in view: UIView, completion: (() -> Void)? = nil) {
        // 基类的默认实现为空
    }
}
