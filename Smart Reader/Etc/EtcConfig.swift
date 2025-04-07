//
//  EtcConfig.swift
//  Smart Reader
//
//  Created by Glenda Ricky on 17.11.24.
//

import UIKit
import RxSwift
import RxRelay
import AVFoundation
import Photos
import CoreImage
import Toast

extension UIViewController {
    func requestUrl(_ link: String) {
        guard let url = URL(string: link) else { return }
        UIApplication.shared.open(url)
    }
    
    func rxButtonTapAnimate(_ button: UIButton, _ backView: UIView, _ disposeBag: DisposeBag) {
        button.rx.controlEvent(.touchDown)
            .asDriver(onErrorJustReturn: ())
            .drive(onNext: { _ in
                backView.alpha = 0.75
            })
            .disposed(by: disposeBag)
        
        button.rx.controlEvent([.touchUpInside, .touchUpOutside, .touchDragExit, .touchCancel])
            .asDriver(onErrorJustReturn: ())
            .drive(onNext: { _ in
                backView.alpha = 1
            })
            .disposed(by: disposeBag)
    }
}

protocol KickbackGenerator {
    func kickback()
}

final class EfficiencyGenerator: KickbackGenerator {
    static let shared = EfficiencyGenerator()
    
    // MARK: Internal
    private init() { }
    
    func kickback() {
        feedback.impactOccurred()
    }
    
    // MARK: Fileprivate
    
    fileprivate let feedback = UIImpactFeedbackGenerator(style: .light)
}

final public class InfoTree {
    static let shared = InfoTree(userDefaults: .standard, encoder: JSONEncoder(), decoder: JSONDecoder())
    
    // MARK: - Private properties
    private let queue = DispatchQueue(label: String(describing: InfoTree.self), qos: .utility)
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var subjects: [String: Any] = [:]
    
    private init(userDefaults: UserDefaults, encoder: JSONEncoder, decoder: JSONDecoder) {
        self.userDefaults = userDefaults
        self.encoder = encoder
        self.decoder = decoder
    }
    
    // MARK: - Public methods
    
    /// Returns value in user defaults in case if there is one for current user. Returns nil if not.
    public func stored<T: Codable>(at key: String) -> T? {
        let item: T? = userDefaults.data(forKey: key)
            .flatMap { try? decoder.decode(T.self, from: $0) }
        getSubject(for: key).accept(item)
        return item
    }
    
    /// Store value in user defaults for specific user. Returns the same value (convenience for Signal)
    public func store<T: Codable>(value: T, at key: String) {
        queue.async { [weak self] in
            guard let self else { return }
            if let encoded = try? self.encoder.encode(value) {
                self.userDefaults.set(encoded, forKey: key)
            }
            self.getSubject(for: key).accept(value)
        }
    }
    
    /// Removes any value for specified key at specified scope
    public func remove(at key: String) {
        queue.async { [weak self] in
            self?.userDefaults.set(nil, forKey: key)
        }
    }
    
    /// We need this to ensure the data is written
    public func synchronize() {
        userDefaults.synchronize()
    }
    
    /// Returns an Observable for the specified key
    public func observable<T: Codable>(for key: String) -> Observable<T?> {
        defer { let _: T? = stored(at: key) }
        return getSubject(for: key).asObservable()
    }
    
    // MARK: - Private methods
    
    private func getSubject<T: Codable>(for key: String) -> BehaviorRelay<T?> {
        if let subject = subjects[key] as? BehaviorRelay<T?> {
            return subject
        }
        let subject = BehaviorRelay<T?>(value: nil)
        subjects[key] = subject
        return subject
    }
}

extension InfoTree {
    var introPresented: Bool {
        get {
            let shown: Bool = InfoTree.shared.stored(at: "introPresented") ?? false
            return shown
        }
        set {
            InfoTree.shared.store(value: newValue, at: "introPresented")
        }
    }
}

struct ApprovalRequest {
    enum AuthorizationState {
        case granted
        case denied
    }
    
    private init() { }
    
