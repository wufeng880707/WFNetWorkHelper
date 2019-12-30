//
//  CacheKey.swift
//  WFNetWorkHelper
//
//  Created by xiantiankeji on 2019/12/30.
//  Copyright © 2019 tomodel. All rights reserved.
//

import Foundation
import Cache

/// 将参数字典转换成字符串后md5
func cacheKey(_ url: String, _ params: Dictionary<String, Any>?, _ dynamicParams: Dictionary<String, Any>?) -> String {
    
    if let filterParams = params?.filter({ (key , _) -> Bool in
        
        return dynamicParams?.contains(where: { (key1, _) -> Bool in
            
            return key != key1
        }) ?? false
    }) {
        
        let str = "\(url)" + "\(sort(filterParams))"
        return MD5(str)
    } else {
        
        return MD5(url)
    }
}

/// 参数排序生成字符串
func sort(_ parameters: Dictionary<String, Any>?) -> String {
    
    var sortParams = ""
    if let params = parameters {
        let sortArr = params.keys.sorted { return $0 < $1 }
        sortArr.forEach({ (str) in
            if let value = params[str] {
                sortParams = sortParams.appending("\(str)=\(value)")
            } else {
                sortParams = sortParams.appending("\(str)=")
            }
        })
    }
    return sortParams
}
