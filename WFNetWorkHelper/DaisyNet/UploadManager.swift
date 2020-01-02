//
//  UploadManager.swift
//  DaisyNet
//
//  Created by xiantiankeji on 2019/12/31.
//  Copyright © 2019 MQZHot. All rights reserved.
//

import Foundation
import Alamofire

class UploadManager {
    
    static let `default` = UploadManager()
    
    fileprivate var uploadTasks = [String: UploadTaskManager]()
    
    func upload(
                _ url: String,
                method: HTTPMethod = .post,
                parameters: Parameters? = nil,
                image: UIImage?,
                encoding: ParameterEncoding = URLEncoding.default,
                headers: HTTPHeaders? = nil,
                fileName: String? = nil) -> UploadTaskManager {
        
        let key = cacheKey(url, parameters, nil)
        let taskManager = UploadTaskManager()
        taskManager.upload(url, parameters: parameters, image: image, method: method, headers: headers)
        self.uploadTasks[key] = taskManager
        
        taskManager.cancelCompletion = {
            
            self.uploadTasks.removeValue(forKey: key)
        }
        return taskManager
    }
    
    /// 暂停下载
    func cancel(_ url: String, parameters: Parameters?, dynamicParams: Parameters? = nil) {
        let key = cacheKey(url, parameters, dynamicParams)
        let task = uploadTasks[key]
        task?.uploadRequest?.cancel()
        NotificationCenter.default.post(name: NSNotification.Name("DaisyUploadCancel"), object: nil)
    }
    
    // Cancel all tasks
    func cancelAll() {
        
        for (key, task) in uploadTasks {
            
            task.uploadRequest?.cancel()
            task.cancelCompletion = {
                
                self.uploadTasks.removeValue(forKey: key)
            }
        }
    }
    
    /// 删除单个下载
    func delete(_ url: String, parameters: Parameters? , dynamicParams: Parameters? = nil, completion: @escaping (Bool)->()) {
        let key = cacheKey(url, parameters, dynamicParams)
        if let task = uploadTasks[key] {
            task.uploadRequest?.cancel()
            task.cancelCompletion = {
                self.uploadTasks.removeValue(forKey: key)
                completion(true)
            }
        }
    }
    
    /// 下载状态
    func uploadStatus(_ url: String, parameters: Parameters?, dynamicParams: Parameters? = nil) -> UploadStatus {
        let key = cacheKey(url, parameters, dynamicParams)
        let task = uploadTasks[key]
        if downloadPercent(url, parameters: parameters) == 1 { return .complete }
        return task?.uploadStatus ?? .suspend
    }
    
    /// 下载进度
    @discardableResult
    func uploadProgress(_ url: String, parameters: Parameters?, dynamicParams: Parameters? = nil, progress: @escaping ((Double)->())) -> UploadTaskManager? {
        let key = cacheKey(url, parameters, dynamicParams)
        
        if let task = uploadTasks[key] {
            
            task.uploadProgress { (pro) in
                
                progress(pro)
            }
            return task
        } else {
            
            progress(0)
            return nil
        }
    }
}

// MARK: - 上传状态
public enum UploadStatus {
    case uploading
    case suspend
    case complete
}

// MARK: - taskManager
public class UploadTaskManager {
    
    fileprivate var uploadRequest: UploadRequest?
    fileprivate var uploadStatus: UploadStatus = .suspend
    fileprivate var cancelCompletion: (()->())?
    fileprivate var cccompletion: (()->())?
    
    init() {

        NotificationCenter.default.addObserver(self, selector: #selector(uploadCancel), name: NSNotification.Name.init("DaisyUploadCancel"), object: nil)
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillResignActive, object: nil, queue: nil) { (_) in
            self.uploadRequest?.cancel()
        }
    }
    
    @objc fileprivate func uploadCancel() {
        self.uploadStatus = .suspend
    }
    
    @discardableResult
    fileprivate func upload (
        _ url: String,
        parameters: Parameters? = nil,
        image: UIImage!,
        method: HTTPMethod = .post,
        headers: HTTPHeaders? = nil
        ) -> UploadTaskManager?
    {
    
        guard let imageData = UIImageJPEGRepresentation(image, 1.0) else {
            
            return nil
        }
        uploadRequest = manager.upload(imageData, to: url, method: method, headers: headers)
        uploadStatus = .uploading
        return self
    }
    
    @discardableResult
    public func uploadProgress(progress: @escaping ((Double) -> Void)) -> UploadTaskManager {
        uploadRequest?.uploadProgress(closure: { (pro) in
            
            progress(pro.fractionCompleted)
        })
        return self
    }
    
    /// 响应
    public func response(completion: @escaping (Alamofire.Result<String>)->()) {
        uploadRequest?.responseData(completionHandler: { (response) in
            switch response.result {
            case .success:
                self.uploadStatus = .complete
//                let str = response.destinationURL?.absoluteString
//                if self.cancelCompletion != nil { self.cancelCompletion!() }
//                completion(Alamofire.Result.success(str!))
            case .failure(let error):
                self.uploadStatus = .suspend
                if self.cancelCompletion != nil { self.cancelCompletion!() }
                completion(Alamofire.Result.failure(error))
            }
        })
    }
    
    lazy var manager: SessionManager = {
        
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders
        return SessionManager(configuration: configuration)
    }()
    
    
    fileprivate func upload (
            _ url: String,
            parameters: Parameters? = nil,
            images: [UIImage],
            encoding: ParameterEncoding = URLEncoding.default,
            headers: HTTPHeaders? = nil,
            fileName: String?
            ) -> UploadTaskManager
        {

            manager.upload(multipartFormData: { multipartFormData in

                if parameters != nil {
                    
                     for (key, value) in parameters! {
                                                
                        let valueStr = "\(value)"
                         //参数的上传
                         multipartFormData.append((valueStr.data(using: String.Encoding.utf8)!), withName: key)
                     }
                }

                for (index, value) in images.enumerated() {

                    let imageData = UIImageJPEGRepresentation(value, 1.0)
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyyMMddHHmmss"
                    let str = formatter.string(from: Date())
                    let fileName = str+"\(index)"+".jpg"

                    // 以文件流格式上传
                    // 批量上传与单张上传，后台语言为java或.net等
                    multipartFormData.append(imageData!, withName: "fileupload", fileName: fileName, mimeType: "image/jpeg")
    //                // 单张上传，后台语言为PHP
    //                multipartFormData.append(imageData!, withName: "fileupload", fileName: fileName, mimeType: "image/jpeg")
    //                // 批量上传，后台语言为PHP。 注意：此处服务器需要知道，前台传入的是一个图片数组
    //                multipartFormData.append(imageData!, withName: "fileupload[\(index)]", fileName: fileName, mimeType: "image/jpeg")
                }
            }, to: url, headers: headers, encodingCompletion: { (encodingResult) in
                
                switch encodingResult {
                    case .success(let upload, _, _):
                        upload.responseJSON { response in
                            print("response = \(response)")
                            let result = response.result
                            if result.isSuccess {
//                                success(response.value)
                            }
                        }
                        // 获取上传进度
                        upload.uploadProgress(queue: DispatchQueue.global(qos: .utility)) { progress in
                            print("图片上传进度: \(progress.fractionCompleted)")
                        }
                    case .failure(let encodingError):
//                        failture(encodingError)
                }
            })
            uploadStatus = .uploading
            return self
        }
}