    static func checkCameraAndPhotoLibraryAuthorizationStatus(completion: @escaping (AuthorizationState) -> Void) {
        var cameraAuthorized = false
        var photoLibraryAuthorized = false
        
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch cameraStatus {
        case .authorized:
            cameraAuthorized = true
            dispatchGroup.leave()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                cameraAuthorized = granted
                dispatchGroup.leave()
            }
        case .denied, .restricted:
            cameraAuthorized = false
            dispatchGroup.leave()
        @unknown default:
            cameraAuthorized = false
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        let photoStatus = PHPhotoLibrary.authorizationStatus()
        switch photoStatus {
        case .authorized, .limited:
            photoLibraryAuthorized = true
            dispatchGroup.leave()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                photoLibraryAuthorized = (status == .authorized || status == .limited)
                dispatchGroup.leave()
            }
        case .denied, .restricted:
            photoLibraryAuthorized = false
            dispatchGroup.leave()
        @unknown default:
            photoLibraryAuthorized = false
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            let state: AuthorizationState = cameraAuthorized && photoLibraryAuthorized ? .granted : .denied
            completion(state)
        }
    }
}

enum WifiType: String, CaseIterable, Codable {
    case wpa = "WPA"
    case wep = "WEP"
    case free = "FREE"
}

struct Field {
    enum FieldType {
        case text
        case networkName
        case networkPassword
        case url
        case contactName
        case contactNumber
        case contactMail
        case contactURL
        
        var configURLKeyboard: Bool {
            switch self {
            case .contactURL, .url:
                return true
            default:
                return false
            }
        }
    }
    let fieldType: FieldType
    let title: String
    let placeholder: String
    let value: String?
    
    var key: String {
        switch fieldType {
        case .text:
            return "Text"
        case .networkName:
            return "WiFi Name"
        case .networkPassword:
            return "Password"
        case .url:
            return "URL"
        case .contactName:
            return "Contact Name"
        case .contactNumber:
            return "Phone Number"
        case .contactMail:
            return "Mail"
        case .contactURL:
            return "URL"
        }
    }
}

struct QRCodeData: Codable, Equatable {
    enum QRCodeType: String, Codable {
        case wifi, url, text, contact
        
        var createTitle: String {
            switch self {
            case .wifi:
                return "Create WiFi"
            case .url:
                return "Create URL"
            case .text:
                return "Create Text"
            case .contact:
                return "Create Contact"
            }
        }
        
        var name: String {
            switch self {
            case .wifi:
                return "WiFi"
            case .url:
                return "URL"
            case .text:
                return "Text"
            case .contact:
                return "Contact"
            }
        }
    }
    
    let type: QRCodeType
    var data: [String: String]
    var backgroundHexColor: String?
    var foregroundHexColor: String?
    var inputFields: [Field] {
        switch type {
        case .wifi:
            return [
                Field(
                    fieldType: .networkName,
                    title: "WiFi Name",
                    placeholder: "Enter network name",
                    value: data["WiFi Name"]
                ),
                Field(
                    fieldType: .networkPassword,
                    title: "Password",
                    placeholder: "Enter password",
                    value: data["Password"]
                )
            ]
        case .url:
            return [
                Field(
                    fieldType: .url,
                    title: "URL",
                    placeholder: "Enter link",
                    value: data["URL"]
                )
            ]
        case .text:
            return [
                Field(
                    fieldType: .text,
                    title: "Text",
                    placeholder: "Enter text",
                    value: data["Text"]
                )
            ]
        case .contact:
            return [
                Field(
                    fieldType: .contactName,
                    title: "Contact Name",
                    placeholder: "Enter contact name",
                    value: data["Contact Name"]
                ),
                Field(
                    fieldType: .contactNumber,
                    title: "Phone Number",
                    placeholder: "Enter phone number",
                    value: data["Phone Number"]
                ),
                Field(
                    fieldType: .contactMail,
                    title: "Mail",
                    placeholder: "Enter contact mail",
                    value: data["Mail"]
                ),
                Field(
                    fieldType: .contactURL,
                    title: "URL",
                    placeholder: "Enter contact URL",
                    value: data["URL"]
                )
            ]
        }
    }
}
struct CreatedQRCodeItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let qrCodeData: QRCodeData
    let date: Date
    
    var name: String {
        switch qrCodeData.type {
        case .wifi:
            return qrCodeData.data["WiFi Name"] ?? qrCodeData.type.rawValue
        case .url:
            return qrCodeData.data["URL"] ?? qrCodeData.type.rawValue
        case .text:
            return qrCodeData.data["Text"] ?? qrCodeData.type.rawValue
        case .contact:
            return qrCodeData.data["Contact Name"] ?? qrCodeData.type.rawValue
        }
    }
    
    var qrCodeImageData: Data {
        return GeneratorOfQRCode.shared.getQRDate(from: qrCodeData)
    }
}

