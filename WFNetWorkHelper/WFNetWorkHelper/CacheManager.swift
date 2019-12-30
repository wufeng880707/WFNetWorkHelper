//
//  CacheManager.swift
//  WFNetWorkHelper
//
//  Created by xiantiankeji on 2019/12/30.
//  Copyright © 2019 tomodel. All rights reserved.
//

import Foundation
import Cache

/// 存储结构体
struct CacheModel: Codable {
    var data: Data?
    var dataDict: Dictionary<String, Data>?
    init() { }
}

/// CacheManager 定义和初始化
class CacheManager: NSObject {
    
    static let `default` = CacheManager()
    private var storage: Storage<CacheModel>?
    override init() {
        super.init()
        expiryConfiguration()
    }
    // 存储过期时间
    var expiry: Expiry = .never
    
    func expiryConfiguration(expiry: Expiry = .never) {
        
        self.expiry = expiry
        let diskConfig = DiskConfig(name: "WFCache", expiry: expiry)
        let memoryConfig = MemoryConfig(expiry: expiry)
        do {
            storage = try Storage(diskConfig: diskConfig, memoryConfig: memoryConfig, transformer: TransformerFactory.forCodable(ofType: CacheModel.self))
        } catch {
            
            WFNetLog(error)
        }
    }
}

/// CacheManager的相关方法
extension CacheManager {
    
    /// 清除所有缓存
    /// - Parameter completion: 结果回调
    func removeAllCache(completion: @escaping (_ isSuccess: Bool)->()) {
        storage?.async.removeAll(completion: { result in

            DispatchQueue.main.async {
                switch result {
                case .value: completion(true)
                case .error: completion(false)
                }
            }
        })
    }
    
    /// 根据key值清除缓存
    /// - Parameter cacheKey: 缓存key
    /// - Parameter completion: 结果回调
    func removeObjectCache(_ cacheKey: String, completion: @escaping (_ isSuccess: Bool)->()) {
        storage?.async.removeObject(forKey: cacheKey, completion: { (result) in
            
            DispatchQueue.main.async {
                switch result {
                case .value: completion(true)
                case .error: completion(false)
                }
            }
        })
    }
    
    /// 读取缓存
    /// - Parameter key: 缓存key
    func objectSync(forKey key: String) -> CacheModel? {
        do {
            
            if let isExpire = try storage?.isExpiredObject(forKey: key), isExpire {
                
                removeObjectCache(key) { (_) in }
                return nil
            } else {
                
                return (try storage?.object(forKey: key)) ?? nil
            }
        } catch {
            return nil
        }
    }
    
    /// 异步缓存
    /// - Parameter object: 缓存对象
    /// - Parameter key: 缓存key
    func setObject(_ object: CacheModel, forKey key: String) {
        storage?.async.setObject(object, forKey: key, completion: { (result) in
            switch result {
            case .value(_):
                WFNetLog("缓存成功")
            case .error(let error):
                WFNetLog("缓存失败:\(error)")
            }
        })
    }
}
