import Foundation
import StoreKit

struct CreditProduct: Decodable {
    let id: String
    let credits: Int
}

final class PurchaseService: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver, SKRequestDelegate {
    static let shared = PurchaseService()
    private var catalog: [CreditProduct] = []
    private var configured: [String: Int] = [:]
    private var products: [String: SKProduct] = [:]
    private var request: SKProductsRequest?
    private var receiptRequest: SKReceiptRefreshRequest?
    private var transactionNotice = ""
    private var waiters: [(Result<[String: Any], Error>) -> Void] = []
    private var timeout: DispatchWorkItem?
    private var receiptTimeout: DispatchWorkItem?
    private var processing = Set<String>()
    private var pendingProducts = Set<String>()
    private var status = "unavailable"
    private let ledgerURL: URL

    override private init() {
        ledgerURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Roro/purchases.json")
        super.init()
        if let url = Bundle.main.url(forResource: "products", withExtension: "json", subdirectory: "AppResources"),
           let data = try? Data(contentsOf: url), let items = try? JSONDecoder().decode([CreditProduct].self, from: data) {
            for item in items where !item.id.isEmpty && item.credits > 0 && item.credits <= 1_000_000 && configured[item.id] == nil {
                catalog.append(item)
                configured[item.id] = item.credits
            }
        }
        SKPaymentQueue.default().add(self)
    }

