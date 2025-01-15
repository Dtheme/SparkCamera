//
//  SCCameraVC+ToolBarDelegate.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/13.
//

import UIKit
import SwiftMessages

// MARK: - SCCameraToolBarDelegate
extension SCCameraVC: SCCameraToolBarDelegate {
    func toolBar(_ toolBar: SCCameraToolBar, didSelect item: SCToolItem, optionType: SCCameraToolOptionsViewType) {
        // 空实现，所有选择逻辑都在 didSelect:for: 方法中处理
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, didExpand item: SCToolItem, optionType: SCCameraToolOptionsViewType) {
        // 打印展开的工具项信息
        print("📸📸 [ToolBar] 展开工具项: \(item.type)")
        print("📸 [ToolBar] 当前状态: \(String(describing: item.state))")
        print("📸 [ToolBar] 是否选中: \(item.isSelected)")
        
        // 根据工具项类型处理特定逻辑
        switch item.type {
        case .ratio:
            // 获取保存的比例设置
            let savedRatioMode = SCCameraSettingsManager.shared.ratioMode
            print("📸 [Ratio] 数据库中保存的比例模式: \(savedRatioMode)")
            if let ratioState = SCRatioState(rawValue: savedRatioMode) {
                item.setState(ratioState)
                item.isSelected = true
                toolBar.updateItem(item)
                print("📸 [Ratio] 选中保存的状态: \(ratioState.title)")
                print("📸 [Ratio] 比例值: \(ratioState.aspectRatio)")
                print("📸 [Ratio] 当前实际比例状态: \(ratioState)")
            }

        case .flash:
            // 获取保存的闪光灯设置
            let savedFlashMode = SCCameraSettingsManager.shared.flashMode
            print("📸 [Flash] 数据库中保存的闪光灯模式: \(savedFlashMode)")
            if let flashState = SCFlashState(rawValue: savedFlashMode) {
                item.setState(flashState)
                item.isSelected = true
                toolBar.updateItem(item)
                print("📸 [Flash] 选中保存的状态: \(flashState.title)")
                print("📸 [Flash] 闪光灯模式: \(flashState.avFlashMode.rawValue)")
                print("📸 [Flash] 当前实际闪光灯状态: \(flashState)")
            }

        case .whiteBalance:
            // 获取保存的白平衡设置
            let savedWhiteBalanceMode = SCCameraSettingsManager.shared.whiteBalanceMode
            print("📸 [WhiteBalance] 数据库中保存的白平衡模式: \(savedWhiteBalanceMode)")
            if let whiteBalanceState = SCWhiteBalanceState(rawValue: savedWhiteBalanceMode) {
                item.setState(whiteBalanceState)
                item.isSelected = true
                toolBar.updateItem(item)
                print("📸 [WhiteBalance] 选中保存的状态: \(whiteBalanceState.title)")
                print("📸 [WhiteBalance] 色温值: \(whiteBalanceState.temperature)")
                print("📸 [WhiteBalance] 当前实际白平衡状态: \(whiteBalanceState)")
            }

        case .exposure:
            // 获取保存的曝光值
            let savedExposureValue = SCCameraSettingsManager.shared.exposureValue
            print("📸 [Exposure] 数据库中保存的曝光值: \(savedExposureValue)")
            let exposureStates: [SCExposureState] = [.negative2, .negative1, .zero, .positive1, .positive2]
            if let exposureState = exposureStates.first(where: { $0.value == savedExposureValue }) {
                item.setState(exposureState)
                item.isSelected = true
                toolBar.updateItem(item)
                print("📸 [Exposure] 选中保存的状态: \(exposureState.title)")
                print("📸 [Exposure] 曝光值: \(exposureState.value)")
                print("📸 [Exposure] 当前实际曝光状态: \(exposureState)")
            }

        case .iso:
            // 获取保存的 ISO 值
            let savedISOValue = SCCameraSettingsManager.shared.isoValue
            print("📸 [ISO] 数据库中保存的 ISO 值: \(savedISOValue)")
            let isoStates: [SCISOState] = [.auto, .iso100, .iso200, .iso400, .iso800]
            if let isoState = isoStates.first(where: { $0.value == savedISOValue }) {
                item.setState(isoState)
                item.isSelected = true
                toolBar.updateItem(item)
                print("📸 [ISO] 选中保存的状态: \(isoState.title)")
                print("📸 [ISO] ISO 值: \(isoState.value)")
                print("📸 [ISO] 当前实际ISO状态: \(isoState)")
            }

        case .timer:
            // 获取保存的定时器设置
            let savedTimerMode = SCCameraSettingsManager.shared.timerMode
            print("📸 [Timer] 数据库中保存的定时器模式: \(savedTimerMode)")
            if let timerState = SCTimerState(rawValue: savedTimerMode) {
                item.setState(timerState)
                item.isSelected = true
                toolBar.updateItem(item)
                print("📸 [Timer] 选中保存的状态: \(timerState.title)")
                print("📸 [Timer] 定时秒数: \(timerState.seconds)")
                print("📸 [Timer] 当前实际定时器状态: \(timerState)")
            }

        case .livePhoto:
            print("📸 [LivePhoto] 功能未实现，使用默认关闭状态")
            let defaultState = SCLivePhotoState.off
            item.setState(defaultState)
            item.isSelected = true
            toolBar.updateItem(item)
            print("📸 [LivePhoto] 使用默认状态: \(defaultState.title)")
            print("📸 [LivePhoto] 当前实际实况照片状态: \(defaultState)")
            
        case .shutterSpeed:
            // 获取保存的快门速度设置
            let savedShutterSpeedValue = SCCameraSettingsManager.shared.shutterSpeedValue
            print("📸 [ShutterSpeed] 数据库中保存的快门速度值: \(savedShutterSpeedValue)")
            let shutterSpeedStates: [SCShutterSpeedState] = [.auto, .speed1_1000, .speed1_500, .speed1_250, .speed1_125, .speed1_60, .speed1_30]
            if let shutterSpeedState = shutterSpeedStates.first(where: { $0.value == savedShutterSpeedValue }) {
                item.setState(shutterSpeedState)
                item.isSelected = true
                toolBar.updateItem(item)
                print("📸 [ShutterSpeed] 选中保存的状态: \(shutterSpeedState.title)")
                print("📸 [ShutterSpeed] 快门速度值: \(shutterSpeedState.value)")
                print("📸 [ShutterSpeed] 当前实际快门速度状态: \(shutterSpeedState)")
            }
        }
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, didCollapse item: SCToolItem, optionType: SCCameraToolOptionsViewType) {
        // 处理工具项收起
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut], animations: {
            // 显示拍照按钮和其他控制按钮
            self.captureButton.transform = .identity
            self.switchCameraButton.transform = .identity
            self.livePhotoButton.transform = .identity
            
            self.captureButton.alpha = 1
            self.switchCameraButton.alpha = 1
            self.livePhotoButton.alpha = 1
        })
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, willAnimate item: SCToolItem, optionType: SCCameraToolOptionsViewType) {
        // 处理工具项动画开始
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, didFinishAnimate item: SCToolItem, optionType: SCCameraToolOptionsViewType) {
        print("工具栏动画完成：\(item.type)")
        
        // 根据工具类型和选项类型处理不同的逻辑
        switch (item.type, optionType) {
        case (.exposure, .scale):
            // 从 scale 选项类型获取曝光值
            if let value = item.getValue(for: SCCameraToolOptionsViewType.scale) as? Float {
                print("📸 [Exposure] 工具栏收起，应用曝光值：\(value)")
                // 更新相机曝光
                if photoSession.setExposure(value) {
                    // 保存到数据库
                    SCCameraSettingsManager.shared.exposureValue = value
                    // 显示状态更新提示
                    let view = MessageView.viewFromNib(layout: .statusLine)
                    view.configureTheme(.success)
                    view.configureContent(title: "", body: "曝光：\(value)")
                    SwiftMessages.show(view: view)
                    // 添加触觉反馈
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        case (.timer, .normal):
            // 从 normal 选项类型获取定时器状态
            if let timerState = item.getValue(for: SCCameraToolOptionsViewType.normal) as? SCTimerState {
                print("📸 [Timer] 工具栏收起，定时器状态：\(timerState.seconds)秒")
            }
        default:
            break
        }
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, didSelect option: String, for item: SCToolItem, optionType: SCCameraToolOptionsViewType) {
        if item.type == .flash {
            if let flashState = item.state as? SCFlashState {
                print("📸 [Flash] 选择闪光灯状态：\(flashState.title)")
                // 更新闪光灯状态
                if photoSession.setFlashMode(flashState.avFlashMode) {
                    // 保存到数据库
                    SCCameraSettingsManager.shared.flashMode = flashState.rawValue
                    // 显示状态更新提示
                    showFlashModeChanged(flashState)
                    // 添加触觉反馈
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        } else if item.type == .ratio {
            if let ratioState = item.state as? SCRatioState {
                print("📸 [Ratio] 选择比例状态：\(ratioState.title)")
                // 使用新的updateAspectRatio方法更新预览和session
                updateAspectRatio(ratioState)
                // 保存到数据库
                SCCameraSettingsManager.shared.ratioMode = ratioState.rawValue
                // 显示状态更新提示
                showRatioModeChanged(ratioState)
                // 添加触觉反馈
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        } else if item.type == .timer {
            if let timerState = item.state as? SCTimerState {
                print("📸 [Timer] 选择定时器状态：\(timerState.seconds)秒")
                // 保存到数据库
                SCCameraSettingsManager.shared.timerMode = timerState.rawValue
                // 显示状态更新提示
                let view = MessageView.viewFromNib(layout: .statusLine)
                view.configureTheme(.success)
                view.configureContent(title: "", body: timerState == .off ? "定时器已关闭" : "定时器：\(timerState.seconds)秒")
                SwiftMessages.show(view: view)
                // 添加触觉反馈
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        } else if item.type == .whiteBalance {
            if let whiteBalanceState = item.state as? SCWhiteBalanceState {
                print("📸 [WhiteBalance] 选择白平衡状态：\(whiteBalanceState.title)")
                // 更新相机白平衡
                if photoSession.setWhiteBalanceMode(whiteBalanceState) {
                    // 保存到数据库
                    SCCameraSettingsManager.shared.whiteBalanceMode = whiteBalanceState.rawValue
                    // 显示状态更新提示
                    let view = MessageView.viewFromNib(layout: .statusLine)
                    view.configureTheme(.success)
                    view.configureContent(title: "", body: "白平衡：\(whiteBalanceState.title)")
                    SwiftMessages.show(view: view)
                    // 添加触觉反馈
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        } else if item.type == .exposure {
            if let exposureState = item.state as? SCExposureState {
                print("📸 [Exposure] 选择曝光状态：\(exposureState.title)")
                // 更新相机曝光
                if photoSession.setExposure(exposureState.value) {
                    // 保存到数据库
                    SCCameraSettingsManager.shared.exposureValue = exposureState.value
                    // 显示状态更新提示
                    let view = MessageView.viewFromNib(layout: .statusLine)
                    view.configureTheme(.success)
                    view.configureContent(title: "", body: "曝光：\(exposureState.title)")
                    SwiftMessages.show(view: view)
                    // 添加触觉反馈
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        } else if item.type == .iso {
            if let isoState = item.state as? SCISOState {
                print("📸 [ISO] 选择ISO状态：\(isoState.title)")
                // 更新相机ISO
                if photoSession.setISO(isoState.value) {
                    // 保存到数据库
                    SCCameraSettingsManager.shared.isoValue = isoState.value
                    // 显示状态更新提示
                    let view = MessageView.viewFromNib(layout: .statusLine)
                    view.configureTheme(.success)
                    view.configureContent(title: "", body: "ISO：\(isoState.title)")
                    SwiftMessages.show(view: view)
                    // 添加触觉反馈
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        } else if item.type == .shutterSpeed {
            if let shutterSpeedState = item.state as? SCShutterSpeedState {
                print("📸 [ShutterSpeed] 选择快门速度状态：\(shutterSpeedState.title)")
                // 更新相机快门速度
                photoSession.setShutterSpeed(shutterSpeedState.value) { success in
                    if success {
                        // 保存到数据库
                        SCCameraSettingsManager.shared.shutterSpeedValue = shutterSpeedState.value
                        
                        // 显示状态更新提示
                        DispatchQueue.main.async {
                            let view = MessageView.viewFromNib(layout: .statusLine)
                            view.configureTheme(.success)
                            view.configureContent(title: "", body: shutterSpeedState == .auto ? "自动快门速度" : "快门速度：1/\(Int(1/shutterSpeedState.value))秒")
                            SwiftMessages.show(view: view)
                            
                            // 添加触觉反馈
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    } else {
                        // 设置失败时显示错误提示
                        DispatchQueue.main.async {
                            SwiftMessages.showErrorMessage("设置快门速度失败")
                        }
                    }
                }
            }
        }
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, didToggleState item: SCToolItem, optionType: SCCameraToolOptionsViewType) {
        // 处理状态切换
        switch item.type {
        case .flash:
            if let flashState = item.state as? SCFlashState {
                if photoSession.setFlashMode(flashState.avFlashMode) {
                    // 保存闪光灯状态
                    SCCameraSettingsManager.shared.flashMode = flashState.rawValue
                    // 添加触觉反馈
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    // 显示状态更新提示
                    showFlashModeChanged(flashState)
                }
            }
        case .livePhoto:
            // 实况照片功能待实现
            SwiftMessages.showInfoMessage("实况照片功能待开发")
        case .ratio, .whiteBalance, .exposure, .iso, .timer:
            break
        case .shutterSpeed:
            if let shutterSpeedState = item.state as? SCShutterSpeedState {
                let nextState = shutterSpeedState.nextState()
                // 更新工具项状态
                item.setState(nextState)
                toolBar.updateItem(item)
                
                // 设置快门速度
                photoSession.setShutterSpeed(nextState.value) { success in
                    if success {
                        // 保存快门速度状态
                        SCCameraSettingsManager.shared.shutterSpeedValue = nextState.value
                        
                        // 添加触觉反馈
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        // 显示状态更新提示
                        let message = nextState.value == 0 ? "自动快门速度" : "快门速度: 1/\(Int(1/nextState.value))秒"
                        DispatchQueue.main.async {
                            SwiftMessages.showSuccessMessage(message)
                        }
                    } else {
                        // 设置失败时显示错误提示
                        DispatchQueue.main.async {
                            SwiftMessages.showErrorMessage("设置快门速度失败")
                        }
                    }
                }
            }
        }
    }
    
    func toolBar(_ toolBar: SCCameraToolBar, didChangeSlider value: Float, for item: SCToolItem, optionType: SCCameraToolOptionsViewType) {
        // 目前只处理曝光值的调整
        if item.type == .exposure {
            // 获取设备支持的曝光值范围
            let range = SCCameraSettingsManager.shared.exposureRange
            // 确保值在设备支持的范围内
            let clampedValue = min(range.max, max(range.min, value))
            
            print("📸 [Exposure] 准备更新曝光值：\(value)")
            print("📸 [Exposure] 设备支持范围：[\(range.min), \(range.max)]")
            print("📸 [Exposure] 调整后的值：\(clampedValue)")
            
            if photoSession.setExposure(clampedValue) {
                print("📸 [Exposure] 成功更新曝光值：\(clampedValue)")
                // 保存到数据库
                SCCameraSettingsManager.shared.exposureValue = clampedValue
            }
        }
    }
} 