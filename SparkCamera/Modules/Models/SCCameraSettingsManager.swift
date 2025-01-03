import Foundation
import RealmSwift

class SCCameraSettingsManager {
    // 单例
    static let shared = SCCameraSettingsManager()
    
    // Realm 实例
    private var realm: Realm
    
    // 当前设置
    private var currentSettings: SCCameraSettings?
    
    private init() {
        // 配置 Realm
        let config = Realm.Configuration(
            fileURL: try! FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("SparkCamera.realm"),
            schemaVersion: 1,
            migrationBlock: { migration, oldSchemaVersion in
                // 处理未来可能的数据库迁移
            }
        )
        
        // 设置默认配置
        Realm.Configuration.defaultConfiguration = config
        
        // 初始化 Realm
        do {
            realm = try Realm()
            print("Realm 文件路径: \(realm.configuration.fileURL?.path ?? "未知")")
        } catch {
            fatalError("Realm 初始化失败: \(error)")
        }
        
        // 加载或创建默认设置
        loadSettings()
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
} 