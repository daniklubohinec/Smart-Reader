//
//  UpshotViewController.swift
//  Smart Reader
//
//  Created by Glenda Ricky on 23.11.24.
//

import UIKit
import RxSwift
import RxRelay
import RxCocoa
import Toast

class UpshotViewController: UIViewController {
    
    @IBOutlet weak var controllerTitleLabel: UILabel!
    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    
    @IBOutlet weak var upshotImageView: UIImageView!
    
    @IBOutlet weak var openInSafariButton: UIButton!
    @IBOutlet weak var downloadButton: UIButton!
    
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var copyTextButton: UIButton!
    
    private enum Section: Int, CaseIterable {
        case image, data
    }
    
    private let scanResult: QRCodeScanningResultsData
    private let qrCodeImage: UIImage
    private lazy var qrProcessor: QRDataProcessor = {
        return QRDataProcessor()
    }()
    let disposeBag = DisposeBag()
    
    init?(coder: NSCoder, scanResult: QRCodeScanningResultsData, image: UIImage) {
        self.scanResult = scanResult
        self.qrCodeImage = image
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        fatalError("`init(coder:image:)` ended with error.")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupInterface()
    }
    
    private func setupInterface() {
        upshotImageView.image = qrCodeImage
        contentLabel.text = scanResult.name
        
        controllerTitleLabel.text = scanResult.type == .barcode ? "EAN-13" : "QR Code"
        
        dismissButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                this.dismiss(animated: true)
            })
            .disposed(by: disposeBag)
        
        shareButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                share(qrImage: this.qrCodeImage, onViewController: self)
            })
            .disposed(by: disposeBag)
        
        openInSafariButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                this.requestUrl("\(this.scanResult.name)")
            })
            .disposed(by: disposeBag)
        
        downloadButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                saveToGallery(qrImage: this.qrCodeImage)
            })
            .disposed(by: disposeBag)
        
        copyTextButton.rx.tap
            .asDriver()
            .drive(onNext: { [weak self] in
                guard let this = self else { return }
                EfficiencyGenerator.shared.kickback()
                UIPasteboard.general.string = this.scanResult.name
                let toast = Toast.text("Copied")
                toast.show()
            })
            .disposed(by: disposeBag)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if scanResult.viewMode == .scan {
            qrProcessor.saveScanResult(result: scanResult)
        }
    }
}

enum StorageKey: String {
    case historyList
}

final class QRDataProcessor {
    private let queue = DispatchQueue(label: String(describing: QRDataProcessor.self))
    private var savedData: QRCodeData?
    
    init() { }
    
    func saveScanResult(result: QRCodeScanningResultsData) {
        let item = QRDataItem(item: .scanned(result), date: Date())
        
        queue.async {
            var currentItems: [QRDataItem] = InfoTree.shared.stored(at: StorageKey.historyList.rawValue) ?? []
            currentItems.append(item)
            InfoTree.shared.store(value: currentItems, at: StorageKey.historyList.rawValue)
        }
    }
    
    func save(qrCodeData: QRCodeData) {
        if let savedData = savedData, savedData == qrCodeData {
            return
        }
        let item = QRDataItem(item: .created(CreatedQRCodeItem(qrCodeData: qrCodeData, date: Date())), date: Date())
        
        queue.async { [weak self] in
            var currentItems: [QRDataItem] = InfoTree.shared.stored(at: StorageKey.historyList.rawValue) ?? []
            currentItems.append(item)
            InfoTree.shared.store(value: currentItems, at: StorageKey.historyList.rawValue)
            self?.savedData = qrCodeData
        }
    }
    
    func saveChanges(item: QRDataItem, modifiedData: QRCodeData) {
        let item = QRDataItem(id: item.id, item: .created(.init(qrCodeData: modifiedData, date: item.date)), date: Date())
        
        queue.async {
            var currentItems: [QRDataItem] = InfoTree.shared.stored(at: StorageKey.historyList.rawValue) ?? []
            currentItems.removeAll(where: { $0.id == item.id })
            currentItems.append(item)
            InfoTree.shared.store(value: currentItems, at: StorageKey.historyList.rawValue)
        }
    }
    
    func saveAsCopy(item: QRDataItem, modifiedData: QRCodeData) {
        let item = QRDataItem(item: .created(CreatedQRCodeItem(qrCodeData: modifiedData, date: Date())), date: Date())
        
        queue.async {
            var currentItems: [QRDataItem] = InfoTree.shared.stored(at: StorageKey.historyList.rawValue) ?? []
            currentItems.append(item)
            InfoTree.shared.store(value: currentItems, at: StorageKey.historyList.rawValue)
        }
    }
}

final class HistoryViewModel {
    private let queue = DispatchQueue(label: String(describing: HistoryViewModel.self))
    var historyListRelay: BehaviorRelay<QRDataList> = .init(value: .init(scanned: .init(entries: []), created: .init(entries: [])))
    var selectedSegmentIndex = BehaviorRelay<Int>(value: 0)
    private let disposeBag = DisposeBag()
    
    var currentSections: Observable<[ItemsSctionOriginal]> {
        return Observable.combineLatest(historyListRelay, selectedSegmentIndex)
            .map { historyList, index in
                index == 0 ? historyList.scanned.entries : historyList.created.entries
            }
    }
    
    init() {
        queue.async { [weak self] in
            self?.loadData()
        }
    }
    
    private func loadData() {
        InfoTree.shared.observable(for: StorageKey.historyList.rawValue)
            .subscribe(onNext: { [weak self] (items: [QRDataItem]?) in
                guard let items = items else { return }
                self?.processLoadedItems(items)
            })
            .disposed(by: disposeBag)
    }
    
    private func processLoadedItems(_ items: [QRDataItem]) {
        let historyList = QRDataList(
            scanned: .init(entries: groupAndSortByDate(items.filter { $0.itemType == .scanned })),
            created: .init(entries: groupAndSortByDate(items.filter { $0.itemType == .created }))
        )
        historyListRelay.accept(historyList)
    }
    
    private func groupAndSortByDate(_ items: [QRDataItem]) -> [ItemsSctionOriginal] {
        let groupedItems = Dictionary(grouping: items) { item in
            Calendar.current.startOfDay(for: item.date)
        }
        
        return groupedItems.map { (date, items) in
            ItemsSctionOriginal(date: date, items: items.sorted(by: { $0.date > $1.date }))
        }.sorted(by: { $0.date > $1.date })
    }
    
    func addItem(_ item: QRDataItem) {
        queue.async { [weak self] in
            var items: [QRDataItem] = InfoTree.shared.stored(at: StorageKey.historyList.rawValue) ?? []
            items.append(item)
            InfoTree.shared.store(value: items, at: StorageKey.historyList.rawValue)
            self?.processLoadedItems(items)
        }
    }
    
    func removeItem(_ item: QRDataItem) {
        var items: [QRDataItem] = InfoTree.shared.stored(at: StorageKey.historyList.rawValue) ?? []
        items.removeAll { $0.id == item.id }
        InfoTree.shared.store(value: items, at: StorageKey.historyList.rawValue)
        processLoadedItems(items)
    }
    
    func removeAll() {
        queue.async { [weak self] in
            guard let self else { return }
            let selectedSegment = selectedSegmentIndex.value
            var items: [QRDataItem] = InfoTree.shared.stored(at: StorageKey.historyList.rawValue) ?? []
            items = items.filter({ $0.itemType.rawValue != selectedSegment })
            InfoTree.shared.store(value: items, at: StorageKey.historyList.rawValue)
            processLoadedItems(items)
        }
    }
}
