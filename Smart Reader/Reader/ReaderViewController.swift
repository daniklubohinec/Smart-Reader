//
//  ViewController.swift
//  Smart Reader
//
//  Created by Glenda Ricky on 8.11.24.
//

import UIKit
import Toast
import RxSwift
import RxCocoa
import RxDataSources

class ReaderViewController: UIViewController {
    
    @IBOutlet weak var goToScanControllerButton: UIButton!
    @IBOutlet weak var goToCreateControllerButton: UIButton!
    
    @IBOutlet weak var scannedCodesSegmentButton: UIButton!
    @IBOutlet weak var createdCodesSegmentButton: UIButton!
    
    @IBOutlet weak var tableViewSegmentIndicatorView: UIView!
    
    @IBOutlet weak var scannedCodesBackView: UIView!
    
    @IBOutlet weak var scannedCodesTableView: UITableView!
    
    @IBOutlet weak var fakeSegmentController: UISegmentedControl!
    
    @IBOutlet weak var codesEmptyImageView: UIImageView!
    @IBOutlet weak var codesEmptyTitleText: UILabel!
    @IBOutlet weak var codesEmptySubtitleText: UILabel!
    
    var viewModel: HistoryViewModel!
    let disposeBag = DisposeBag()
    
    var dataSource: RxTableViewSectionedReloadDataSource<ItemsSctionOriginal>!
    
    private var scannedCodesEmptyResult = false
    private var createdCodesEmptyResult = false
    
    private var currentCodesViewSegment = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        currentCodesViewSegment = 0
        fakeSegmentController.selectedSegmentIndex = currentCodesViewSegment
        
        viewModel = HistoryViewModel()
        
        scannedCodesTableView.rx.setDelegate(self)
            .disposed(by: disposeBag)
        
        dataSource = RxTableViewSectionedReloadDataSource<ItemsSctionOriginal>(
            configureCell: { [weak self] (_, tableView, indexPath, item) -> UITableViewCell in
                let scannedCell = tableView.dequeueReusableCell(withIdentifier: "scannedReaderCell", for: indexPath) as! ScannedTableViewCell
                scannedCell.configure(with: item)
                
                
                scannedCell.scannedTitleLabel.text = self?.currentCodesViewSegment == 0 ? item.name : item.qrCodeData?.data["text"]
                
                scannedCell.scannedSettingsButton.rx.tap
                    .asDriver()
                    .drive(onNext: { [weak self] _ in
                        guard let this = self else { return }
                        EfficiencyGenerator.shared.kickback()
                        let alert = UIAlertController(title: nil, message: item.name, preferredStyle: .actionSheet)
                        
                        alert.addAction(UIAlertAction(title: "Copy", style: .default , handler:{ (UIAlertAction)in
                            EfficiencyGenerator.shared.kickback()
                            let toast = Toast.text("Copied")
                            toast.show()
                            UIPasteboard.general.image = UIImage(data: item.qrCodeImageData)
                        }))
                        
                        alert.addAction(UIAlertAction(title: "Share", style: .default , handler:{ (UIAlertAction)in
                            guard let qrImage = UIImage(data: item.qrCodeImageData), let self else {
                                return
                            }
                            EfficiencyGenerator.shared.kickback()
                            share(qrImage: qrImage, onViewController: self)
                        }))
                        
                        alert.addAction(UIAlertAction(title: "Save as Image", style: .default , handler:{ (UIAlertAction)in
                            guard let qrImage = UIImage(data: item.qrCodeImageData) else {
                                return
                            }
                            EfficiencyGenerator.shared.kickback()
                            saveToGallery(qrImage: qrImage)
                        }))
                        
                        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler:{ (UIAlertAction)in
                            EfficiencyGenerator.shared.kickback()
                            if tableView.numberOfRows(inSection: 0) == 1 {
                                this.viewModel.removeAll()
                            } else {
                                this.viewModel.removeItem(item)
                            }
                            let toast = Toast.text("Deleted")
                            toast.show()
                        }))
                        
                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler:{ (UIAlertAction)in
                            EfficiencyGenerator.shared.kickback()
                        }))
                        
