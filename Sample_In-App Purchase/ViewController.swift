//
//  ViewController.swift
//  Sample_In-App Purchase
//
//  Created by suzuki_kiwamu on 2/4/15.
//  Copyright (c) 2015 suzuki_kiwamu. All rights reserved.
//

import UIKit

private let products = ["jp.hoge.HogeApp.PointRank01", "jp.hoge.HogeApp.PointRank02"]
private let applicationServerURL = "http://google.co.jp"

class ViewController: UIViewController {
    @IBOutlet weak var respondToBuyButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //トランザクションが残っている場合はボタンをOff
        let defaults = NSUserDefaults.standardUserDefaults()
        var count = defaults.integerForKey("NumberOfTransactions")
        if count > 0 {
            respondToBuyButton.enabled = false
        } else {
            respondToBuyButton.enabled = true
        }
    }
    
    
    
    @IBAction func respondToBuyButtonClick() {
        respondToBuyButton.enabled = false
        let inAppPurchase = InAppPurchase.sharedInstance()
        inAppPurchase.requestTimeoutInterval = 150.0
        inAppPurchase.retryCount = 5
        
        
        var server = true
        if server {
            //サーバにレシートを送る処理も含む場合
            inAppPurchase.startInAppPurchase(
                NSURL(fileURLWithPath: applicationServerURL)!,
                productId:products[0],
                complete: {(status: String, error: NSError?, receipt: String?) in
                    println("startInAppPurchase完了ステータス == \(status)")
                    println("startInAppPurchaseエラーコード == \(error)")
                    self.respondToBuyButton.enabled = true
            })
        } else {
            //レシート取得のみの場合
            inAppPurchase.getReceiptInAppPurchase(
                products[0],
                complete: {(status: String, error: NSError?, receipt: String?) in
                    println("startInAppPurchase完了ステータス == \(status)")
                    println("startInAppPurchaseエラーコード == \(error)")
                    self.respondToBuyButton.enabled = true
            })
        }
    }
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    
    //-----------以下作業用
    @IBAction func logUserDefaults(sender: AnyObject) {
        let defaults = NSUserDefaults.standardUserDefaults()
        if var data = defaults.objectForKey("receipts") as? [String] {
            for item in data {
                println("レシートデータ == \(item)")
            }
        }
    }
    
    
    
    @IBAction func delUserDefaults() {
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.removeObjectForKey("receipts")
        println("削除完了")
        defaults.removeObjectForKey("NumberOfTransactions")
        println("削除完了")
    }
}

