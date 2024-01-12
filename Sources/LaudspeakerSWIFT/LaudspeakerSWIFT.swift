// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import UserNotifications
import Foundation
import FirebaseMessaging
import UserNotifications
import CryptoKit
import CommonCrypto
import Starscream
import SocketIO

public typealias PropertyDict = [String: Any]

// for future tracker update
func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    inputData.withUnsafeBytes {
        _ = CC_SHA256($0.baseAddress, CC_LONG(inputData.count), &hash)
    }
    return hash.map { String(format: "%02x", $0) }.joined()
}


public protocol LaudspeakerStorage {
    func getItem(forKey key: String) -> String?
    func setItem(_ item: String, forKey key: String)
}

public class UserDefaultsStorage: LaudspeakerStorage {
    public func getItem(forKey key: String) -> String? {
        return UserDefaults.standard.string(forKey: key)
    }
    
    public func setItem(_ item: String, forKey key: String) {
        UserDefaults.standard.set(item, forKey: key)
    }
}

public class LaudspeakerSWIFT {
    private var storage: LaudspeakerStorage
    private let defaultURLString = "https://laudspeaker.com"
    private let manager: SocketManager
    private var socket: SocketIOClient?
    private var apiKey: String?
    private var isPushAutomated: Bool = false
    public var isConnected: Bool = false
    
    public func getCustomerId() -> String {
        return self.storage.getItem(forKey: "customerId") ?? ""
    }
    
    public init(storage: LaudspeakerStorage? = nil, url: String? = nil, apiKey: String? = nil, isPushAutomated: Bool? = nil) {
        self.storage = storage ?? UserDefaultsStorage()
        self.apiKey = apiKey
        self.isPushAutomated = isPushAutomated ?? false
        
        let urlString = url ?? defaultURLString
        guard let url = URL(string: urlString) else {
            fatalError("Invalid URL")
        }
        
        // Use SocketManager to manage the connection
        manager = SocketManager(socketURL: url, config: [
            .log(true),
            .compress,
        ])
        
        // Initialize the socket using the manager
        socket = manager.defaultSocket
        
        addHandlers()
    }
    
    private func addHandlers() {
        socket?.on(clientEvent: .connect) { [weak self] data, ack in
            print("LaudspeakerSWIFT connected")
            self?.isConnected = true
        }
        
        socket?.on(clientEvent: .disconnect) { [weak self] data, ack in
            print("LaudspeakerSWIFT disconnected")
            self?.isConnected = false
        }
        
        socket?.on(clientEvent: .error) { [weak self] data, ack in
            print("LaudspeakerSWIFT ERROR",data)
            self?.isConnected = false
        }
        
        socket?.on("customerId") { [weak self] data, ack in
            print("LaudspeakerSWIFT Got customerId")
            
            if let customerId = data[0] as? String {
                print(customerId)
                
                self?.storage.setItem(customerId, forKey: "customerId")
                if ((self?.isPushAutomated) == true) {
                    self?.sendFCMToken()
                }
            }
        }
        
        socket?.on("log") {data, ack in
            print("LaudspeakerSWIFT LOG")
            print(data)
        }
    }
    
    public func identify(uniqueProperties: PropertyDict, optionalProperties: PropertyDict? = nil) {
        // Ensure the socket is connected before attempting to write
        guard isConnected else {
            print("Impossible to identify: no connection to API. Try to init connection first")
            return
        }
        
        var messageDict: PropertyDict = ["uniqueProperties": uniqueProperties]
        if let optionalProps = optionalProperties {
            messageDict["optionalProperties"] = optionalProps
        }
        
        socket?.emit("identify", messageDict)
    }
    
    public func sendFCMToken(fcmToken: String? = nil) {
        guard isConnected else {
            print("Impossible to send token: no connection to API. Try to init connection first")
            return
        }
        
        let tokenToSend: String
        
        if let token = fcmToken {
            tokenToSend = token
            
            self.storage.setItem(tokenToSend, forKey: "fcmToken")
            
            let payload: [String: Any] = [
                "type": "iOS",
                "token": tokenToSend
            ]
            
            self.socket?.emit("fcm_token", payload)
        } else {
            DispatchQueue.main.async {
                let center = UNUserNotificationCenter.current()
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error = error {
                        print("Error requesting notifications permissions: \(error)")
                        return
                    }
                    guard granted else {
                        print("Permissions not granted")
                        return
                    }
                    
                    Messaging.messaging().token { [weak self] token, error in
                        if let error = error {
                            print("Error fetching FCM token: \(error)")
                            return
                        }
                        guard let token = token else {
                            print("Token is nil")
                            return
                        }
                        
                        print("FCM token found: \(token)")
                        self?.storage.setItem(token, forKey: "fcmToken")
                        
                        let payload: [String: Any] = [
                            "type": "iOS",
                            "token": token
                        ]
                        
                        self?.socket?.emit("fcm_token", payload)
                    }
                }
            }
            return
        }
    }
    
    
    
    public func connect() {
        print("Try to connect")
        
        let authParams: [String: Any] = [
            "apiKey": self.apiKey ?? "",
            "customerId": self.storage.getItem(forKey: "customerId") ?? "",
            "development": false
        ]
        
        socket?.connect(withPayload: authParams)
    }
    
    public func disconnect() {
        socket?.disconnect()
    }
    
}
