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

    #if DEBUG && targetEnvironment(simulator)
    private var localLedgerURL: URL { ledgerURL.deletingLastPathComponent().appendingPathComponent("xcode-purchases.json") }
    private var cachedLocalReceipt: (data: Data, response: [String: Any]?)?

    private func localResponse(_ data: Data) -> [String: Any]? {
        if let cached = cachedLocalReceipt, cached.data == data { return cached.response }
        let response = try? XcodeReceipt.verify(data)
        cachedLocalReceipt = (data, response)
        return response
    }
    #endif

    private var displayedLedgerURL: URL {
        #if DEBUG && targetEnvironment(simulator)
        if let url = Bundle.main.appStoreReceiptURL, let data = try? Data(contentsOf: url), localResponse(data) != nil {
            return localLedgerURL
        }
        #endif
        return ledgerURL
    }

    private func ledger(at url: URL) throws -> [String: Any] {
        let environments = url == ledgerURL ? ["Production", "Sandbox"] : ["Xcode"]
        guard FileManager.default.fileExists(atPath: url.path) else {
            var empty: [String: Any] = ["environment": environments[0]]
            for environment in environments {
                empty[environment] = ["balance": 0, "transactions": [String](), "activity": [[String: Any]]()] as [String: Any]
            }
            return empty
        }
        guard let value = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
              let environment = value["environment"] as? String, environments.contains(environment) else { throw roroError("Your purchase history could not be read. Please try again.") }
        for environment in environments {
            guard let account = value[environment] as? [String: Any], account["balance"] is Int,
                  (account["unlockedCategories"] == nil || account["unlockedCategories"] is [String]),
                  (account["unlockedTopics"] == nil || account["unlockedTopics"] is [String]),
                  account["transactions"] is [String], account["activity"] is [[String: Any]] else { throw roroError("Your purchase history could not be read. Please try again.") }
        }
        return value
    }

    func snapshot() throws -> [String: Any] {
        let value = try ledger(at: displayedLedgerURL)
        let account = value[value["environment"] as! String] as! [String: Any]
        let offers: [[String: Any]] = catalog.map { item in
            let price = products[item.id].flatMap { localizedPrice($0) }
            return ["id": item.id, "price": price as Any? ?? NSNull(), "credits": item.credits]
        }
        return [
            "unlockedCategories": account["unlockedCategories"] as? [String] ?? [],
            "unlockedTopics": account["unlockedTopics"] as? [String] ?? [],
            "balance": account["balance"]!, "activity": account["activity"]!,
            "products": offers, "status": status, "notice": transactionNotice,
            "checkoutBlocked": checkoutBlocked,
            "canRetry": !undeliveredTransactions.isEmpty && processing.isEmpty && receiptRequest == nil
        ]
    }

    func unlockTopicWork(_ id: String, scope: String, quotedPrice: Int) throws -> [String: Any] {
        guard let work = try CommunityCatalog.records("photos").first(where: { $0["id"] as? String == id }),
              work["surface"] as? String == "topics", let workPrice = work["coinPrice"] as? Int,
              (1...9999).contains(workPrice), let category = work["topic"] as? String,
              let prices = try CommunityCatalog.load()["categoryPrices"] as? [String: Int],
              let passPrice = prices[category], (1...9999).contains(passPrice),
              ["work", "category"].contains(scope) else { throw roroError("This work is unavailable.") }
        let url = displayedLedgerURL
        var value = try ledger(at: url)
        let environment = value["environment"] as! String
        var account = value[environment] as! [String: Any]
        let isPass = scope == "category"
        let price = isPass ? passPrice : workPrice
        guard price == quotedPrice else { throw roroError("The price has changed. Review the price and try again.") }
        let passes = account["unlockedCategories"] as? [String] ?? []
        let works = account["unlockedTopics"] as? [String] ?? []
        if passes.contains(category) || (!isPass && works.contains(id)) { return try snapshot() }
        let balance = account["balance"] as! Int
        guard balance >= price else { throw roroError("You need more coins to unlock this work.") }
        if isPass { account["unlockedCategories"] = passes + [category] }
        else { account["unlockedTopics"] = works + [id] }
        account["balance"] = balance - price
        var activity = account["activity"] as! [[String: Any]]
        activity.insert(["id": isPass ? "category-" + category : "topic-" + id, "label": isPass ? category + " pass" : "Topic work", "credits": -price, "date": ISO8601DateFormatter().string(from: Date())], at: 0)
        account["activity"] = activity
        value[environment] = account
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return try snapshot()
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
        _ = try ledger(at: displayedLedgerURL)
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
        #if DEBUG && targetEnvironment(simulator)
        if let response = localResponse(receipt) {
            deliver(.success(response), transaction: transaction, id: transactionID, ledgerURL: localLedgerURL)
            return
        }
        #endif
        verifyReceipt(receipt, sandbox: false) { result in
            DispatchQueue.main.async {
                self.deliver(result, transaction: transaction, id: transactionID, ledgerURL: self.ledgerURL)
            }
        }
    }

    private func deliver(_ result: Result<[String: Any], Error>, transaction: SKPaymentTransaction, id transactionID: String, ledgerURL: URL) {
        defer { processing.remove(transactionID) }
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
                  let environment = response["environment"] as? String, (ledgerURL == self.ledgerURL ? ["Production", "Sandbox"] : ["Xcode"]).contains(environment) else {
                throw roroError("Your purchase is waiting for confirmation.")
            }
            var ledger = try self.ledger(at: ledgerURL)
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
            try FileManager.default.createDirectory(at: ledgerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: ledger, options: [.sortedKeys]).write(to: ledgerURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            self.pendingProducts.remove(transaction.payment.productIdentifier)
            self.transactionNotice = alreadyCredited ? "" : "Purchase confirmed. Your balance has been updated."
            SKPaymentQueue.default().finishTransaction(transaction)
        } catch {
            transactionNotice = "Your purchase is waiting for confirmation. Please check again later."
            // Leave undelivered transactions in Apple's queue for a later retry.
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