struct QRDataItem: Identifiable, Codable, Equatable {
    enum ItemType: Int, Codable {
        case scanned, created
    }
    
    enum Item: Codable, Equatable {
        case scanned(QRCodeScanningResultsData)
        case created(CreatedQRCodeItem)
        
        var qrCodeImageData: Data {
            switch self {
            case .scanned(let result):
                return GeneratorOfQRCode.shared.generateQRCode(from: result.rawCode, backgroundColor: .white, foregroundColor: .black) ?? Data()
            case .created(let createdQRCodeItem):
                return GeneratorOfQRCode.shared.getQRDate(from: createdQRCodeItem.qrCodeData)
            }
        }
        var name: String {
            switch self {
            case .scanned(let result):
                return result.name
            case .created(let createdQRCodeItem):
                return createdQRCodeItem.name
            }
        }
    }
    var id: UUID = UUID()
    let item: Item
    let date: Date
    var itemType: ItemType {
        switch item {
        case .scanned:
            return .scanned
        case .created:
            return .created
        }
    }
    var scanResult: QRCodeScanningResultsData? {
        switch item {
        case .scanned(let result):
            return result
        case .created:
            return nil
        }
    }
    var qrCodeData: QRCodeData? {
        switch item {
        case .scanned:
            return nil
        case .created(let createdQRCodeItem):
            return createdQRCodeItem.qrCodeData
        }
    }
    var typeName: String {
        switch item {
        case .scanned(let result):
            return result.type.name
        case .created(let createdQRCodeItem):
            return createdQRCodeItem.qrCodeData.type.name
        }
    }
    
    var name: String {
        item.name
    }
    
    var qrCodeImageData: Data {
        return item.qrCodeImageData
    }
}

struct QRDataList {
    static let empty = QRDataList(scanned: .init(entries: []), created: .init(entries: [])
    )
    let scanned: QRDataListModel
    let created: QRDataListModel
    
    var isEmpty: Bool {
        return scanned.entries.isEmpty && created.entries.isEmpty
    }
    
    func updateWithScanned(_ item: QRDataItem) -> QRDataList {
        return QRDataList(scanned: scanned.updateSizing(item), created: created)
    }
    
    func updateWithCreated(_ item: QRDataItem) -> QRDataList {
        return QRDataList(scanned: scanned, created: created.updateSizing(item))
    }
}

struct QRDataListModel: Equatable {
    let entries: [ItemsSctionOriginal]
    
    func updateSizing(_ item: QRDataItem) -> QRDataListModel {
        var updatedEntries = self.entries
        let itemDate = Calendar.current.startOfDay(for: item.date)
        
        //        if
        let index = updatedEntries.firstIndex(where: { $0.date == itemDate }) // {
        updatedEntries[index!] = ItemsSctionOriginal(date: itemDate, items: [item] + updatedEntries[index!].items)
        //        } else {
        //            let newSection = DateSection(date: itemDate, items: [item])
        //            updatedEntries.insert(newSection, at: 0)
        //        }
        
        return Self(entries: updatedEntries)
    }
}
struct ItemsSctionOriginal: Equatable {
    let date: Date
    var items: [QRDataItem]
}

protocol QRDataUpdatableList {
    func updateSizing(_ item: QRDataItem) -> Self
}

struct ScannedQRDataListModel: Equatable, QRDataUpdatableList {
    let entries: [ItemsSctionOriginal]
    
