//
//  InAppPurchase.swift
//  Sample_In-App Purchase
//
//  Created by suzuki_kiwamu on 2/4/15.
//  Copyright (c) 2015 suzuki_kiwamu. All rights reserved.
//

import UIKit
import StoreKit

private let sharedInAppPurchase = InAppPurchase()
private let ReceiptsUserDefaultsKey = "receipts"
private let NumberOfTransactionsUserDefaultsKey = "NumberOfTransactions"


enum ErrorCode: Int {
    case Network        = 201
    case Authorization  = 202
    case ServerResponse = 203
    case InvalidProduct = 204
}



@objc class InAppPurchase: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    
    //option
    var requestTimeoutInterval: NSTimeInterval = 120.0
    var retryCount: Int = 0
    
    // property
    var _receiptOnly = false
    var _applicationServerURL: NSURL?
    var _newReceipt: String?
    var receiptComplete: (status: String, error: NSError?, receipt: String?) -> Void = {(status: String, error: NSError?, receipt: String?) in}
    var sendComplete: (status: String, error: NSError?, receipt: String?) -> Void = {(status: String, error: NSError?, receipt: String?) in}
    
    
    private override init() {
        super.init()
        isUntreatedTransaction("init")
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "applicationDidEnterBackground", name: UIApplicationDidEnterBackgroundNotification, object: nil)
        
        SKPaymentQueue.defaultQueue().addTransactionObserver(self)
    }
    
    class func sharedInstance() -> InAppPurchase {
        return sharedInAppPurchase
    }
    
    
    
    /**
    購入処理開始時に呼ばれる(getReceiptInAppPurchaseを呼び、callback時にレシートの保存と、サーバへのレシート送付を行う)
    :param: applicationServerURL サーバのURL
    :param: productId            購入対象のproductId
    :param: complete             購入処理がなんらか終了したタイミングで実行するメソッド
    */
    func startInAppPurchase(applicationServerURL: NSURL, productId: String, complete:(status: String, error: NSError?, receipt: String?) -> Void) {
        _applicationServerURL = applicationServerURL
        sendComplete = complete
        
        getReceiptInAppPurchase(productId, complete: {(status: String, error: NSError?, receipt: String?) -> Void in
            if (receipt != nil) {
                self.saveReceipts(receipt!)
                self.sendToAppServer(receipt!)
            } else {
                self.sendComplete(status: status, error: error, receipt: receipt)
            }
        })
    }
    
    
    
    /**
    購入処理開始時に呼ばれる(レシート取得のみを行う)
    :param: productId            購入対象のproductId
    :param: complete             購入処理がなんらか終了したタイミングで実行するメソッド
    */
    func getReceiptInAppPurchase(productId: String, complete:(status: String, error: NSError?, receipt: String?) -> Void) {
        receiptComplete = complete
        
        checkNetwork()
        checkBillingAuthorization()
        requestProduct(productId)
    }
    
    
    
    /**
    指定したproductIdが、iTunesConnect利用可能かを問い合わせます。
    :param: productId 購入対象のProductId
    */
    func requestProduct(productId: String) {
        isUntreatedTransaction("requestProduct")
        let productRequest = SKProductsRequest(productIdentifiers: NSSet(objects: productId))
        productRequest.delegate = self
        productRequest.start()
    }
    
    
    
    // MARK: SKProductsRequestDelegate protocol
    /**
    購入対象のproductIdの状態が購入可能なら、購入のQueueに登録
    */
    func productsRequest(request: SKProductsRequest!, didReceiveResponse response: SKProductsResponse!) {
        isUntreatedTransaction("productsRequest")
        if response.invalidProductIdentifiers.count > 0 {
            receiptComplete(status: "invalidProductError", error: (NSError(domain: "invalidProductError", code: ErrorCode.InvalidProduct.rawValue, userInfo: nil)), receipt: nil)
            return
        }
        for product in response.products {
            let payment = SKPayment(product: product as SKProduct)
            SKPaymentQueue.defaultQueue().addPayment(payment)
        }
    }
    
    
    
    // MARK: TransactionObserver
    /**
    購入処理のステータス変更の度に呼ばれる
    */
    func paymentQueue(queue: SKPaymentQueue!, updatedTransactions transactions: [AnyObject]!) {
        //購入処理を取得
        isUntreatedTransaction("updatedTransactions")
        for transaction in transactions as [SKPaymentTransaction] {
            switch transaction.transactionState {
            case .Purchasing:
                isUntreatedTransaction("購入中...")
                countUpNumberOfTransactions()
            case .Purchased:
                isUntreatedTransaction("購入処理が成功...")
                let url = NSBundle.mainBundle().appStoreReceiptURL
                let data = NSData(contentsOfURL: url!)!
                
                _newReceipt = data.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue:0)) //base64
                queue.finishTransaction(transaction)
            case .Restored:
                isUntreatedTransaction("購入処理復元...")
                queue.finishTransaction(transaction)
                receiptComplete(status: "Restored", error: nil, receipt: nil)
            case .Failed:
                isUntreatedTransaction("購入処理復元...")
                queue.finishTransaction(transaction)
            case .Deferred:
                isUntreatedTransaction("ファミリー共有")
                queue.finishTransaction(transaction)
                receiptComplete(status: "Deferred", error: nil, receipt: nil)
            }
        }
    }
    
    
    
    /**
    購入処理(成功/失敗)の終了時に呼ばれる
    */
    func paymentQueue(queue: SKPaymentQueue!, removedTransactions transactions: [AnyObject]!) {
        isUntreatedTransaction("removedTransactions")
        receiptComplete(status: "購入 or 失敗の処理完了", error: nil, receipt: nil)
        countDownNumberOfTransactions()
    }
    
    
    
    // MARK: Method
    /**
    UserDefaultsへ、レシートの保存処理を行う
    */
    func saveReceipts(newReceipt: String) {
        let defaults = NSUserDefaults.standardUserDefaults()
        if var receipts = defaults.objectForKey(ReceiptsUserDefaultsKey) as? [String] {
            receipts.append(newReceipt)
            defaults.setObject(receipts, forKey: ReceiptsUserDefaultsKey)
        } else {
            defaults.setObject([newReceipt], forKey: ReceiptsUserDefaultsKey)
        }
        defaults.synchronize()
    }
    
    
    
    /**
    transaction管理の為にトランザクション数を、追加
    */
    func countUpNumberOfTransactions() {
        let defaults = NSUserDefaults.standardUserDefaults()
        var count = defaults.integerForKey(NumberOfTransactionsUserDefaultsKey)
        defaults.setInteger(count+1, forKey: NumberOfTransactionsUserDefaultsKey)
        defaults.synchronize()
    }
    
    
    
    /**
    transaction管理の為にトランザクション数を、削除
    */
    func countDownNumberOfTransactions() {
        let defaults = NSUserDefaults.standardUserDefaults()
        var count = defaults.integerForKey(NumberOfTransactionsUserDefaultsKey)
        defaults.setInteger(count-1, forKey: NumberOfTransactionsUserDefaultsKey)
        defaults.synchronize()
    }
    
    
    
    // TODO:サーバサイドに仕様確認
    /**
    アプリケーションサーバへレシートを送る
    */
    func sendToAppServer(newReceipt: String) {

        let strData = newReceipt.dataUsingEncoding(NSUTF8StringEncoding)
        var request = NSMutableURLRequest(URL: _applicationServerURL!)
        
        request.HTTPMethod = "POST"
        request.HTTPBody = strData
        request.timeoutInterval = requestTimeoutInterval
        
        //        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue(), completionHandler: self.getHttp)
        sendComplete(status: "sendToAppServer", error: nil, receipt: nil)
    }
    
    
    
    /**
    sendAsynchronousRequest処理完了時に呼ばれ、エラーの場合はリトライします
    :param: res   NSURLResponse
    :param: data  NSData
    :param: error NSError
    */
    func getHttp(res: NSURLResponse?, data: NSData?, error: NSError?) {
        if error != nil {
            if retryCount > 0 {
                retryCount--
                sendToAppServer(_newReceipt!)
            } else {
                receiptComplete(status: "ServerResponseError", error:(NSError(domain: "ServerResponseError", code: ErrorCode.ServerResponse.rawValue, userInfo: nil)), receipt: nil)
                return
            }
        } else {
            getData(res, data: data, error: error)
        }
    }
    
    
    
    /**
    getHttpでデータが正常処理時に呼ばれます。
    :param: res   NSURLResponse
    :param: data  NSData
    :param: error NSError
    */
    func getData(res: NSURLResponse?, data: NSData?, error: NSError?) {
        var returnData = NSString(data: data!, encoding: NSUTF8StringEncoding)!
        
        if returnData == NSNull() {
            //取得エラー
        }
        //正常にサーバで処理された場合の処理をここに書く
    }
    
    
    
    /**
    networkの疎通チェック
    */
    func checkNetwork() {
        if !IJReachability.isConnectedToNetwork() {
            receiptComplete(status: "networkError", error: (NSError(domain: "networkError", code: ErrorCode.Network.rawValue, userInfo: nil)), receipt: nil)
            return
        }
    }
    
    
    
    /**
    アプリ内課金の制限チェック
    */
    func checkBillingAuthorization() {
        if !SKPaymentQueue.canMakePayments() {
            receiptComplete(status: "authorizationError", error: (NSError(domain: "authorizationError", code: ErrorCode.Authorization.rawValue, userInfo: nil)), receipt: nil)
            return
        }
    }
    
    
    /**
    バックグラウンド時は、transaction未完了は、破棄
    */
    func applicationDidEnterBackground() {
        let transactions = SKPaymentQueue.defaultQueue().transactions
        for transaction in transactions as [SKPaymentTransaction] {
            SKPaymentQueue.defaultQueue().finishTransaction(transaction)
        }
    }
    
    
    
    deinit {
        SKPaymentQueue.defaultQueue().removeTransactionObserver(self)
    }
    
    
    
    func isUntreatedTransaction(string: String) {
        let transactions = SKPaymentQueue.defaultQueue().transactions
        println("transactions.count ==  \(transactions.count) / \(string)")
    }
}
