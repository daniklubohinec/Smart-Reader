//
//  UpshotExtension.swift
//  Smart Reader
//
//  Created by Glenda Ricky on 28.11.24.
//

import Foundation

enum QRCodeScanningResultsType: Codable, Equatable {
    case barcode, text, url, email, message, contact, wifi, location, unknown
    
    var defaultDisplayOrder: [String] {
        switch self {
        case .url:
            return ["URL"]
        case .email:
            return ["Mail", "Subject", "Message"]
        case .message:
            return ["Phone Number", "Message"]
        case .contact:
            return ["Contact Name", "Phone Number", "Mail", "URL"]
        case .wifi:
            return ["WiFi Name", "Password", "Type"]
        case .location:
            return ["Location"]
        case .barcode, .text, .unknown:
            return ["Text"]
        }
    }
    
    var qrCodeType: QRCodeData.QRCodeType? {
        switch self {
        case .text:
            return .text
        case .url:
            return .url
        case .contact:
            return .contact
        case .wifi:
            return .wifi
        default: return nil
        }
    }
    
    var name: String {
        switch self {
        case .barcode:
            return "Barcode"
        case .text:
            return "Text"
        case .url:
            return "URL"
        case .email:
            return "Email"
        case .message:
            return "Message"
        case .contact:
            return "Contact"
        case .wifi:
            return "WiFi"
        case .location:
            return "Location"
        case .unknown:
            return "Unknown"
        }
    }
}

struct QRCodeScanningResultsData: Codable, Equatable {
    enum ViewMode: Codable {
        case view
        case scan
    }
    let type: QRCodeScanningResultsType
    let viewMode: ViewMode
    let data: [String: String]
    let rawCode: String
    let displayOrder: [String]
    
    var name: String {
        switch type {
        case .barcode, .text:
            return data["Text"] ?? rawCode
        case .url:
            return data["URL"] ?? rawCode
        case .email:
            return data["Mail"] ?? rawCode
        case .message:
            return data["Message"] ?? rawCode
        case .contact:
            return data["Contact Name"] ?? rawCode
        case .wifi:
            return rawCode
        case .location:
            return rawCode
        case .unknown:
            return rawCode
        }
    }
    
    func withUpdatedViewMode(_ value: ViewMode) -> Self {
        return Self(type: type, viewMode: value, data: data, rawCode: rawCode, displayOrder: displayOrder)
    }
}
