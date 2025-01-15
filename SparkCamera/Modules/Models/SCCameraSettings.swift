//
//  SCCameraSettings.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/21.
//



import Foundation
import RealmSwift

class SCCameraSettings: Object {
    // 主键
    @Persisted(primaryKey: true) var id: String = "default"
    
    // Flash 设置
    @Persisted var flashMode: Int = 0  // 0: auto, 1: on, 2: off
    
    // Live Photo 设置
    @Persisted var isLivePhotoEnabled: Bool = false
    
    // Ratio 设置
    @Persisted var ratioMode: Int = 0  // 0: 4:3, 1: 1:1, 2: 16:9
    
    // Exposure 设置
    @Persisted var exposureValue: Float = 0.0
    
    // ISO 设置
    @Persisted var isoValue: Float = 0.0
    
    // White Balance 设置
    @Persisted var whiteBalanceMode: Int = 0  // 0: auto, 1: sunny, 2: cloudy, 3: fluorescent
    
    // Timer 设置
    @Persisted var timerMode: Int = 0  // 0: off, 1: 3s, 2: 10s
    
    // 对焦模式
    @Persisted var focusMode: Int = 1  // 默认为连续对焦模式
    
    // 对焦锁定
    @Persisted var isFocusLocked: Bool = false
    
    // 自动保存照片
    @Persisted var isAutoSaveEnabled: Bool = false
    
    // 上次更新时间
    @Persisted var lastUpdated: Date = Date()
    
    // 便利方法：获取默认设置
    static func defaultSettings() -> SCCameraSettings {
        let settings = SCCameraSettings()
        settings.id = "default"
        settings.flashMode = 0
        settings.isLivePhotoEnabled = false
        settings.ratioMode = 0
        settings.exposureValue = 0.0
        settings.isoValue = 0.0
        settings.whiteBalanceMode = 0
        settings.timerMode = 0
        settings.focusMode = 1  // 连续对焦
        settings.isFocusLocked = false
        settings.isAutoSaveEnabled = false  // 默认关闭自动保存
        settings.lastUpdated = Date()
        return settings
    }
    
    // 更新时间戳
    func updateTimestamp() {
        lastUpdated = Date()
    }
    
    @objc dynamic var shutterSpeedValue: Float = 0.0  // 添加快门速度属性，默认为0.0（自动模式）
    
    override static func primaryKey() -> String? {
        return "id"
    }
} 
