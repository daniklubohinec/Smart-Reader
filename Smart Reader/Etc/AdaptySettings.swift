//
//  AdaptySettings.swift
//  Smart Reader
//
//  Created by Glenda Ricky on 8.11.24.
//

import Foundation
import UIKit
import Adapty

struct AdaptyRemoteConfig: Decodable {
    var trial: String?
    var priceSubtitle: String
    var priceDescription: String
    var purchaseTitle: String
    var descriptionSubtitle: String
    var descriptionPerWeek: String
    var review: Bool
}

struct PurchasesModelStruct {
    var config: AdaptyRemoteConfig
    var products: [AdaptyPaywallProduct]
}

protocol PurchaseServiceProtocol {
    
    var hasPremium: Bool { get }
    var paywallsLoaded: Bool { get }
    var inAppPaywall: PurchasesModelStruct? { get }
    
    func configure()
    func getPaywalls() async
    func checkPurchases() async
    func makePurchase(product: AdaptyPaywallProduct) async
    func restorePurchases() async
}

enum PurchaseInfo {
    case onboardingInapp
    
    var key: String {
        switch self {
        case .onboardingInapp:
            return "premium_access"
        }
    }
}

final class PurchaseService: PurchaseServiceProtocol {
    static let shared = PurchaseService()
    
    @Published var hasPremium: Bool = false
    @Published var inAppPaywall: PurchasesModelStruct?
    var paywallsLoaded: Bool {
        inAppPaywall != nil
    }
    var review: Bool {
        true// inAppPaywall?.config.review ?? false
    }
    
    private init() { }
    
    func configure() {
        Adapty.delegate = self
        Adapty.activate("public_live_un2rzF4t.0eepG37BGWlKglPjQPjr")
        Task {
            await checkPurchases()
            await getPaywalls()
        }
        
        print("________\(inAppPaywall?.config.review)")
    }
    
    @MainActor
    func checkPurchases() async {
        do {
            let profile = try await Adapty.getProfile()
            hasPremium = profile.accessLevels["premium"]?.isActive ?? false
        } catch {
            hasPremium = false
        }
    }
    
    func getPaywalls() async {
        do {
            let inAppPaywall = try await Adapty.getPaywall(placementId: PurchaseInfo.onboardingInapp.key)
            let inAppData = retrievePaywalls(paywall: inAppPaywall)
            
            guard let inAppData else { return }
            try await getPaywallProducts(paywall: inAppPaywall, data: inAppData, type: .onboardingInapp)
        } catch { }
    }
    
    private func retrievePaywalls(paywall: AdaptyPaywall) -> Data? {
        guard let json = paywall.remoteConfig,
              let inAppData = try? JSONSerialization.data(withJSONObject: json) else { return nil }
        return inAppData
    }
    
    private func getPaywallProducts(paywall: AdaptyPaywall,
                                    data: Data,
                                    type: PurchaseInfo) async throws {
        
        let config = try JSONDecoder().decode(AdaptyRemoteConfig.self, from: data)
        inAppPaywall = PurchasesModelStruct(config: config, products: [])
        let products: [AdaptyPaywallProduct] = try await Adapty.getPaywallProducts(paywall: paywall)
        switch type {
        case .onboardingInapp:
            inAppPaywall = PurchasesModelStruct(config: config, products: products)
        }
    }
    
    func makePurchase(product: AdaptyPaywallProduct) async {
        do {
            let result = try await Adapty.makePurchase(product: product)
            hasPremium = (result.profile.accessLevels["premium"]?.isActive == true)
        } catch {
            hasPremium = false
        }
    }
    
    func restorePurchases() async {
        do {
            let profile = try await Adapty.restorePurchases()
            hasPremium = (profile.accessLevels["premium"]?.isActive == true)
        } catch {
            hasPremium = false
        }
    }
}
extension PurchaseService: AdaptyDelegate {
    func didLoadLatestProfile(_ profile: AdaptyProfile) {
        hasPremium = profile.accessLevels["premium"]?.isActive ?? false
    }
}

func presentPurchasesScreen(presenting: UIViewController) {
    let purchasesVc = UIStoryboard(name: "Purchases", bundle: .main).instantiateViewController(identifier: "PurchasesViewController") as PurchasesViewController
    purchasesVc.modalPresentationStyle = .fullScreen
    if !isPurchasesPresented {
        presenting.present(purchasesVc, animated: true, completion: nil)
    }
}
