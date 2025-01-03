import Foundation
import RealmSwift

class SCCameraSettings: Object {
    // 主键
    @Persisted(primaryKey: true) var id: String = "default"
    
    // Flash 设置
    @Persisted var flashMode: Int = 0  // 0: auto, 1: on, 2: off
    
    // Live Photo 设置
    @Persisted var isLivePhotoEnabled: Bool = true
    
    // Ratio 设置
    @Persisted var ratioMode: Int = 0  // 0: 4:3, 1: 1:1, 2: 16:9
    
    // Exposure 设置
    @Persisted var exposureValue: Float = 0.0
    
    // ISO 设置
    @Persisted var isoValue: Float = 100.0
    
    // White Balance 设置
    @Persisted var whiteBalanceMode: Int = 0  // 0: auto, 1: sunny, 2: cloudy, 3: fluorescent
    
    // Timer 设置
    @Persisted var timerMode: Int = 0  // 0: off, 1: 3s, 2: 10s
    
    // 上次更新时间
    @Persisted var lastUpdated: Date = Date()
    
    // 便利方法：获取默认设置
    static func defaultSettings() -> SCCameraSettings {
        let settings = SCCameraSettings()
        settings.id = "default"
        settings.flashMode = 0
        settings.isLivePhotoEnabled = true
        settings.ratioMode = 0
        settings.exposureValue = 0.0
        settings.isoValue = 100.0
        settings.whiteBalanceMode = 0
        settings.timerMode = 0
        settings.lastUpdated = Date()
        return settings
    }
    
    // 更新时间戳
    func updateTimestamp() {
        lastUpdated = Date()
    }
} 