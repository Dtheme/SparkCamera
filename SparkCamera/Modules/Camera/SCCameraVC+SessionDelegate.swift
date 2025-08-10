//
//  SCCameraVC+SessionDelegate.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/13.
//

import UIKit
import AVFoundation
import SwiftMessages


// MARK: - SCSessionDelegate
extension SCCameraVC: SCSessionDelegate {

    func didChangeValue(session: SCSession, value: Any, key: String) {
        switch key {
        case "devicePosition":
            if let position = value as? AVCaptureDevice.Position {
                let message = position == .front ? "已切换到前置摄像头" : "已切换到后置摄像头"
                
                DispatchQueue.main.async {
                    // 触觉反馈
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // 显示提示
                    let view = MessageView.viewFromNib(layout: .statusLine)
                    view.configureTheme(.success)
                    view.configureContent(title: "", body: message)
                    SwiftMessages.show(view: view)
                }
            }
            
        case "focusMode":
            if let focusMode = value as? SCFocusMode {
                print("  [Focus] 对焦模式：\(focusMode)")
            }
            
        case "focusState":
            if let focusState = value as? SCFocusState {
                print("  [Focus] 对焦状态：\(focusState)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.handleFocusStateChange(focusState)
                }
            }
            
        case "focusPoint":
            if let point = value as? CGPoint {
                print("  [Focus] 设置对焦点：\(point)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if let previewLayer = self.previewView.previewLayer {
                        let pointInLayer = previewLayer.layerPointConverted(fromCaptureDevicePoint: point)
                        self.showFocusAnimation(at: pointInLayer, state: .focusing)
                    }
                }
            }
            
        case "zoom":
            if let zoomFactor = value as? CGFloat {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // 更新缩放值显示
                    self.zoomLabel.text = String(format: "%.1fx", zoomFactor)
                    
                    // 确保视图可见且重置透明度
                    self.zoomIndicatorView.isHidden = false
                    self.zoomIndicatorView.alpha = 1
                    
                    // 取消之前的延迟隐藏
                    NSObject.cancelPreviousPerformRequests(withTarget: self, 
                                                         selector: #selector(self.hideZoomIndicator), 
                                                         object: nil)
                    
                    // 延迟3秒后隐藏
                    self.perform(#selector(self.hideZoomIndicator), with: nil, afterDelay: 3.0)
                }
            }
            
        case "photo":
            if let photo = value as? UIImage {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // 触觉反馈
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // 显示成功提示
                    let view = MessageView.viewFromNib(layout: .statusLine)
                    view.configureTheme(.success)
                    view.configureContent(title: "", body: "拍照成功")
                    SwiftMessages.show(view: view)
                }
            }
            
        default:
            print("  [Unknown] 未知的值变更: \(value) for key: \(key)")
        }
    }
} 
