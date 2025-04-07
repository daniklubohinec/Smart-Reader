//
//  ScannedTableViewCell.swift
//  Smart Reader
//
//  Created by Glenda Ricky on 28.11.24.
//

import UIKit
import RxSwift

class ScannedTableViewCell: UITableViewCell {
    
    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var scannedTitleLabel: UILabel!
    @IBOutlet weak var scannedSubtitleLabel: UILabel!
    @IBOutlet weak var scannedSettingsButton: UIButton!
    
    var disposeBag = DisposeBag()
    var item: QRDataItem?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
    func configure(with item: QRDataItem) {
        self.item = item
        scannedSubtitleLabel.text = "QR Code"
        
        if let image = UIImage(data: item.qrCodeImageData) {
            qrCodeImageView.image = image
        } else {
            qrCodeImageView.image = UIImage(systemName: "qrcode")
        }
    }
    
    override func prepareForReuse() {
        scannedTitleLabel.text = nil
        scannedSubtitleLabel.text = nil
        qrCodeImageView.image = nil
    }
}
