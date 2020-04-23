//
//  YGNetwork.swift
//  YunGuSmartHome
//
//  Created by Pro on 6/9/18.
//  Copyright © 2018年 yungu. All rights reserved.
//

import Foundation
import AFNetworking


//swift 枚举支持任意数据类型
enum YGHTTPMethod {
    case GET
    case POST
    case DELETE
}

class YGNetwork: AFHTTPSessionManager {
    // 静态区（常量去）/常量/闭包
    //第一次访问时执行闭包，并将结果保存在 shared 常量中
    static let shared = YGNetwork()
    let yyCache = "yyCache" //缓存
    var json:String?
    
    //专门负责拼接token 的网络请求方法
    func
        paramsRequest(isLogin:Bool = false, isCookieCheck:Bool = false, method:YGHTTPMethod = .POST, URLString:String, parameters: [String:Any]? = nil, name: String? = nil, data: Data? = nil, url:URL? = nil ,completion:@escaping (_ json: Any?, _ isSuccess:Bool) -> ()) {
        //2.相关设置
        let response =  AFHTTPResponseSerializer()
        response.acceptableContentTypes = ["application/json", "text/json", "text/javascript","text/html","image/jpg","image/png","image/jpeg","application/octet-stream"]
        responseSerializer = response
        if isCookieCheck { //cookie检查
            requestSerializer.setValue(objectForKey(user_cookie) as? String, forHTTPHeaderField: "Cookie")
        }
        //设置缓存策略
        //如果网络是通的就不用缓存，用服务器的，并进行更新缓存，如果网络不通，则用缓存数据
        let status = Reachability.init(hostname:"www.baidu.com")
        if status?.connection == Reachability.Connection.none {
            let cache  = YYCache.init(name: self.yyCache)
            let json = cache?.object(forKey: URLString)
            if json != nil {
                guard let data = json as? Data,
                    let dic = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
                    else { completion(nil,false); return }
                completion(dic, true)
            }else {
                completion(nil, false)
            }
            return
        }
     
        // 3> 判断 name 和 data,上传图片
        if let name = name, let data = data {// 上传文件
            upload(URLString: URLString, parameters: parameters, name: name, data: data, url: url!, completion: completion)
            //            addBody(URLString: url, parameters: parameters, name: name, data: data)
        } else {
            //调起 request 发起真正的网络请求
            request(isLogin:isLogin, isCookieCheck:isCookieCheck, method: method, URLString: URLString, parameters: parameters, completion: completion)
        }
    }
    
    //MARK: - 封装AFN的GET/POST请求
    func request(isLogin:Bool, isCookieCheck:Bool, method:YGHTTPMethod = .POST, URLString:String, parameters: [String:Any]?, completion:@escaping (_ json: Any?, _ isSuccess:Bool) -> ()) {
          let success = { (task:URLSessionDataTask, json:Any?)->() in //成功回调
//            if let data = task.originalRequest?.httpBody,
//                let postString = NSString(data: data , encoding: String.Encoding.utf8.rawValue) as String?
//            {
//                //
//            }
            if isLogin { //登录保存cookie
                let res:HTTPURLResponse = task.response as! HTTPURLResponse
                if let setcookie:String = res.allHeaderFields["Set-Cookie"] as? String {
                    let arr = setcookie.components(separatedBy: "HttpOnly, ")
                    let cookie = arr.last as Any
                    setObject(cookie, key: user_cookie) //保存用户cookie
//                    print("原始请求-\(cookie)")
                }
            }
           
            //请求成功,设置缓存
            let cache  = YYCache.init(name: self.yyCache)
            //            guard let data:Data = json as? Data else { return }
            cache?.setObject((json as! NSCoding), forKey: URLString)
            
            self.successReturn(isTokenCheck:isCookieCheck, json: json, completion: completion)
        }
        let failure = {  (task:URLSessionDataTask?, error:Error)->() in  //失败回调
            if URLString != app_update_url { //更新的url请求失败不必提示
                BaseAlertView.showText(loadErrorMsg, 0.5)
            }
             completion(nil,false)
        }
        
        if method == .GET {
            get(URLString, parameters: parameters, headers: nil, progress: nil,  success: success , failure: failure)
        }else if method == .DELETE {
            delete(URLString, parameters: parameters, headers: nil, success: success, failure: failure)
        }
        else {
            post(URLString, parameters: parameters, headers: nil, progress: nil, success: success, failure: failure)
        }
        
    }
    
