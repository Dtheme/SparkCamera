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
    
    private var videoInput: AVCaptureDeviceInput?
    
    @objc override init() {
        self.session = AVCaptureSession()
        super.init()
        setupCamera()
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
        //
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
            isWideAngleAvailable = device.minAvailableVideoZoomFactor <= 0.5
            
            do {
                videoInput = try AVCaptureDeviceInput(device: device)
                if let videoInput = videoInput {
                    if session.canAddInput(videoInput) {
                        session.addInput(videoInput)
                    }
                }
                
                if isWideAngleAvailable {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = 1.0
                    device.unlockForConfiguration()
                }
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
                let minZoom = isWideAngleAvailable ? 0.5 : 1.0
                device.videoZoomFactor = CGFloat(max(minZoom, min(10.0, zoom)))
                device.unlockForConfiguration()
            } catch {
                print("Error setting zoom: \(error.localizedDescription)")
            }
        }
    }
}