    func updateSizing(_ item: QRDataItem) -> ScannedQRDataListModel {
        var updatedEntries = self.entries
        let itemDate = Calendar.current.startOfDay(for: item.date)
        
        //        if let index = updatedEntries.firstIndex(where: { $0.date == itemDate }) {
        //            updatedEntries[index] = DateSection(date: itemDate, items: [item] + updatedEntries[index].items)
        let index = updatedEntries.firstIndex(where: { $0.date == itemDate }) // {
        updatedEntries[index!] = ItemsSctionOriginal(date: itemDate, items: [item] + updatedEntries[index!].items)
        //        } else {
        //            let newSection = DateSection(date: itemDate, items: [item])
        //            updatedEntries.insert(newSection, at: 0)
        //        }
        
        return Self(entries: updatedEntries)
    }
}

struct CreatedQRDataListModel: Equatable, QRDataUpdatableList {
    let entries: [ItemsSctionOriginal]
    
    func updateSizing(_ item: QRDataItem) -> CreatedQRDataListModel {
        var updatedEntries = self.entries
        let itemDate = Calendar.current.startOfDay(for: item.date)
        
        //    if let index = updatedEntries.firstIndex(where: { $0.date == itemDate }) {
        let index = updatedEntries.firstIndex(where: { $0.date == itemDate })
        updatedEntries[index!] = ItemsSctionOriginal(date: itemDate, items: [item] + updatedEntries[index!].items)
        //        } else {
        //            let newSection = DateSection(date: itemDate, items: [item])
        //            updatedEntries.insert(newSection, at: 0)
        //        }
        
        return Self(entries: updatedEntries)
    }
}

final class GeneratorOfQRCode {
    static let shared = GeneratorOfQRCode()
    private let ciContext = CIContext()
    
    private init() { }
    
    func getQRDate(from qrCodeData: QRCodeData) -> Data {
        let text: String
        
        switch qrCodeData.type {
        case .wifi:
            text = "WIFI:T:\(qrCodeData.data["Type"] ?? "WPA");S:\(qrCodeData.data["WiFi Name"] ?? "");P:\(qrCodeData.data["Password"] ?? "");;"
        case .url:
            text = qrCodeData.data["URL"] ?? ""
        case .text:
            text = qrCodeData.data["Text"] ?? ""
        case .contact:
            let vCardComponents = [
                "BEGIN:VCARD",
                "VERSION:3.0",
                "N:\(qrCodeData.data["Contact Name"] ?? "")",
                "TEL:\(qrCodeData.data["Phone Number"] ?? "")",
                "EMAIL:\(qrCodeData.data["Mail"] ?? "")",
                "URL:\(qrCodeData.data["URL"] ?? "")",
                "END:VCARD"
            ]
            text = vCardComponents.joined(separator: "\n")
        }
        lazy var backgroundColor: UIColor = {
            if let backgroundColorHex = qrCodeData.backgroundHexColor {
                return UIColor.colorWithHexString(hexString: backgroundColorHex)
            }
            return .white
        }()
        lazy var foregroundColor: UIColor = {
            if let foregroundColorHex = qrCodeData.foregroundHexColor {
                return UIColor.colorWithHexString(hexString: foregroundColorHex)
            }
            return .black
        }()
        
        return generateQRCode(from: text, backgroundColor: backgroundColor, foregroundColor: foregroundColor) ?? Data()
    }
    
    func generateQRCode(from string: String, backgroundColor: UIColor, foregroundColor: UIColor, padding: CGFloat = 3) -> Data? {
        guard let data = string.data(using: .utf8) else { return nil }
        
        guard let qrFilter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        
        qrFilter.setValue(data, forKey: "inputMessage")
        qrFilter.setValue("H", forKey: "inputCorrectionLevel")
        
        guard let qrImage = qrFilter.outputImage else { return nil }
        
        let extent = qrImage.extent.insetBy(dx: -padding, dy: -padding)
        
        let backgroundImage = CIImage(color: CIColor(color: backgroundColor))
            .cropped(to: extent)
        
        let coloredQR = qrImage.applyingFilter("CIFalseColor", parameters: [
            "inputColor0": CIColor(color: foregroundColor),
            "inputColor1": CIColor(color: .clear)
        ])
        
        let finalImage = coloredQR.composited(over: backgroundImage)
        
        let scale: CGFloat = 10
        let scaledImage = finalImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        guard let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage).pngData()
    }
}

