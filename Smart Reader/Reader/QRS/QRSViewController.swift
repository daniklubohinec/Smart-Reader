//
//  QRSViewController.swift
//  Smart Reader
//
//  Created by Glenda Ricky on 23.11.24.
//

import UIKit
import Photos
import AVFoundation
import RxSwift
import RxCocoa

class QRSViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet weak var dismissControllerButton: UIButton!
    
    @IBOutlet weak var flashlightButtonAction: UIButton!
    @IBOutlet weak var goToGalleryButtonAction: UIButton!
    
    @IBOutlet weak var cameraContentView: UIView!
    
    private var contentCaptureSession: AVCaptureSession!
    private var contentVideoPreviewLayer: AVCaptureVideoPreviewLayer!
    
    private var flashlightTurned = false
    private var isControllerDissappeared = false
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        settingsCameraSession()
        loadingLibraryLastImage()
        setingsButtonsContent()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DispatchQueue.global(qos: .background).async {
            if (self.contentCaptureSession?.isRunning == false) {
                self.contentCaptureSession.startRunning()
            }
        }
        if isControllerDissappeared {
            isControllerDissappeared = false
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if (contentCaptureSession?.isRunning == true) {
            contentCaptureSession.stopRunning()
        }
        isControllerDissappeared = true
    }
    
    private func settingsCameraSession() {
        contentCaptureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if (contentCaptureSession.canAddInput(videoInput)) {
            contentCaptureSession.addInput(videoInput)
        } else {
            failourScanningAlert()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (contentCaptureSession.canAddOutput(metadataOutput)) {
            contentCaptureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr, .ean13]
        } else {
            failourScanningAlert()
            return
        }
        
        contentVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: contentCaptureSession)
        contentVideoPreviewLayer.frame = view.layer.bounds
        contentVideoPreviewLayer.videoGravity = .resizeAspectFill
        cameraContentView.layer.insertSublayer(contentVideoPreviewLayer, at: 0)
        
        DispatchQueue.global(qos: .background).async {
            self.contentCaptureSession.startRunning()
        }
    }
    
    private func setingsButtonsContent() {
        dismissControllerButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                this.dismiss(animated: true)
            })
            .disposed(by: disposeBag)
        
        flashlightButtonAction.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                this.toggleFlash()
            })
            .disposed(by: disposeBag)
        
        goToGalleryButtonAction.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                this.showImagePickerController()
            })
            .disposed(by: disposeBag)
    }
    
    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        flashlightTurned.toggle()
        
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                
                if device.torchMode == .off {
                    device.torchMode = .on
                } else {
                    device.torchMode = .off
                }
                
                device.unlockForConfiguration()
            } catch {
                print("Torch could not be used")
            }
        } else {
            print("Torch is not available")
        }
    }
    
    func showImagePickerController() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .photoLibrary
        present(imagePickerController, animated: true, completion: nil)
    }
    
    func showQRScanningResult(_ result: QRCodeScanningResultsData) {
        if PurchaseService.shared.hasPremium {
            let desiredSize = CGSize(width: result.type == .barcode ? 147 : 147, height: 147)
            let codeImage = generateQRCodeFromScanningData(from: result.rawCode, codeType: result.type, size: desiredSize) ?? UIImage()
            
            let imageViewController = UIStoryboard(name: "Reader", bundle: .main).instantiateViewController(identifier: "UpshotViewController", creator: { coder -> UpshotViewController? in
                UpshotViewController(coder: coder, scanResult: result, image: codeImage)
            })
            imageViewController.modalPresentationStyle = .fullScreen
            imageViewController.modalTransitionStyle = .crossDissolve
            present(imageViewController, animated: true)
        } else {
            presentPurchasesScreen(presenting: self)
        }
    }
    
    func showQRScanningResultFromGallery(_ result: QRCodeScanningResultsData) {
        let desiredSize = CGSize(width: result.type == .barcode ? 147 : 147, height: 147)
        let codeImage = generateQRCodeFromScanningData(from: result.rawCode, codeType: result.type, size: desiredSize) ?? UIImage()
        
        let imageViewController = UIStoryboard(name: "Reader", bundle: .main).instantiateViewController(identifier: "UpshotViewController", creator: { coder -> UpshotViewController? in
            UpshotViewController(coder: coder, scanResult: result, image: codeImage)
        })
        imageViewController.modalPresentationStyle = .fullScreen
        imageViewController.modalTransitionStyle = .crossDissolve
        present(imageViewController, animated: true)
    }
    
    func foundQRCodeScanningData(code: String) -> QRCodeScanningResultsData {
        print(code)
        let parsedInfo = ParserQRCodeData.parseQRCode(code)
        
        return QRCodeScanningResultsData(type: parsedInfo.type, viewMode: .scan, data: parsedInfo.parsedData, rawCode: parsedInfo.rawString, displayOrder: parsedInfo.type.defaultDisplayOrder)
    }
    
    private func generateQRCodeFromScanningData(from string: String, codeType: QRCodeScanningResultsType, size: CGSize) -> UIImage? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        var filterName: String
        
        switch codeType {
        case .barcode:
            filterName = "CICode128BarcodeGenerator"
        case .url, .text, .email, .message, .contact, .wifi, .location, .unknown:
            if let data = GeneratorOfQRCode.shared.generateQRCode(from: string, backgroundColor: .white, foregroundColor: .black, padding: 4) {
                return UIImage(data: data)
            }
            filterName = "CIQRCodeGenerator"
        }
        
        if let filter = CIFilter(name: filterName) {
            filter.setValue(data, forKey: "inputMessage")
            if codeType != .barcode {
                filter.setValue("H", forKey: "inputCorrectionLevel")
            }
            
            if let outputImage = filter.outputImage {
                var extent = outputImage.extent
                let scale: CGFloat
                var transformedImage: CIImage
                
                if codeType == .barcode {
                    // For barcode, make sure the image is exactly the size specified
                    let widthScale = size.width / extent.width
                    let heightScale = size.height / extent.height
                    scale = min(widthScale, heightScale)
                    transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: widthScale, y: heightScale))
                } else {
                    let padding: CGFloat = 3
                    extent = outputImage.extent.insetBy(dx: -padding, dy: -padding)
                    scale = min(size.width / extent.width, size.height / extent.height)
                    
                    transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                }
                
                let context = CIContext()
                if let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }
        return nil
    }
    
    private func failourScanningAlert() {
        let alertController = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
        contentCaptureSession = nil
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        contentCaptureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            
            let scanResult = foundQRCodeScanningData(code: stringValue)
            showQRScanningResult(scanResult)
        } else {
            let alertController = UIAlertController(title: "Something went wrong", message: "Please, try again", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "TryAgain", style: .cancel))
            alertController.addAction(UIAlertAction(title: "Cancel", style: .default))
            present(alertController, animated: true)
        }
    }
    
    private func ciDetectorQRCode(in image: UIImage) -> String? {
        if PurchaseService.shared.hasPremium {
            guard let ciImage = CIImage(image: image) else { return nil }
            
            let context = CIContext()
            let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
            let features = detector?.features(in: ciImage) as? [CIQRCodeFeature]
            
            return features?.first?.messageString
        } else {
            return nil
        }
    }
    
    func ciDetectQRGallery(in image: UIImage) -> String? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let context = CIContext()
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: ciImage) as? [CIQRCodeFeature]
        
        return features?.first?.messageString
    }
    
    private func loadingLibraryLastImage() {
        guard PHPhotoLibrary.authorizationStatus() == .authorized else { return }
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        if let lastAsset = fetchResult.firstObject {
            PHImageManager.default().requestImage(for: lastAsset,
                                                  targetSize: goToGalleryButtonAction.bounds.size,
                                                  contentMode: .default,
                                                  options: nil) { (image, _) in
            }
        }
    }
}
