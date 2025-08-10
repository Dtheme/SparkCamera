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
    
    private let sessionQueue = DispatchQueue(label: "com.sparkcamera.session")
    
    @objc public var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                oldValue?.removeFromSuperlayer()
                
                if let previewLayer = self.previewLayer {
                    previewLayer.videoGravity = .resizeAspectFill
                    self.layer.insertSublayer(previewLayer, at: 0)
                    previewLayer.frame = self.bounds
                }
            }
        }
    }
    
    @objc public var session: SCSession? {
        didSet {
            sessionQueue.async { [weak self] in
                guard let self = self else { return }
                oldValue?.stop()
                
                if let session = session {
                    DispatchQueue.main.async {
                        if self.previewLayer == nil {
                            let newLayer = AVCaptureVideoPreviewLayer()
                            newLayer.session = session.session
                            self.previewLayer = newLayer
                        } else {
                            self.previewLayer?.session = session.session
                        }
                        
                        session.previewLayer = self.previewLayer
                        session.overlayView = self
                    }
                    
                    self.updateMaxZoomFactor(for: session.currentLens?.name)
                    
                    // 确保在主线程启动会话
                    DispatchQueue.main.async {
                        session.start()
                    }
                }
            }
        }
    }
    
    @objc private(set) public var gridView: SCGridView? {
        didSet {
            oldValue?.removeFromSuperview()
            
            if let gridView = self.gridView {
                self.addSubview(gridView)
                gridView.frame = bounds
            }
        }
    }
    
    @objc public var showGrid: Bool = false {
        didSet {
            if self.showGrid == oldValue {
                return
            }
            
            if self.showGrid {
                self.gridView = SCGridView(frame: bounds)
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
    
    internal let focusBox = SCFocusBoxView()
    
    // MARK: - Initialization
    @objc public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    @objc public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        self.addSubview(focusBox)
        self.bringSubviewToFront(focusBox)
    }
    
    // MARK: - Layout
    @objc public override func layoutSubviews() {
        super.layoutSubviews()
        
        let currentBounds = bounds
        
        // 更新 previewLayer
        if previewLayer?.frame != currentBounds {
            previewLayer?.frame = currentBounds
            
            // 只在调试模式下打印一次布局信息
            #if DEBUG
            if ProcessInfo.processInfo.environment["LAYOUT_DEBUG"] != nil {
                print("Preview layer setup completed: \(String(describing: currentBounds))")
                print("Preview view setup completed: \(frame)")
            }
            #endif
        }
        
        // 更新 gridView
        if let gridView = gridView, gridView.frame != currentBounds {
            gridView.frame = currentBounds
        }
        
        // 确保 focusBox 始终在最上层
        bringSubviewToFront(focusBox)
    }
    
    // MARK: - Private Methods
    private func updateMaxZoomFactor(for lensName: String?) {
        guard let lensName = lensName else { return }
        
        switch lensName {
        case "0.5x":
            self.maxZoomFactor = 2.0
        case "1x":
            self.maxZoomFactor = 2.96
        case "3x":
            self.maxZoomFactor = 15.0
        default:
            self.maxZoomFactor = 2.96
        }
        
        #if DEBUG
        print("  [Zoom] \(lensName) lens maxZoomFactor set to \(self.maxZoomFactor)")
        #endif
    }
    
    // MARK: - Public Methods
    public func setSession(_ session: AVCaptureSession) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let newPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
                self.previewLayer = newPreviewLayer
            }
        }
    }
}