extension UIColor {
    func hexStringFromColor() -> String? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        if a == 1.0 {
            // If the alpha channel is 1, return the HEX code without the alpha value
            return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        } else {
            // If the alpha channel is not 1, include the alpha value
            return String(format: "#%02X%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
        }
    }
    
    static func colorWithHexString(hexString: String) -> UIColor {
        var cString: String = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }
        
        if cString.count == 6 {
            cString.append("FF") // Add alpha value if not provided
        }
        
        if cString.count != 8 {
            return UIColor.gray // Return gray color if the string is invalid
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        
        return UIColor(
            red: CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0,
            green: CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0,
            blue: CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0,
            alpha: CGFloat(rgbValue & 0x000000FF) / 255.0
        )
    }
}

func saveToGallery(qrImage: UIImage, completion: ((Bool, Error?) -> Void)? = nil) {
    PHPhotoLibrary.requestAuthorization { status in
        if status == .authorized {
            UIImageWriteToSavedPhotosAlbum(qrImage, nil, nil, nil)
            onMain {
                let toast = Toast.text("Saved to Gallery")
                toast.show()
            }
            completion?(true, nil)
        } else {
            onMain {
                let toast = Toast.text("Failed to save")
                toast.show()
            }
            completion?(false, NSError(domain: "", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to save"]))
        }
    }
}

func share(
    qrImage: UIImage,
    onViewController: UIViewController? = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
) {
    let activityViewController = UIActivityViewController(activityItems: [qrImage], applicationActivities: nil)
    activityViewController.excludedActivityTypes = [
        .assignToContact,
        .addToReadingList
    ]
    
    onViewController?.present(activityViewController, animated: true, completion: nil)
}

func openAppSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

extension UIViewController {
    func presentWithFade(_ viewControllerToPresent: UIViewController, duration: TimeInterval = 0.5, completion: (() -> Void)? = nil) {
        viewControllerToPresent.modalPresentationStyle = .overFullScreen
        viewControllerToPresent.view.alpha = 0.0
        
        self.present(viewControllerToPresent, animated: false) {
            UIView.animate(withDuration: duration, animations: {
                viewControllerToPresent.view.alpha = 1.0
            }, completion: { finished in
                completion?()
            })
        }
    }
}

struct QRCodeParsedResult {
    var rawString: String
    var type: QRCodeScanningResultsType
    var parsedData: [String: String]
}

final class ParserQRCodeData {
    private init() { }
    
    static func parseQRCode(_ qrString: String) -> QRCodeParsedResult {
        var resultType: QRCodeScanningResultsType = .unknown
        var parsedData: [String: String] = [:]
        
        // Identify type
        if qrString.starts(with: "http://") || qrString.starts(with: "https://") {
            resultType = .url
            parsedData["URL"] = qrString
        } else if qrString.starts(with: "MATMSG:") {
            resultType = .email
            parsedData = parseEmail(qrString)
        } else if qrString.contains("BEGIN:VCARD") {
            resultType = .contact
            parsedData = parseVCard(qrString)
        } else if qrString.starts(with: "MECARD:") {
            resultType = .contact
            parsedData = parseMeCard(qrString)
        } else if qrString.starts(with: "SMSTO:") {
            resultType = .message
            parsedData = parseMessage(qrString)
        } else if qrString.starts(with: "WIFI:") {
            resultType = .wifi
            parsedData = parseWiFi(qrString)
        } else if qrString.starts(with: "geo:") {
            resultType = .location
            parsedData = parseLocation(qrString)
        } else if qrString.starts(with: "BARCODE:") {
            resultType = .barcode
            parsedData["Text"] = qrString.replacingOccurrences(of: "BARCODE:", with: "")
        } else {
            resultType = .text
            parsedData["Text"] = qrString
        }
        
        return QRCodeParsedResult(rawString: qrString, type: resultType, parsedData: parsedData)
    }
    
    private static func parseEmail(_ qrString: String) -> [String: String] {
        var emailData: [String: String] = [:]
        
        let components = qrString.replacingOccurrences(of: "MATMSG:", with: "").components(separatedBy: ";")
        for component in components {
            var keyValue = component.components(separatedBy: ":")
            if keyValue.count > 2 {
                keyValue[1] += keyValue[2...keyValue.count - 1].joined()
                keyValue = Array(keyValue[0...1])
            }
            if keyValue.count == 2 {
                let key = keyValue[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = keyValue[1].trimmingCharacters(in: .whitespacesAndNewlines)
                switch key {
                case "TO":
                    emailData["Mail"] = value
                case "SUB":
                    emailData["Subject"] = value
                case "BODY":
                    emailData["Message"] = value
                default:
                    break
                }
            }
        }
        
        return emailData
    }
    
    private static func parseVCard(_ qrString: String) -> [String: String] {
        var vCardData: [String: String] = [:]
        
        let lines = qrString.components(separatedBy: "\n")
        for line in lines {
            let keyValue = line.components(separatedBy: ":")
            if keyValue.count == 2 {
                let key = keyValue[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = keyValue[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if key == "FN" || key == "N" {
                    vCardData["Contact Name"] = value
                } else if key == "TEL" || key.contains("TEL") {
                    vCardData["Phone Number"] = value
                } else if key == "EMAIL" || key.contains("EMAIL") {
                    vCardData["Mail"] = value
                } else if key == "URL" {
                    vCardData["URL"] = value
                }
            }
        }
        
        return vCardData
    }
    
    private static func parseMeCard(_ qrString: String) -> [String: String] {
        var meCardData: [String: String] = [:]
        
        let components = qrString.replacingOccurrences(of: "MECARD:", with: "").components(separatedBy: ";")
        for component in components {
            var keyValue = component.components(separatedBy: ":")
            if keyValue.count > 2 {
                keyValue[1] += keyValue[2...keyValue.count - 1].joined()
                keyValue = Array(keyValue[0...1])
            }
            if keyValue.count == 2 {
                let key = keyValue[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = keyValue[1].trimmingCharacters(in: .whitespacesAndNewlines)
                switch key {
                case "N":
                    meCardData["Contact Name"] = value
                case "TEL":
                    meCardData["Phone Number"] = value
                case "EMAIL":
                    meCardData["Mail"] = value
                case "URL":
                    meCardData["URL"] = value
                default:
                    break
                }
            }
        }
        
        return meCardData
    }
    
    private static func parseMessage(_ qrString: String) -> [String: String] {
        var messageData: [String: String] = [:]
        
        let components = qrString.replacingOccurrences(of: "SMSTO:", with: "").components(separatedBy: ":")
        if components.count == 2 {
            messageData["Phone Number"] = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            messageData["Message"] = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return messageData
    }
    
    private static func parseWiFi(_ qrString: String) -> [String: String] {
        var wifiData: [String: String] = [:]
        
        let components = qrString.replacingOccurrences(of: "WIFI:", with: "").components(separatedBy: ";")
        for component in components {
            let keyValue = component.components(separatedBy: ":")
            if keyValue.count == 2 {
                let key = keyValue[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = keyValue[1].trimmingCharacters(in: .whitespacesAndNewlines)
                switch key {
                case "S":
                    wifiData["WiFi Name"] = value
                case "P":
                    wifiData["Password"] = value
                case "T":
                    wifiData["Type"] = value
                default:
                    break
                }
            }
        }
        
        return wifiData
    }
    
    private static func parseLocation(_ qrString: String) -> [String: String] {
        var locationData: [String: String] = [:]
        
        let components = qrString.replacingOccurrences(of: "geo:", with: "").components(separatedBy: ",")
        if components.count == 2 {
            locationData["Location"] = "\(components[0].trimmingCharacters(in: .whitespacesAndNewlines)), \(components[1].trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        
        return locationData
    }
}
