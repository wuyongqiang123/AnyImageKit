//
//  PhotoManager.swift
//  AnyImageKit
//
//  Created by 刘栋 on 2019/9/16.
//  Copyright © 2019 AnyImageProject.org. All rights reserved.
//

import UIKit
import Photos

struct FetchRecord {
    
    let identifier: String
    var requestIDs: [PHImageRequestID]
}

final class PhotoManager {
    
    static let shared: PhotoManager = PhotoManager()
    
    var config = ImagePickerController.Config()
    
    var isUpToLimit: Bool {
        return selectdAssets.count == config.selectLimit
    }
    
    var useOriginalImage: Bool = false
    
    /// 已选中的资源
    private(set) var selectdAssets: [Asset] = []
    
    /// Running Fetch Requests
    private var fetchRecords = [FetchRecord]()
    
    /// 缓存
    private var cache = NSCache<NSString, UIImage>()
    
    private init() { }
    
    let workQueue = DispatchQueue(label: "org.AnyImageProject.AnyImageKit.PhotoManager")
}

extension PhotoManager {
    
    func clearAll() {
        useOriginalImage = false
        selectdAssets.removeAll()
        cache.removeAllObjects()
    }
}

// MARK: - Fetch Queue

extension PhotoManager {
    
    func enqueueFetch(for identifier: String, requestID: PHImageRequestID) {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            if let index = self.fetchRecords.firstIndex(where: { $0.identifier == identifier }) {
                self.fetchRecords[index].requestIDs.append(requestID)
            } else {
                self.fetchRecords.append(FetchRecord(identifier: identifier, requestIDs: [requestID]))
            }
        }
    }
    
    func dequeueFetch(for identifier: String, requestID: PHImageRequestID?) {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            guard let requestID = requestID else { return }
            if let index = self.fetchRecords.firstIndex(where: { $0.identifier == identifier }) {
                if let idx = self.fetchRecords[index].requestIDs.firstIndex(of: requestID) {
                    self.fetchRecords[index].requestIDs.remove(at: idx)
                }
                if self.fetchRecords[index].requestIDs.isEmpty {
                    self.fetchRecords.remove(at: index)
                }
            }
        }
    }
    
    func cancelFetch(for identifier: String) {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            if let index = self.fetchRecords.firstIndex(where: { $0.identifier == identifier }) {
                let fetchRecord = self.fetchRecords.remove(at: index)
                fetchRecord.requestIDs.forEach { PHImageManager.default().cancelImageRequest($0) }
            }
        }
    }
    
    func cancelAllFetch() {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            for fetchRecord in self.fetchRecords {
                fetchRecord.requestIDs.forEach { PHImageManager.default().cancelImageRequest($0) }
            }
            self.fetchRecords.removeAll()
        }
    }
}

// MARK: - Cache

extension PhotoManager {
    
    func readCache(for identifier: String) -> UIImage? {
        return cache.object(forKey: identifier as NSString)
    }
    
    func writeCache(image: UIImage, for identifier: String) {
        cache.setObject(image, forKey: identifier as NSString)
    }
}

// MARK: - Select

extension PhotoManager {
    
    @discardableResult
    func addSelectedAsset(_ asset: Asset) -> Bool {
        if selectdAssets.contains(asset) { return false }
        if selectdAssets.count == PhotoManager.shared.config.selectLimit { return false }
        selectdAssets.append(asset)
        asset.isSelected = true
        asset.selectedNum = selectdAssets.count
        syncAsset(asset, postNotification: false)
        return true
    }
    
    @discardableResult
    func removeSelectedAsset(_ asset: Asset) -> Bool {
        guard let idx = PhotoManager.shared.selectdAssets.firstIndex(where: { $0 == asset }) else { return false }
        for item in selectdAssets {
            if item.selectedNum > asset.selectedNum {
                item.selectedNum -= 1
            }
        }
        selectdAssets.remove(at: idx)
        asset.isSelected = false
        asset._image = nil
        return true
    }
    
    func removeAllSelectedAsset() {
        selectdAssets.removeAll()
    }
    
    func syncAsset(_ asset: Asset, postNotification: Bool) {
        switch asset.mediaType {
        case .photo, .photoGIF, .photoLive:
            // 勾选图片就开始加载
            if let image = readCache(for: asset.phAsset.localIdentifier) {
                asset._image = image
            } else {
                workQueue.async { [weak self] in
                    guard let self = self else { return }
                    let options = PhotoFetchOptions(sizeMode: .preview)
                    self.requestPhoto(for: asset.phAsset, options: options) { result in
                        switch result {
                        case .success(let response):
                            if !response.isDegraded {
                                asset._image = response.image
                                if postNotification {
                                    NotificationCenter.default.post(name: .didSyncAsset, object: nil)
                                }
                            }
                        case .failure(let error):
                            _print(error)
                            let message = BundleHelper.pickerLocalizedString(key: "Fetch failed, please retry")
                            if postNotification {
                                NotificationCenter.default.post(name: .didSyncAsset, object: message)
                            }
                        }
                    }
                }
            }
        case .video:
            workQueue.async { [weak self] in
                guard let self = self else { return }
                let options = PhotoFetchOptions(sizeMode: .resize(100*UIScreen.main.nativeScale), needCache: false)
                self.requestPhoto(for: asset.phAsset, options: options, completion: { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let response):
                        asset._image = response.image
                    case .failure:
                        break
                    }
                    self.workQueue.async { [weak self] in
                        guard let self = self else { return }
                        self.requestVideo(for: asset.phAsset) { result in
                            switch result {
                            case .success(_):
                                asset.videoDidDownload = true
                                if postNotification {
                                    NotificationCenter.default.post(name: .didSyncAsset, object: nil)
                                }
                            case .failure(let error):
                                _print(error)
                                let message = BundleHelper.pickerLocalizedString(key: "Fetch failed, please retry")
                                if postNotification {                                
                                    NotificationCenter.default.post(name: .didSyncAsset, object: message)
                                }
                            }
                        }
                    }
                })
            }
        }
    }
}

extension Notification.Name {
    
    static let didSyncAsset: Notification.Name = Notification.Name("org.AnyImageProject.AnyImageKit.didSyncAsset")
    
}