                        this.present(alert, animated: true)
                    })
                    .disposed(by: scannedCell.disposeBag)
                return scannedCell
            }
        )
        
        viewModel.currentSections
            .bind(to: scannedCodesTableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
        
        viewModel.historyListRelay
            .asObservable()
            .subscribe(onNext: { [weak self] list in
                guard let this = self else { return }
                this.scannedCodesEmptyResult = list.scanned.entries.isEmpty
                this.createdCodesEmptyResult = list.created.entries.isEmpty
                onMain {
                    if this.fakeSegmentController.selectedSegmentIndex == 0 {
                        this.scannedCodesTableView.isHidden = list.scanned.entries.isEmpty
                        this.codesEmptyImageView.isHidden = !list.scanned.entries.isEmpty
                        this.codesEmptyTitleText.isHidden = !list.scanned.entries.isEmpty
                        this.codesEmptySubtitleText.isHidden = !list.scanned.entries.isEmpty
                    } else {
                        this.scannedCodesTableView.isHidden = list.created.entries.isEmpty
                        this.codesEmptyImageView.isHidden = !list.created.entries.isEmpty
                        this.codesEmptyTitleText.isHidden = !list.created.entries.isEmpty
                        this.codesEmptySubtitleText.isHidden = !list.created.entries.isEmpty
                    }
                }
            })
            .disposed(by: disposeBag)
        
        scannedCodesTableView.rx.itemDeleted
            .subscribe(onNext: { [weak self] indexPath in
                guard let self else { return }
                let item = dataSource[indexPath]
                viewModel.removeItem(item)
            })
            .disposed(by: disposeBag)
        
        ApprovalRequest.checkCameraAndPhotoLibraryAuthorizationStatus { [weak self] status in
            guard let this = self else { return }
            switch status {
            case .denied:
                this.goToSettingsPermissionAlert()
            case .granted:
                break
            }
        }
        
        fakeSegmentController.rx.selectedSegmentIndex
            .bind(to: viewModel.selectedSegmentIndex)
            .disposed(by: disposeBag)
        
        fakeSegmentController.rx.selectedSegmentIndex
            .changed
            .subscribe(onNext: { [weak self] value in
                guard let this = self else { return }
                this.currentCodesViewSegment = value
                if value == 0 {
                    this.scannedCodesTableView.isHidden = this.scannedCodesEmptyResult
                    this.codesEmptyImageView.isHidden = !this.scannedCodesEmptyResult
                    this.codesEmptyTitleText.isHidden = !this.scannedCodesEmptyResult
                    this.codesEmptySubtitleText.isHidden = !this.scannedCodesEmptyResult
                    
                    UIView.animate(withDuration: 0.25) {
                        this.tableViewSegmentIndicatorView.frame.origin.x = this.scannedCodesSegmentButton.frame.origin.x + 4
                        this.scannedCodesSegmentButton.tintColor = .white
                        this.createdCodesSegmentButton.tintColor = .black
                    }
                    
                    this.codesEmptyImageView.image = UIImage(named: "uerioturtert")
                    this.codesEmptyTitleText.text = "No scanned QR codes"
                    this.codesEmptySubtitleText.text = "The scanned QR codes will be stored here."
                    
                } else {
                    this.scannedCodesTableView.isHidden = this.createdCodesEmptyResult
                    this.codesEmptyImageView.isHidden = !this.createdCodesEmptyResult
                    this.codesEmptyTitleText.isHidden = !this.createdCodesEmptyResult
                    this.codesEmptySubtitleText.isHidden = !this.createdCodesEmptyResult
                    
                    UIView.animate(withDuration: 0.25) {
                        this.tableViewSegmentIndicatorView.frame.origin.x = this.createdCodesSegmentButton.frame.origin.x
                        this.scannedCodesSegmentButton.tintColor = .black
                        this.createdCodesSegmentButton.tintColor = .white
                    }
                    
                    this.codesEmptyImageView.image = UIImage(named: "lkxcvxcvxcv")
                    this.codesEmptyTitleText.text = "No QR codes generated"
                    this.codesEmptySubtitleText.text = "The generated QR codes will be stored here."
                }
            })
            .disposed(by: disposeBag)
        
        setupButtons()
    }
    
    func setupButtons() {
        scannedCodesTableView.isHidden = scannedCodesEmptyResult
        
        goToScanControllerButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                ApprovalRequest.checkCameraAndPhotoLibraryAuthorizationStatus { status in
                    switch status {
                    case .granted:
                        let QRSViewController = UIStoryboard(name: "Reader", bundle: .main).instantiateViewController(identifier: "QRSViewController")
                        QRSViewController.modalPresentationStyle = .fullScreen
                        QRSViewController.modalTransitionStyle = .crossDissolve
                        this.present(QRSViewController, animated: true)
                    case .denied:
                        this.goToSettingsPermissionAlert()
                    }
                }
            })
            .disposed(by: disposeBag)
        
        goToCreateControllerButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                ApprovalRequest.checkCameraAndPhotoLibraryAuthorizationStatus { status in
                    switch status {
                    case .granted:
                        if PurchaseService.shared.hasPremium {
                            this.openCreate(for: .text)
                        } else {
                            presentPurchasesScreen(presenting: this)
                        }
                        break
                    case .denied:
                        this.goToSettingsPermissionAlert()
                    }
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func openCreate(for type: QRCodeData.QRCodeType, data: QRCodeData? = nil) {
        let CQRCViewController = UIStoryboard(name: "Reader", bundle: .main).instantiateViewController(identifier: "CreatingQRCodesViewController", creator: { coder -> CreatingQRCodesViewController? in
            CreatingQRCodesViewController(coder: coder, type: type)
        })
        CQRCViewController.modalPresentationStyle = .fullScreen
        CQRCViewController.modalTransitionStyle = .crossDissolve
        present(CQRCViewController, animated: true)
    }
    
    func goToSettingsPermissionAlert() {
        PermissionAlertViewController.presentAlert(
            firstAction: (
                action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }
                },
                title: "Go to Settings"
            )
        )
    }
}
