//
//  CreatingQRCodesViewController.swift
//  Smart Reader
//
//  Created by Glenda Ricky on 29.11.24.
//

import UIKit
import RxSwift
import RxCocoa

class CreatingQRCodesViewController: UIViewController {
    
    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var shareQRContentButton: UIButton!
    
    @IBOutlet weak var createdQRImageView: UIImageView!
    
    @IBOutlet weak var downloadCreatedQRButton: UIButton!
    @IBOutlet weak var colorCreatedQRButton: UIButton!
    
    @IBOutlet weak var dataCreatedQRTextView: UITextView!
    
    @IBOutlet weak var colorWellAction: UIColorWell!
    
    var qrCodeData: QRCodeData
    var qrCodeImage: UIImage?
    
    private lazy var qrCodeProcessor: QRDataProcessor = {
        return QRDataProcessor()
    }()
    
    var selectedBackgroundColor: UIColor?
    var selectedForegroundColor: UIColor?
    
    private let disposeBag = DisposeBag()
    private var appeared = false
    private let item: QRDataItem?
    
    var onValueChanged: ((String) -> Void)?
    var onBeginEditing: (() -> Void)?
    
    init?(coder: NSCoder, type: QRCodeData.QRCodeType, data: QRCodeData? = nil, item: QRDataItem? = nil) {
        if let item = item, let qrCodedata = item.qrCodeData {
            self.qrCodeData = qrCodedata
        } else {
            let data = data?.data ?? [:]
            self.qrCodeData = QRCodeData(type: type, data: data, backgroundHexColor: "#FFFFFF", foregroundHexColor: "#000000")
        }
        self.item = item
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupInterface()
        updateQRCode()
        
        enableContentAndButtons(false)
        
        colorWellAction.addTarget(self, action: #selector(colorWellChanged), for: .valueChanged)
    }
    
    private func setupInterface() {
        dismissButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                this.dismiss(animated: true)
            })
            .disposed(by: disposeBag)
        
        shareQRContentButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                this.shareQRCode()
            })
            .disposed(by: disposeBag)
        
        downloadCreatedQRButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                this.saveQRCodeToGallery()
            })
            .disposed(by: disposeBag)
        
        colorCreatedQRButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] in
                EfficiencyGenerator.shared.kickback()
            })
            .disposed(by: disposeBag)
    }
    
    @objc private func colorWellChanged() {
        qrCodeData.foregroundHexColor = colorWellAction.selectedColor?.hexStringFromColor() ?? UIColor.clear.hexStringFromColor()
        updateQRCode()
    }
    
    private func updateQRCodeData(key: String, value: String) {
        qrCodeData.data[key] = value
        updateQRCode()
    }
    
    private func saveQRCodeToGallery() {
        guard let qrImage = qrCodeImage else { return }
        saveToGallery(qrImage: qrImage) { saved, error in
        }
        qrCodeProcessor.save(qrCodeData: qrCodeData)
    }
    
    private func shareQRCode() {
        guard let qrImage = qrCodeImage else { return }
        share(qrImage: qrImage, onViewController: self)
        qrCodeProcessor.save(qrCodeData: qrCodeData)
    }
    
    func updateQRCode(initial: Bool = false) {
        let content = generateContent()
        let backgroundColor: UIColor = {
            if let hex = qrCodeData.backgroundHexColor {
                return UIColor.colorWithHexString(hexString: hex)
            }
            return selectedBackgroundColor ?? .white
        }()
        let foregroundColor: UIColor = {
            if let hex = qrCodeData.foregroundHexColor {
                return UIColor.colorWithHexString(hexString: hex)
            }
            return selectedForegroundColor ?? .black
        }()
        if let qrCodeData = GeneratorOfQRCode.shared.generateQRCode(
            from: content,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor
        ),
           let image = UIImage(data: qrCodeData) {
            qrCodeImage = image
            if !initial {
                createdQRImageView.image = image
            }
        }
    }
    
    private func generateContent() -> String {
        switch qrCodeData.type {
        case .text:
            return qrCodeData.data["text"] ?? ""
        case .wifi:
            let ssid = qrCodeData.data["name"] ?? ""
            let password = qrCodeData.data["password"] ?? ""
            let type = qrCodeData.data["type"] ?? "WPA"
            return "WIFI:T:\(type);S:\(ssid);P:\(password);;"
        case .url:
            return qrCodeData.data["url"] ?? ""
        case .contact:
            let name = qrCodeData.data["name"] ?? ""
            let phone = qrCodeData.data["phone"] ?? ""
            let email = qrCodeData.data["email"] ?? ""
            let url = qrCodeData.data["url"] ?? ""
            return """
            BEGIN:VCARD
            VERSION:3.0
            N:\(name)
            TEL:\(phone)
            EMAIL:\(email)
            URL:\(url)
            END:VCARD
            """
        }
    }
    
    func enableContentAndButtons(_ enable: Bool) {
        downloadCreatedQRButton.isUserInteractionEnabled = enable
        downloadCreatedQRButton.alpha = enable ? 1 : 0.8
    }
}

extension CreatingQRCodesViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        onValueChanged?(textView.text)
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        onBeginEditing?()
        
        dataCreatedQRTextView.textColor = .black
        dataCreatedQRTextView.text = ""
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if dataCreatedQRTextView.text.isEmpty == true || dataCreatedQRTextView.text == "Paste text or link" {
            enableContentAndButtons(false)
        } else {
            enableContentAndButtons(true)
        }
        updateQRCodeData(key: "text", value: textView.text)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n"{
            return textView.resignFirstResponder()
        }
        return true
    }
}
