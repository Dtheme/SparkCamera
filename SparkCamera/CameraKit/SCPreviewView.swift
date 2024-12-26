//
//  SCPreviewView.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/19.
//

import UIKit
import AVFoundation

@objc public class SCPreviewView: UIView {
    
    private var lastScale: CGFloat = 1.0
    public var currentZoomFactor: CGFloat = 1.0
    public var maxZoomFactor: CGFloat = 15.0
    
    @objc private(set) public var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            
            if let previewLayer = previewLayer {
                self.layer.addSublayer(previewLayer)
            }
        }
    }
    
    @objc public var session: SCSession? {
        didSet {
            oldValue?.stop()
            
            if let session = session {
                self.previewLayer = AVCaptureVideoPreviewLayer(session: session.session)
                session.previewLayer = self.previewLayer
                session.overlayView = self
                session.start()
                
                // 初始化时设置 maxZoomFactor
                if let lensName = session.currentLens?.name {
                    switch lensName {
                    case "0.5x":
                        self.maxZoomFactor = 2.0
                    case "1x":
                        self.maxZoomFactor = 2.96
                    default:
                        self.maxZoomFactor = 2.96
                    }
                    print("Initial maxZoomFactor set to \(self.maxZoomFactor)")
                }
            }
        }
    }
    
    @objc private(set) public var gridView: SCGridView? {
        didSet {
            oldValue?.removeFromSuperview()
            
            if let gridView = self.gridView {
                self.addSubview(gridView)
            }
        }
    }
    
    @objc public var showGrid: Bool = false {
        didSet {
            if self.showGrid == oldValue {
                return
            }
            
            if self.showGrid {
                self.gridView = SCGridView(frame: self.bounds)
            } else {
                self.gridView = nil
            }
        }
    }
    
    @objc public var autorotate: Bool = false {
        didSet {
            if !self.autorotate {
                self.previewLayer?.connection?.videoOrientation = .portrait
            }
        }
    }
    
    private var zoomLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 5
        label.clipsToBounds = true
        return label
    }()
    
    @objc public override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupView()
    }
    
    @objc public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setupView()
    }
    
    private func setupView() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:)))
        self.addGestureRecognizer(tapGestureRecognizer)
        
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(recognizer:)))
        self.addGestureRecognizer(pinchGestureRecognizer)
        
        // 确保手势识别器的优先级
        tapGestureRecognizer.require(toFail: pinchGestureRecognizer)
        
        // 添加变焦倍数指示器
        self.addSubview(zoomLabel)
        zoomLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            zoomLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 10),
            zoomLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            zoomLabel.widthAnchor.constraint(equalToConstant: 100),
            zoomLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    @objc private func handleTap(recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: self)
        if let point = self.previewLayer?.captureDevicePointConverted(fromLayerPoint: location) {
            self.session?.focus(at: point)
        }
    }
    
    @objc private func handlePinch(recognizer: UIPinchGestureRecognizer) {
        guard let device = session?.videoInput?.device else { return }
        
        if let lensName = session?.currentLens?.name {
            print("Current lens name: \(lensName)")
            switch lensName {
            case "0.5x":
                self.maxZoomFactor = 2.0
                print("0.5x lens maxZoomFactor set to \(self.maxZoomFactor)")
            case "1x":
                self.maxZoomFactor = 2.96
                print("1x lens maxZoomFactor set to \(self.maxZoomFactor)")
            case "3x":
                self.maxZoomFactor = 15.0
                print("3x lens maxZoomFactor set to \(self.maxZoomFactor)")
            default:
                self.maxZoomFactor = 15.0
                print("Default lens maxZoomFactor set to \(self.maxZoomFactor)")
            }
        } else {
            print("No current lens set")
        }
        
        switch recognizer.state {
        case .began:
            lastScale = currentZoomFactor
        case .changed:
            let scale = recognizer.scale
            let newZoomFactor = min(self.maxZoomFactor, max(1.0, lastScale * scale))
            print("Attempting to set new zoom factor: \(newZoomFactor)")

            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = newZoomFactor
                device.unlockForConfiguration()
                
                currentZoomFactor = newZoomFactor
                DispatchQueue.main.async {
                    self.zoomLabel.text = String(format: "%.1fx", self.currentZoomFactor)
                    print("Pinch gesture changed, new zoom factor: \(self.currentZoomFactor)")
                }
                
                session?.delegate?.didChangeValue(session: session!, value: currentZoomFactor, key: "zoom")
            } catch {
                print("Error setting zoom: \(error.localizedDescription)")
            }
        case .ended:
            if var lens = session?.currentLens {
                lens.lastZoomFactor = currentZoomFactor
                session?.currentLens = lens
            }
        default:
            break
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        self.previewLayer?.frame = self.bounds
        self.gridView?.frame = self.bounds
        
        if self.autorotate {
            self.previewLayer?.connection?.videoOrientation = UIDevice.current.orientation.videoOrientation
        }
    }
}