    //MARK: - 成功回调
    func successReturn(isTokenCheck:Bool, json:Any?, completion:@escaping (_ json: Any?, _ isSuccess:Bool) -> ()) {
        guard let data = json as? Data,
//            let responseString = NSString(data: data , encoding: String.Encoding.utf8.rawValue) as String?,
            let dic = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
            else { completion(nil,false); return }
        
//           print(responseString);
           completion(dic,true)
    }
    
    
    //MARK: - 封装 AFN 的上传文件方法
    func upload(URLString: String, parameters: [String: Any]?, name: String, data: Data, url:URL, completion: @escaping (_ json: Any?, _ isSuccess: Bool)->()) {
        
        let success = { (task:URLSessionDataTask, json:Any?)->() in //成功回调
//            if let data = task.originalRequest?.httpBody,
//                let postString = NSString(data: data , encoding: String.Encoding.utf8.rawValue) as String?
//            {
//                print("上传原始请求-\(postString)")
//            }
            self.successReturn(isTokenCheck:true, json: json, completion: completion)
        }
        
//        let picName = getFormatDateString("yyyyMMddHHmmss", date: Date())
        post(URLString, parameters: parameters, headers: nil, constructingBodyWith: { (formData) in
//           try! formData.appendPart(withFileURL: url, name: "avatar", fileName: "\(name).jpg", mimeType: "image/jpg")
            
            formData.appendPart(withFileData: data, name: "avatar", fileName: "\(name).jpg", mimeType: "image/jpg") //application/octet-stream
        }, progress: { (progress) in
//            let pro:Progress = progress
            //发出登录成功的通知
//            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "progressNotification"), object: pro)
        }, success: success, failure: { (task, error) in
            BaseAlertView.showText(loadErrorMsg)
            completion(nil,false)
        })
        
        //        post(URLString, parameters: parameters, constructingBodyWith: { (formData) in
        //            formData.appendPart(withFileData: data, name: name, fileName: "xxx.jpg", mimeType: "image/jpg") //application/octet-stream
        //        }, progress: { (progress) in
        //            let pro:Progress = progress
        //            //发出登录成功的通知
        //            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "progressNotification"), object: pro)
        //        }, success: { (task, json) in
        //            self.successReturn(isTokenCheck:true, json: json, completion: completion)
        //        }) { (task, error) in
        //            BaseAlertView.showText(loadErrorMsg)
        //            completion(nil,false)
        //        }
    }
    
    func addBody(URLString: String, parameters: [String: Any]?, name: String, data: Data) {
        let request = AFJSONRequestSerializer().multipartFormRequest(withMethod: "POST", urlString: URLString, parameters: nil, constructingBodyWith: { (formData) in
            formData.appendPart(withFileData: data, name: name, fileName: "xxx.jpg", mimeType: "image/jpg") //application/octet-stream
        }, error: nil)
        let dd = try? JSONSerialization.data(withJSONObject: parameters as Any, options: []) as Data
//        let ss = NSString(data: dd! , encoding: String.Encoding.utf8.rawValue) as String?
        request.httpBody = dd
        //        print(ss ?? "")
        
        //        uploadTask(with: request as URLRequest, from: data, progress: { (progress) in
        //             let pro:Progress = progress
        //            print(pro.completedUnitCount)
        //        }) { (response, datas, error) in
        //            guard let dt = datas as? Data,
        //            let s = NSString(data: dt , encoding: String.Encoding.utf8.rawValue) as String? else {return}
        //            print(s)
        //        }.resume()
        //
        dataTask(with: request as URLRequest, uploadProgress: { (Progress) in
            
        }, downloadProgress: { (Progress) in
            
        }) { (response, object, error) in
            guard let data = object as? Data,
                let responseString = NSString(data: data , encoding: String.Encoding.utf8.rawValue) as String? else {return}
            print(responseString)
        }.resume()
//        dataTask(with: request as URLRequest) { (response, object, error) in
//            guard let data = object as? Data,
//                let responseString = NSString(data: data , encoding: String.Encoding.utf8.rawValue) as String? else {return}
//            print(responseString)
//            }.resume()
    }
    
    
    func updateApp( URLString:String, completion:@escaping (_ json: Any?, _ isSuccess:Bool) -> ()) {
        let success = { (task:URLSessionDataTask, json:Any?)->() in //成功回调
            //            print(json)
            guard let dic = json as? [String: Any] else { completion(nil,false); return }
            completion(dic,false)
        }
        let failure = {  (task:URLSessionDataTask?, error:Error)->() in  //失败回调
            //            BaseAlertView.showText(loadErrorMsg)
            completion(nil,false)
        }
        get(URLString, parameters: nil, headers: nil, progress: nil,  success: success , failure: failure)
    }
    
    func checkNetwork()->Bool {
        var network = false
        AFNetworkReachabilityManager.shared().setReachabilityStatusChange { (status) in
            switch status {
            case .notReachable :
                network = false
            case .unknown:
                network = false
            case .reachableViaWWAN:
                network =  true
            case .reachableViaWiFi:
                network =  true
            }
        }
        AFNetworkReachabilityManager.shared().startMonitoring()
        return network
    }
}
