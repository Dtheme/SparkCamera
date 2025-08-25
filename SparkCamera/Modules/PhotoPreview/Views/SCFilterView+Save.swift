//
//  SCFilterView+Save.swift
//  SparkCamera
//
//  Created by dzw on 2024/1/22.
//

import UIKit
import Photos
import GPUImage

// MARK: - Private Extension
private extension SCFilterView {
    var internalGPUImageView: GPUImageView! {
        return value(forKey: "gpuImageView") as? GPUImageView
    }
    
    var internalCurrentPicture: GPUImagePicture? {
        return value(forKey: "currentPicture") as? GPUImagePicture
    }
    
    var internalOriginalImage: UIImage? {
        return value(forKey: "originalImage") as? UIImage
    }
}

// MARK: - Save to Album
extension SCFilterView {
    // 保存图片到相册
    func saveToAlbum(completion: @escaping (Bool, Error?) -> Void) {
        // 检查相册权限
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(false, NSError(
                        domain: "com.sparkcamera.filter",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "内部错误"]
                    ))
                }
                return
            }
            
            if status == .authorized {
                // 在主线程中获取滤镜后的图片
                DispatchQueue.main.async {
                    self.getFilteredImage { image in
                        if let image = image {
                            print("[FilterView] 保存使用滤镜后的图像 size=\(image.size)")
                            // 保存到相册
                            PHPhotoLibrary.shared().performChanges({
                                // 创建资源请求
                                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                                
                                // 设置资源创建日期
                                request.creationDate = Date()
                                
                            }, completionHandler: { success, error in
                                DispatchQueue.main.async {
                                    if success {
                                        // 发送保存成功通知
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("PhotoSavedToAlbum"),
                                            object: nil
                                        )
                                        print("[FilterView] 滤镜 JPEG 保存成功 -> 已发出 PhotoSavedToAlbum")
                                    }
                                    completion(success, error)
                                }
                            })
                        } else {
                            DispatchQueue.main.async {
                                completion(false, NSError(
                                    domain: "com.sparkcamera.filter",
                                    code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "无法生成滤镜图片"]
                                ))
                            }
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, NSError(
                        domain: "com.sparkcamera.filter",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "没有相册访问权限"]
                    ))
                }
            }
        }
    }
} 
