//
//  CKSession.swift
//  CameraKit
//
//  Created by Adrian Mateoaea on 08/01/2019.
//  Copyright © 2019 Wonderkiln. All rights reserved.
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
    
    @objc public var zoom = 1.0
    
    @objc public weak var delegate: SCSessionDelegate?
    
    @objc override init() {
        self.session = AVCaptureSession()
    }
    
    @objc deinit {
        self.session.stopRunning()
    }
    
    @objc public func start() {
        self.session.startRunning()
    }
    
    @objc public func stop() {
        self.session.stopRunning()
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
}
