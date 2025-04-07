//
//  QRSExtension.swift
//  Smart Reader
//
//  Created by Glenda Ricky on 23.11.24.
//

import UIKit

extension QRSViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let selectedImage = info[.originalImage] as? UIImage {
            guard let code = ciDetectQRGallery(in: selectedImage) else {
                return
            }
            picker.dismiss(animated: true, completion: nil)
            let scanResult = foundQRCodeScanningData(code: code)
            picker.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.showQRScanningResultFromGallery(scanResult)
                }
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}
