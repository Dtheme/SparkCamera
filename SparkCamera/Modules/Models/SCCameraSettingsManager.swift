//
//  SCCameraSettingsManager.swift
//  SparkCamera
//
//  Created by dzw on 2024/12/21.
//


import Foundation
import AVFoundation
import RealmSwift

class SCCameraSettingsManager {
    // 单例
    static let shared = SCCameraSettingsManager()
    
    // Realm 实例
    private var realm: Realm
    
    // 当前设置
    private var currentSettings: SCCameraSettings?
    
    // 持有当前的 captureDevice
    private weak var currentDevice: AVCaptureDevice?
    
    // 获取当前 App 版本作为数据库版本
    private static var currentSchemaVersion: UInt64 {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let versionNumber = UInt64(version.replacingOccurrences(of: ".", with: "")) {
            return versionNumber
        }
        return 1
    }
    
    private init() {
        print("  [Settings] 开始初始化设置管理器")
        
        // 获取文档目录
        guard let documentsURL = try? FileManager.default.url(for: .documentDirectory, 
                                                            in: .userDomainMask, 
                                                            appropriateFor: nil, 
                                                            create: true) else {
            fatalError("❌ [Settings] 无法获取文档目录")
        }
        
        let realmURL = documentsURL.appendingPathComponent("SparkCamera.realm")
        print("  [Settings] Realm 文件路径: \(realmURL.path)")
        
        // 配置 Realm
        let config = Realm.Configuration(
            fileURL: realmURL,
            schemaVersion: Self.currentSchemaVersion,
            migrationBlock: { migration, oldSchemaVersion in
                // 数据库迁移逻辑
                if oldSchemaVersion < Self.currentSchemaVersion {
                    migration.enumerateObjects(ofType: SCCameraSettings.className()) { oldObject, newObject in
                        // 检查并设置新增属性的默认值
                        if oldObject != nil && !oldObject!.objectSchema.properties.contains(where: { $0.name == "isAutoSaveEnabled" }) {
                            newObject!["isAutoSaveEnabled"] = false
                        }
                    }
                }
            },
            shouldCompactOnLaunch: { totalBytes, usedBytes in
                // 如果数据库文件大于 100MB 且至少 50% 是可以压缩的
                let oneHundredMB = 100 * 1024 * 1024
                return (totalBytes > oneHundredMB) && (Double(usedBytes) / Double(totalBytes)) < 0.5
            }
        )
        
        print("  [Settings] 当前 App 版本：\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知")")
        print("  [Settings] 当前数据库版本：\(Self.currentSchemaVersion)")
        
        // 设置默认配置
        Realm.Configuration.defaultConfiguration = config
        
        // 初始化 Realm
        do {
            realm = try Realm()
            print("  [Settings] Realm 初始化成功")
        } catch let error as NSError {
            print("⚠️ [Settings] Realm 初始化失败: \(error.localizedDescription)")
            print("⚠️ [Settings] 错误代码: \(error.code)")
            print("⚠️ [Settings] 错误域: \(error.domain)")
            
            // 尝试删除现有的 Realm 文件
            do {
                try FileManager.default.removeItem(at: realmURL)
                print("  [Settings] 已删除旧的 Realm 文件")
                
                // 重新创建 Realm
                realm = try Realm()
                print("  [Settings] Realm 重新创建成功")
            } catch {
                print("❌ [Settings] 无法删除或重新创建 Realm: \(error)")
                // 使用内存数据库作为后备方案
                let memoryConfig = Realm.Configuration(inMemoryIdentifier: "SparkCameraTemp")
                realm = try! Realm(configuration: memoryConfig)
                print("  [Settings] 已切换到内存数据库")
            }
        }
        
        // 加载或创建默认设置
        loadSettings()
        print("  [Settings] 设置管理器初始化完成")
    }
    
    // MARK: - 公共方法
    
    // 加载设置
    func loadSettings() {
        if let settings = realm.object(ofType: SCCameraSettings.self, forPrimaryKey: "default") {
            currentSettings = settings
        } else {
            // 创建并保存默认设置
            let defaultSettings = SCCameraSettings.defaultSettings()
            do {
                try realm.write {
                    realm.add(defaultSettings)
                }
                currentSettings = defaultSettings
            } catch {
                print("保存默认设置失败: \(error)")
            }
        }
    }
    