    private func ledger() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: ledgerURL.path) else {
            return ["environment": "Production", "Production": ["balance": 0, "transactions": [String](), "activity": [[String: Any]]()], "Sandbox": ["balance": 0, "transactions": [String](), "activity": [[String: Any]]()]]
        }
        guard let value = try JSONSerialization.jsonObject(with: Data(contentsOf: ledgerURL)) as? [String: Any],
              let environment = value["environment"] as? String, ["Production", "Sandbox"].contains(environment) else { throw roroError("Your purchase history could not be read. Please try again.") }
        for environment in ["Production", "Sandbox"] {
            guard let account = value[environment] as? [String: Any], account["balance"] is Int,
                  account["transactions"] is [String], account["activity"] is [[String: Any]] else { throw roroError("Your purchase history could not be read. Please try again.") }
        }
        return value
    }

    func snapshot() throws -> [String: Any] {
        let value = try ledger()
        let account = value[value["environment"] as! String] as! [String: Any]
        let offers: [[String: Any]] = catalog.map { item in
            let price = products[item.id].flatMap { localizedPrice($0) }
            return ["id": item.id, "price": price as Any? ?? NSNull(), "credits": item.credits]
        }
        return [
            "balance": account["balance"]!, "activity": account["activity"]!,
            "products": offers, "status": status, "notice": transactionNotice,
            "checkoutBlocked": checkoutBlocked,
            "canRetry": !undeliveredTransactions.isEmpty && processing.isEmpty && receiptRequest == nil
        ]
    }

    private var checkoutBlocked: Bool {
        !pendingProducts.isEmpty || !SKPaymentQueue.default().transactions.isEmpty
    }

    private var undeliveredTransactions: [SKPaymentTransaction] {
        SKPaymentQueue.default().transactions.filter {
            ($0.transactionState == .purchased || $0.transactionState == .restored) &&
            configured[$0.payment.productIdentifier] != nil
        }
    }

    private func localizedPrice(_ product: SKProduct) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price)
    }

    func load(_ completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard !configured.isEmpty else { completion(Result { try snapshot() }); return }
        waiters.append(completion)
        guard request == nil else { return }
        status = "loading"
        let request = SKProductsRequest(productIdentifiers: Set(configured.keys))
        self.request = request
        request.delegate = self
        let timeout = DispatchWorkItem { [weak self, weak request] in
            guard let self, self.request === request else { return }
            self.request?.cancel()
            self.complete(phase: "failed")
        }
        self.timeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
        request.start()
    }

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            guard self.request === request else { return }
            self.products = Dictionary(uniqueKeysWithValues: response.products.compactMap { product in
                guard self.configured[product.productIdentifier] != nil,
                      self.localizedPrice(product) != nil else { return nil }
                return (product.productIdentifier, product)
            })
            let phase = self.products.isEmpty ? "unavailable" :
                (self.products.count == self.catalog.count ? "ready" : "partial")
            self.complete(phase: phase)
        }
    }

    func requestDidFinish(_ request: SKRequest) {
        DispatchQueue.main.async {
            guard self.receiptRequest === request else { return }
            self.clearReceiptRequest()
            self.retryTransactions()
        }
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async {
            if self.receiptRequest === request {
                self.clearReceiptRequest()
                self.transactionNotice = "Your purchase is waiting for confirmation. Please try again later."
                return
            }
            guard self.request === request else { return }
            self.complete(phase: "failed")
        }
    }

    private func complete(phase: String) {
        timeout?.cancel(); timeout = nil
        request?.delegate = nil; request = nil
        if phase == "failed" { products.removeAll() }
        status = phase
        let result = Result { try snapshot() }
        let callbacks = waiters; waiters = []
        callbacks.forEach { $0(result) }
    }

    func buy(_ id: String) throws {
        guard SKPaymentQueue.canMakePayments() else { throw roroError("Purchases are not allowed on this iPhone.") }
        guard status == "ready" || status == "partial", let product = products[id] else { throw roroError("This offer is not available. Pull down to check prices.") }
        guard !checkoutBlocked else { throw roroError("A purchase is already being processed.") }
        _ = try ledger()
        pendingProducts.insert(id)
        transactionNotice = "Your purchase is being processed."
        SKPaymentQueue.default().add(SKPayment(product: product))
    }

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        DispatchQueue.main.async {
            for transaction in transactions {
                switch transaction.transactionState {
                case .purchased, .restored:
                    self.verify(transaction, refreshIfMissing: true)
                case .failed:
                    self.pendingProducts.remove(transaction.payment.productIdentifier)
                    let cancelled = (transaction.error as? SKError)?.code == .paymentCancelled
                    self.transactionNotice = cancelled ? "Purchase cancelled." : "The purchase could not be completed."
                    queue.finishTransaction(transaction)
                case .deferred, .purchasing:
                    self.transactionNotice = transaction.transactionState == .deferred ? "Your purchase is awaiting approval." : "Your purchase is being processed."
                    self.pendingProducts.insert(transaction.payment.productIdentifier)
                @unknown default:
                    break
                }
            }
        }
    }

    func retry() {
        guard !undeliveredTransactions.isEmpty, processing.isEmpty, receiptRequest == nil else { return }
        if let url = Bundle.main.appStoreReceiptURL, let data = try? Data(contentsOf: url), !data.isEmpty {
            retryTransactions()
        } else {
            refreshReceipt()
        }
    }

    private func refreshReceipt() {
        guard receiptRequest == nil else { return }
        let request = SKReceiptRefreshRequest()
        receiptRequest = request
        request.delegate = self
        let timeout = DispatchWorkItem { [weak self, weak request] in
            guard let self, self.receiptRequest === request else { return }
            self.receiptRequest?.cancel()
            self.clearReceiptRequest()
            self.transactionNotice = "Your purchase is waiting for confirmation. Please check again later."
        }
        receiptTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
        request.start()
    }

    private func clearReceiptRequest() {
        receiptTimeout?.cancel()
        receiptTimeout = nil
        receiptRequest?.delegate = nil
        receiptRequest = nil
    }

    private func retryTransactions() {
        for transaction in undeliveredTransactions { verify(transaction) }
    }

    private func verify(_ transaction: SKPaymentTransaction, refreshIfMissing: Bool = false) {
        guard configured[transaction.payment.productIdentifier] != nil else {
            transactionNotice = "A purchase needs assistance before it can be confirmed."
            return
        }
        guard let transactionID = transaction.transactionIdentifier,
              !processing.contains(transactionID) else { return }
        transactionNotice = "Your purchase is waiting for confirmation."
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receipt = try? Data(contentsOf: receiptURL), !receipt.isEmpty else {
            if refreshIfMissing { refreshReceipt() }
            return
        }
        processing.insert(transactionID)
        // Consumable receipt validation uses Apple's receipt endpoint without a shared secret.
        verifyReceipt(receipt, sandbox: false) { result in
            DispatchQueue.main.async {
                defer { self.processing.remove(transactionID) }
                do {
                    let response = try result.get()
                    guard let receipt = response["receipt"] as? [String: Any],
                          receipt["bundle_id"] as? String == Bundle.main.bundleIdentifier,
                          let rows = receipt["in_app"] as? [[String: Any]],
                          let record = rows.first(where: { $0["transaction_id"] as? String == transactionID && $0["product_id"] as? String == transaction.payment.productIdentifier }),
                          record["cancellation_date"] == nil,
                          let quantityString = record["quantity"] as? String,
                          let quantity = Int(quantityString), quantity == transaction.payment.quantity, quantity > 0,
                          let credits = self.configured[transaction.payment.productIdentifier],
                          let environment = response["environment"] as? String, ["Production", "Sandbox"].contains(environment) else {
                        throw roroError("Your purchase is waiting for confirmation.")
                    }
                    var ledger = try self.ledger()
                    var account = ledger[environment] as! [String: Any]
                    var transactions = account["transactions"] as! [String]
                    let alreadyCredited = transactions.contains(transactionID)
                    if !alreadyCredited {
                        let (amount, overflow) = credits.multipliedReportingOverflow(by: quantity)
                        let (balance, balanceOverflow) = (account["balance"] as! Int).addingReportingOverflow(amount)
                        guard !overflow, !balanceOverflow else { throw roroError("Your purchase needs assistance.") }
                        transactions.append(transactionID)
                        var activity = account["activity"] as! [[String: Any]]
                        activity.insert(["id": transactionID, "credits": amount, "date": ISO8601DateFormatter().string(from: Date())], at: 0)
                        account["transactions"] = transactions
                        account["balance"] = balance
                        account["activity"] = activity
                        ledger[environment] = account
                    }
                    ledger["environment"] = environment
                    try FileManager.default.createDirectory(at: self.ledgerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try JSONSerialization.data(withJSONObject: ledger, options: [.sortedKeys]).write(to: self.ledgerURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                    self.pendingProducts.remove(transaction.payment.productIdentifier)
                    self.transactionNotice = alreadyCredited ? "" : "Purchase confirmed. Your balance has been updated."
                    SKPaymentQueue.default().finishTransaction(transaction)
                } catch {
                    self.transactionNotice = "Your purchase is waiting for confirmation. Please check again later."
                    // Leave undelivered transactions in Apple's queue for a later retry.
                }
            }
        }
    }

    private func verifyReceipt(_ receipt: Data, sandbox: Bool, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let endpoint = sandbox ? "https://sandbox.itunes.apple.com/verifyReceipt" : "https://buy.itunes.apple.com/verifyReceipt"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["receipt-data": receipt.base64EncodedString()])
        URLSession.shared.dataTask(with: request) { data, response, error in
            do {
                if let error { throw error }
                guard (response as? HTTPURLResponse)?.statusCode == 200, let data,
                      let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let status = result["status"] as? Int else { throw roroError("Your purchase is waiting for confirmation.") }
                if status == 21007 && !sandbox { self.verifyReceipt(receipt, sandbox: true, completion: completion); return }
                guard status == 0 else { throw roroError("Your purchase is waiting for confirmation.") }
                completion(.success(result))
            } catch { completion(.failure(error)) }
        }.resume()
    }
}
