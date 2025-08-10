import Foundation
import RealmSwift

/// 自定义滤镜管理器
class SCCustomFilterManager {
    static let shared = SCCustomFilterManager()
    private let realm: Realm

    private init() {
        realm = try! Realm() // 复用默认配置（已由 SCCameraSettingsManager 配置）
    }

    func saveFilter(name: String, parameters: [String: Float]) throws -> SCCustomFilter {
        if let existing = realm.objects(SCCustomFilter.self).filter("name == %@", name).first {
            try realm.write {
                existing.apply(parameters: parameters)
                existing.updatedAt = Date()
                realm.add(existing, update: .modified)
            }
            return existing
        } else {
            let filter = SCCustomFilter()
            filter.name = name
            filter.apply(parameters: parameters)
            try realm.write {
                realm.add(filter, update: .modified)
            }
            return filter
        }
    }

    func updateFilter(id: String, name: String?, parameters: [String: Float]?) throws {
        guard let obj = realm.object(ofType: SCCustomFilter.self, forPrimaryKey: id) else { return }
        try realm.write {
            if let name = name { obj.name = name }
            if let parameters = parameters { obj.apply(parameters: parameters) }
            obj.updatedAt = Date()
            realm.add(obj, update: .modified)
        }
    }

    func deleteFilter(id: String) throws {
        guard let obj = realm.object(ofType: SCCustomFilter.self, forPrimaryKey: id) else { return }
        try realm.write {
            realm.delete(obj)
        }
    }

    func allFilters() -> [SCCustomFilter] {
        return Array(realm.objects(SCCustomFilter.self).sorted(byKeyPath: "createdAt", ascending: false))
    }
}


