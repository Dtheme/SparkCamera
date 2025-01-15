//
//  SCCameraVC+ToolOptionsDelegate.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/13.
//

import UIKit
import SwiftMessages
import AVFoundation

// MARK: - SCCameraToolOptionsViewDelegate
extension SCCameraVC: SCCameraToolOptionsViewDelegate {
    func optionsView(_ optionsView: SCCameraToolOptionsView, didChangeSliderValue value: Float, for type: SCToolType) {
        // 处理选项选择
        if let item = toolBar.getItem(for: type) {
            item.setValue(value, for: .scale)
            toolBar.delegate?.toolBar(toolBar, didChangeSlider: value, for: item, optionType: .scale)
        }
    }
    
    func optionsView(_ optionsView: SCCameraToolOptionsView, didSelect option: SCToolOption, for type: SCToolType) {
        // 处理选项选择
        if let item = toolBar.getItem(for: type) {
            item.setState(option.state)
            toolBar.updateItem(item)
            toolBar.delegate?.toolBar(toolBar, didSelect: option.title, for: item, optionType: .normal)
        }
    }
} 