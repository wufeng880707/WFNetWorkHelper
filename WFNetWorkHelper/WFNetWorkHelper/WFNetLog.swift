//
//  WFNetLog.swift
//  WFNetWorkHelper
//
//  Created by xiantiankeji on 2019/12/30.
//  Copyright © 2019 tomodel. All rights reserved.
//

import Foundation

// MARK: - log日志
func WFNetLog<T>( _ message: T, file: String = #file, method: String = #function, line: Int = #line){
    #if DEBUG
        print("\((file as NSString).lastPathComponent)[\(line)], \(method): \(message)")
    #endif
}