    // 保存设置
    func saveSettings() {
        guard let settings = currentSettings else { return }
        
        do {
            try realm.write {
                settings.updateTimestamp()
                realm.add(settings, update: .modified)
            }
        } catch {
            print("保存设置失败: \(error)")
        }
    }
    
    // MARK: - 设置访问器
    
    // 自动保存开关
    var isAutoSaveEnabled: Bool {
        get { return currentSettings?.isAutoSaveEnabled ?? false }
        set {
            try? realm.write {
                currentSettings?.isAutoSaveEnabled = newValue
                currentSettings?.updateTimestamp()
            }
        }
    }
    
    // Flash 模式
    var flashMode: Int {
        get { return currentSettings?.flashMode ?? 0 }
        set {
            try? realm.write {
                currentSettings?.flashMode = newValue
                currentSettings?.updateTimestamp()
            }
        }
    }
    
    // Live Photo 开关
    var isLivePhotoEnabled: Bool {
        get { return currentSettings?.isLivePhotoEnabled ?? true }
        set {
            try? realm.write {
                currentSettings?.isLivePhotoEnabled = newValue
                currentSettings?.updateTimestamp()
            }
        }
    }
    
    // 比例模式
    var ratioMode: Int {
        get { return currentSettings?.ratioMode ?? 0 }
        set {
            try? realm.write {
                currentSettings?.ratioMode = newValue
                currentSettings?.updateTimestamp()
            }
        }
    }
    
    // 曝光值
    var exposureValue: Float {
        get { return currentSettings?.exposureValue ?? 0.0 }
        set {
            try? realm.write {
                currentSettings?.exposureValue = newValue
                currentSettings?.updateTimestamp()
            }
        }
    }
    
    // ISO 值
    var isoValue: Float {
        get { return currentSettings?.isoValue ?? 100.0 }
        set {
            try? realm.write {
                currentSettings?.isoValue = newValue
                currentSettings?.updateTimestamp()
            }
        }
    }
    
    // 白平衡模式
    var whiteBalanceMode: Int {
        get { return currentSettings?.whiteBalanceMode ?? 0 }
        set {
            try? realm.write {
                currentSettings?.whiteBalanceMode = newValue
                currentSettings?.updateTimestamp()
            }
        }
    }
    
    // 定时器模式
    var timerMode: Int {
        get { return currentSettings?.timerMode ?? 0 }
        set {
            try? realm.write {
                currentSettings?.timerMode = newValue
                currentSettings?.updateTimestamp()
            }
        }
    }
    
    // 重置所有设置
    func resetToDefaults() {
        let defaultSettings = SCCameraSettings.defaultSettings()
        do {
            try realm.write {
                realm.add(defaultSettings, update: .modified)
            }
            currentSettings = defaultSettings
        } catch {
            print("重置设置失败: \(error)")
        }
    }
    
    // 清除所有数据（用于测试）
    func clearAllData() {
        do {
            try realm.write {
                realm.deleteAll()
            }
            loadSettings()  // 重新加载默认设置
        } catch {
            print("清除数据失败: \(error)")
        }
    }
    
    // MARK: - Device Management
    func setCurrentDevice(_ device: AVCaptureDevice) {
        self.currentDevice = device
        print("  [Settings] 更新当前设备：\(device.localizedName)")
    }
    
    func getCurrentDevice() -> AVCaptureDevice? {
        return currentDevice
    }
    
    // MARK: - Device Parameters
    // 获取曝光值范围
    var exposureRange: (min: Float, max: Float) {
        guard let device = currentDevice else {
            return (-2.0, 2.0) // 默认值
        }
        return (device.minExposureTargetBias, device.maxExposureTargetBias)
    }
    
    // 获取ISO范围
    var isoRange: (min: Float, max: Float) {
        guard let device = currentDevice else {
            return (100, 800) // 默认值
        }
        return (Float(device.activeFormat.minISO), Float(device.activeFormat.maxISO))
    }
    
    // MARK: - Focus Settings
    public var focusMode: SCFocusMode {
        get {
            guard let settings = currentSettings else {
                return .continuous // 默认使用连续对焦
            }
            return SCFocusMode(rawValue: settings.focusMode) ?? .continuous
        }
        set {
            if let settings = currentSettings {
                try? realm.write {
                    settings.focusMode = newValue.rawValue
                    settings.updateTimestamp()
                }
            }
        }
    }
    
    public var isFocusLocked: Bool {
        get {
            guard let settings = currentSettings else { return false }
            return settings.isFocusLocked
        }
        set {
            if let settings = currentSettings {
                try? realm.write {
                    settings.isFocusLocked = newValue
                    settings.updateTimestamp()
                }
            }
        }
    }
    
    // 快门速度值
    public var shutterSpeedValue: Float {
        get {
            guard let settings = currentSettings else { return 0.0 }
            return settings.shutterSpeedValue
        }
        set {
            if let settings = currentSettings {
                try? realm.write {
                    settings.shutterSpeedValue = newValue
                    settings.updateTimestamp()
                }
            }
        }
    }
    
    // 快门速度范围
    var shutterSpeedRange: ClosedRange<Float> {
        return 0.001...1.0
    }
    
    // 获取当前快门速度状态
    var currentShutterSpeedState: SCShutterSpeedState {
        let value = shutterSpeedValue
        if value == 0.0 {
            return .auto
        }
        // 查找最接近的预设值
        return SCShutterSpeedState.allCases.min(by: { abs($0.rawValue - value) < abs($1.rawValue - value) }) ?? .auto
    }
    
    // 获取所有相机设置
    public func getCameraSettings() -> CameraSettings {
        // 如果是第一次使用（没有保存过状态），保存默认的自动模式
        if flashMode == 0 {
            flashMode = SCFlashState.auto.rawValue
        }
        let savedFlashMode = flashMode
        let flashState = SCFlashState(rawValue: savedFlashMode) ?? .auto
        
        // 获取保存的曝光设置，如果没有保存过，默认为0
        let savedExposureValue = exposureValue
        let exposureStates: [SCExposureState] = [.negative2, .negative1, .zero, .positive1, .positive2]
        let exposureState = exposureStates.first { $0.value == savedExposureValue } ?? .zero
        if exposureValue == 0 {
            exposureValue = SCExposureState.zero.value
        }
        
        // 获取比例设置
        let savedRatioMode = ratioMode
        let ratioState = SCRatioState(rawValue: savedRatioMode) ?? .ratio4_3
        if ratioMode == 0 {
            ratioMode = SCRatioState.ratio4_3.rawValue
        }
        
        // 获取定时器设置
        let savedTimerMode = timerMode
        let timerState = SCTimerState(rawValue: savedTimerMode) ?? .off
        if timerMode == 0 {
            timerMode = SCTimerState.off.rawValue
        }
        
        // 获取白平衡设置
        let savedWhiteBalanceMode = whiteBalanceMode
        let whiteBalanceState = SCWhiteBalanceState(rawValue: savedWhiteBalanceMode) ?? .auto
        if whiteBalanceMode == 0 {
            whiteBalanceMode = SCWhiteBalanceState.auto.rawValue
        }
        
        // 获取ISO设置
        let savedISOValue = isoValue
        let isoStates: [SCISOState] = [.auto, .iso100, .iso200, .iso400, .iso800]
        let isoState = isoStates.first { $0.value == savedISOValue } ?? .auto
        if isoValue == 0 {
            isoValue = SCISOState.auto.value
        }
        
        // 获取其他设置
        let isAutoSaveEnabled = self.isAutoSaveEnabled
        let isFocusLocked = self.isFocusLocked
        let focusMode = self.focusMode
        
        return CameraSettings(
            flashState: flashState,
            ratioState: ratioState,
            timerState: timerState,
            whiteBalanceState: whiteBalanceState,
            exposureState: exposureState,
            isoState: isoState,
            isAutoSaveEnabled: isAutoSaveEnabled,
            isFocusLocked: isFocusLocked,
            focusMode: focusMode
        )
    }
    
    // 相机设置结构体
    public struct CameraSettings {
        public let flashState: SCFlashState
        public let ratioState: SCRatioState
        public let timerState: SCTimerState
        public let whiteBalanceState: SCWhiteBalanceState
        public let exposureState: SCExposureState
        public let isoState: SCISOState
        public let isAutoSaveEnabled: Bool
        public let isFocusLocked: Bool
        public let focusMode: SCFocusMode
        
        public var description: String {
            return """
              [Camera Settings]
            - 闪光灯: \(flashState.title)
            - 比例: \(ratioState.title)
            - 定时器: \(timerState.title)
            - 白平衡: \(whiteBalanceState.title)
            - 曝光值: \(exposureState.value)
            - ISO: \(isoState.title)
            - 自动保存: \(isAutoSaveEnabled)
            - 对焦锁定: \(isFocusLocked)
            - 对焦模式: \(focusMode)
            """
        }
    }
} 
