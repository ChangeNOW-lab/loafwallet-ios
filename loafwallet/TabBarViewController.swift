//
//  TabBarViewController.swift
//  loafwallet
//
//  Created by Kerry Washington on 11/17/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.

import UIKit
import Foundation
import SwiftyJSON

enum TabViewControllerIndex: Int {
    case transactions = 0
    case send = 1
    case buy = 2
    case receive = 3
    case spend = 4
}
 
protocol MainTabBarControllerDelegate {
    func alertViewShouldDismiss()
}

class TabBarViewController: UIViewController, Subscriber, Trackable, UITabBarDelegate {
      
    let kInitialChildViewControllerIndex = 2 // BuyLTCViewController
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var tabBar: UITabBar!
    @IBOutlet weak var currentLTCPriceLabel: UILabel!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var timeStampLabel: UILabel!
    
    var primaryBalanceLabel: UpdatingLabel?
    var secondaryBalanceLabel: UpdatingLabel?
    private let largeFontSize: CGFloat = 26.0
    private let smallFontSize: CGFloat = 13.0
    private var hasInitialized = false
    private let dateFormatter = DateFormatter()
    private let equalsLabel = UILabel(font: .barloweMedium(size: 13), color: .whiteTint)
    private var regularConstraints: [NSLayoutConstraint] = []
    private var swappedConstraints: [NSLayoutConstraint] = []
    private let currencyTapView = UIView()
    private let storyboardNames:[String] = ["Transactions","Send","Buy","Receive"]
    var storyboardIDs:[String] = ["TransactionsViewController","SendLTCViewController", "BuyLTCViewController","ReceiveLTCViewController"]
    var viewControllers:[UIViewController] = []
    var activeController:UIViewController? = nil
    
    var delegate: MainTabBarControllerDelegate?
    
    var updateTimer: Timer?
    var store: Store?
    var walletManager: WalletManager?
    var exchangeRate: Rate? {
        didSet { setBalances() }
    }
    
    private var balance: UInt64 = 0 {
        didSet { setBalances() }
    }
    
    var isLtcSwapped: Bool? {
        didSet { setBalances() }
    }
      
    override func viewDidLoad() {
        super.viewDidLoad()
        configurePriceLabels()
        addSubscriptions()
        dateFormatter.setLocalizedDateFormatFromTemplate("MMM d, h:mm a")
  
        for (index, storyboardID) in self.storyboardIDs.enumerated() {
            let controller = UIStoryboard.init(name: storyboardNames[index], bundle: nil).instantiateViewController(withIdentifier: storyboardID)
            viewControllers.append(controller)
        }
        
       
         
        self.updateTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { timer in
            self.setBalances()
        }
        
        guard let array = self.tabBar.items else {
            NSLog("ERROR: no items found")
            return
        }
        self.tabBar.selectedItem = array[kInitialChildViewControllerIndex]
    }
    
    deinit {
        self.updateTimer = nil
    }
    
     
    private func configurePriceLabels() {

        
        //TODO: Debug the reizing of label...very important
        guard let primaryLabel = self.primaryBalanceLabel ,
            let secondaryLabel = self.secondaryBalanceLabel else {
          NSLog("ERROR: Price labels not initialized")
                return
        }
         
        let priceLabelArray = [primaryBalanceLabel,secondaryBalanceLabel,equalsLabel]
        
        priceLabelArray.enumerated().forEach { (index, view) in
            view?.backgroundColor = .clear
            view?.textColor = .white
        }
        let equalsWidth: CGFloat = 20
        let halfRemainingWidth = (CGFloat(self.view.frame.width) - CGFloat(currentLTCPriceLabel.frame.width + CGFloat(settingsButton.frame.width)))/2 - equalsWidth
 
        primaryLabel.font = UIFont.barloweSemiBold(size: largeFontSize)
        secondaryLabel.font = UIFont.barloweSemiBold(size: smallFontSize)
        
        
        equalsLabel.text = S.AccountHeader.equals
        
        headerView.addSubview(primaryLabel)
        headerView.addSubview(secondaryLabel)
        headerView.addSubview(equalsLabel)
        headerView.addSubview(currencyTapView)
 
        secondaryLabel.constrain([
            secondaryLabel.constraint(.firstBaseline, toView: primaryLabel, constant: 0.0) ])

        equalsLabel.translatesAutoresizingMaskIntoConstraints = false
        primaryLabel.translatesAutoresizingMaskIntoConstraints = false
    
        regularConstraints = [
            primaryLabel.firstBaselineAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -15),
            primaryLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            primaryLabel.widthAnchor.constraint(equalToConstant: halfRemainingWidth),
            equalsLabel.firstBaselineAnchor.constraint(equalTo: primaryLabel.firstBaselineAnchor),
            equalsLabel.leadingAnchor.constraint(equalTo: primaryLabel.trailingAnchor, constant: 5),
            equalsLabel.widthAnchor.constraint(equalToConstant: equalsWidth),
            secondaryLabel.leadingAnchor.constraint(equalTo: equalsLabel.trailingAnchor, constant: 5),
            secondaryLabel.widthAnchor.constraint(equalToConstant: halfRemainingWidth-30)
        ]

        swappedConstraints = [
            secondaryLabel.firstBaselineAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -15),
            secondaryLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            secondaryLabel.widthAnchor.constraint(equalToConstant: halfRemainingWidth),
            equalsLabel.firstBaselineAnchor.constraint(equalTo: secondaryLabel.firstBaselineAnchor),
            equalsLabel.leadingAnchor.constraint(equalTo: secondaryLabel.trailingAnchor, constant: 5),
            equalsLabel.widthAnchor.constraint(equalToConstant: equalsWidth),
            primaryLabel.leadingAnchor.constraint(equalTo: equalsLabel.trailingAnchor, constant: 5),
            primaryLabel.widthAnchor.constraint(equalToConstant: halfRemainingWidth-30)
        ]
        
        if let isLTCSwapped = self.isLtcSwapped {
            NSLayoutConstraint.activate(isLTCSwapped ? self.swappedConstraints : self.regularConstraints)
        }
        
        currencyTapView.constrain([
                   currencyTapView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 0),
                   currencyTapView.trailingAnchor.constraint(equalTo: self.currentLTCPriceLabel.leadingAnchor, constant: 50),
                   currencyTapView.topAnchor.constraint(equalTo: primaryLabel.topAnchor, constant: 0),
                   currencyTapView.bottomAnchor.constraint(equalTo: primaryLabel.bottomAnchor, constant: C.padding[1]) ])

               let gr = UITapGestureRecognizer(target: self, action: #selector(currencySwitchTapped))
               currencyTapView.addGestureRecognizer(gr)
    }
    
    private func addSubscriptions() {
        
        guard let store = self.store else {
            NSLog("ERROR - Store not passed")
            return
        }
        
        guard let primaryLabel = self.primaryBalanceLabel ,
            let secondaryLabel = self.secondaryBalanceLabel else {
          NSLog("ERROR: Price labels not initialized")
                return
        }
        
        store.lazySubscribe(self,
                            selector: { $0.isLtcSwapped != $1.isLtcSwapped },
                            callback: { self.isLtcSwapped = $0.isLtcSwapped })
        store.lazySubscribe(self,
                            selector: { $0.currentRate != $1.currentRate},
                            callback: {
                                if let rate = $0.currentRate {
                                    let placeholderAmount = Amount(amount: 0, rate: rate, maxDigits: $0.maxDigits)
                                    secondaryLabel.formatter = placeholderAmount.localFormat
                                    primaryLabel.formatter = placeholderAmount.ltcFormat
                                    
                                }
                                self.exchangeRate = $0.currentRate
        })
        
        store.lazySubscribe(self,
                            selector: { $0.maxDigits != $1.maxDigits},
                            callback: {
                                if let rate = $0.currentRate {
                                    let placeholderAmount = Amount(amount: 0, rate: rate, maxDigits: $0.maxDigits)
                                    secondaryLabel.formatter = placeholderAmount.localFormat
                                    primaryLabel.formatter = placeholderAmount.ltcFormat
                                    self.setBalances()
                                }
        })
        
        store.subscribe(self,
                        selector: {$0.walletState.balance != $1.walletState.balance },
                        callback: { state in
                            if let balance = state.walletState.balance {
                                self.balance = balance
                            } })
        
        //        store.subscribe(self, name: TriggerName, callback: <#T##(TriggerName?) -> Void#>)
        //
        //        guard let currentRate = rates.first( where: { $0.code == self.store.state.defaultCurrencyCode }) else { completion(); return }
        //        self.store.perform(action: ExchangeRates.setRates(currentRate: currentRate, rates: rates))
        //        completion()
        //
        //
        //
        //        ExchangeRates.setRates(currentRate:
        ////            store.subscribe(self,
        ////                            selector: { $0.walletState.name != $1.walletState.name },
        ////                            callback: { self.name.text = $0.walletState.name })
    }
    
    private func setBalances() {
        guard let rate = exchangeRate else { return }
        guard let store = self.store else { return }
        guard let isLTCSwapped = self.isLtcSwapped else { return }
        guard let primaryLabel = self.primaryBalanceLabel,
            let secondaryLabel = self.secondaryBalanceLabel else {
                NSLog("ERROR: Price labels not initialized")
                return
        }
        
        
        let amount = Amount(amount: balance, rate: rate, maxDigits: store.state.maxDigits)
        if !hasInitialized {
            let amount = Amount(amount: balance, rate: exchangeRate!, maxDigits: store.state.maxDigits)
            NSLayoutConstraint.deactivate(isLTCSwapped ? self.regularConstraints : self.swappedConstraints)
            NSLayoutConstraint.activate(isLTCSwapped ? self.swappedConstraints : self.regularConstraints)
            primaryLabel.setValue(amount.amountForLtcFormat)
            secondaryLabel.setValue(amount.localAmount)
            if isLTCSwapped {
                primaryLabel.transform = transform(forView: primaryLabel)
            } else {
                secondaryLabel.transform = transform(forView: secondaryLabel)
            }
            hasInitialized = true
            //hideExtraViews()
        } else {
            if primaryLabel.isHidden {
                primaryLabel.isHidden = false
            }

            if secondaryLabel.isHidden {
                secondaryLabel.isHidden = false
            }

            primaryLabel.setValueAnimated(amount.amountForLtcFormat, completion: { [weak self] in
                guard let myself = self else { return }
                guard let isLTCSwapped = myself.isLtcSwapped else { return }
                guard let primaryLabel = myself.primaryBalanceLabel else {
                        NSLog("ERROR: Price label not initialized")
                        return
                }

                if !isLTCSwapped {
                    primaryLabel.transform = .identity
                } else {
                    primaryLabel.transform = myself.transform(forView: primaryLabel)
                }
                //myself.hideExtraViews()
            })
            secondaryLabel.setValueAnimated(amount.localAmount, completion: { [weak self] in
                guard let myself = self else { return }
                guard let isLTCSwapped = myself.isLtcSwapped else { return }
                guard let secondaryLabel = myself.secondaryBalanceLabel else {
                        NSLog("ERROR: Price label not initialized")
                        return
                }
                if isLTCSwapped {
                    secondaryLabel.transform = .identity
                } else {
                    secondaryLabel.transform = myself.transform(forView: secondaryLabel)
                }
                //myself.hideExtraViews()
            })
        }
        
        self.timeStampLabel.text = S.TransactionDetails.priceTimeStampLabel + " " + dateFormatter.string(from: Date())
        let fiatRate = Double(round(100*rate.rate)/100)
        let formattedFiatString = String(format: "%.02f", fiatRate)
        self.currentLTCPriceLabel.text = Currency.getSymbolForCurrencyCode(code: rate.code)! + formattedFiatString
    }
    
    private func hideExtraViews() {
        var didHide = false
        
        guard let primaryLabel = self.primaryBalanceLabel,
                   let secondaryLabel = self.secondaryBalanceLabel else {
                       NSLog("ERROR: Price labels not initialized")
                       return
               }
        
        if secondaryLabel.frame.maxX > currentLTCPriceLabel.frame.minX {
            secondaryLabel.isHidden = true
            didHide = true
        } else {
            secondaryLabel.isHidden = false
        }

        if primaryLabel.frame.maxX > currentLTCPriceLabel.frame.minX {
            primaryLabel.isHidden = true
            didHide = true
        } else {
            primaryLabel.isHidden = false
        }
        equalsLabel.isHidden = didHide
    }
    
    private func transform(forView: UIView) ->  CGAffineTransform {
        forView.transform = .identity //Must reset the view's transform before we calculate the next transform
        let scaleFactor: CGFloat = smallFontSize/largeFontSize
        let deltaX = forView.frame.width * (1-scaleFactor)
        let deltaY = forView.frame.height * (1-scaleFactor)
        let scale = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        return scale.translatedBy(x: -deltaX, y: deltaY/2.0)
    }
    
    override func viewWillAppear(_ animated: Bool) {

        super.viewWillAppear(animated)
        
        guard let array = self.tabBar.items as? [UITabBarItem] else {
            NSLog("ERROR: no items found")
            return
        }
        
        array.forEach { item in
            
            switch item.tag {
            case 0: item.title = S.Account.barItemTitle
            case 1: item.title = S.Send.barItemTitle
            case 2: item.title = S.BuyCenter.barItemTitle
            case 3: item.title = S.Receive.barItemTitle
            case 4: item.title = S.Spend.barItemTitle
            default:
                item.title = "XXXXXX"
                NSLog("ERROR: UITabbar item count is wrong")
            }
        }
     }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.displayContentController(contentController: viewControllers[kInitialChildViewControllerIndex])
    }

    
    func displayContentController(contentController:UIViewController) {
        
        var rawStringClassName = NSStringFromClass(contentController.classForCoder)
         
        switch NSStringFromClass(contentController.classForCoder) {
        case "Litewallet_dev.TransactionsViewController", "Litewallet.TransactionsViewController":

            guard var transactionVC = contentController as? TransactionsViewController else  {
                return
            }
            transactionVC.store = self.store
            transactionVC.walletManager = self.walletManager
            transactionVC.isLtcSwapped = self.store?.state.isLtcSwapped

        case "Litewallet_dev.SendLTCViewController", "Litewallet.SendLTCViewController":
            guard var sendVC = contentController as? SendLTCViewController else  {
                return
            }
            
        case "Litewallet_dev.BuyLTCViewController", "Litewallet.BuyLTCViewController":
            guard var buyVC = contentController as? BuyLTCViewController else  {
                return
            }
        case "Litewallet_dev.ReceiveLTCViewController", "Litewallet.ReceiveLTCViewController":
            guard var receiveVC = contentController as? ReceiveLTCViewController else  {
                return
            }
            
        default:
            fatalError("Tab viewController not set")
        }
        //self.exchangeRate = TransactionManager.sharedInstance.rate
        
        self.addChildViewController(contentController)
        contentController.view.frame = self.containerView.frame
        self.view.addSubview(contentController.view)
        contentController.didMove(toParentViewController: self)
        self.activeController = contentController
    }
    
    func hideContentController(contentController:UIViewController) {
        contentController.willMove(toParentViewController: nil)
        contentController.view .removeFromSuperview()
        contentController.removeFromParentViewController()
    }
      
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        
        if let tempActiveController = activeController {
            self.hideContentController(contentController: tempActiveController)
        }
        self.displayContentController(contentController: viewControllers[item.tag])
    }
    
}

extension TabBarViewController {
    
    @objc private func currencySwitchTapped() {
        self.view.layoutIfNeeded()
        guard let store = self.store else { return }
        guard let isLTCSwapped = self.isLtcSwapped else { return }
        guard let primaryLabel = self.primaryBalanceLabel,
            let secondaryLabel = self.secondaryBalanceLabel else {
                NSLog("ERROR: Price labels not initialized")
                return
        }
        
        UIView.spring(0.7, animations: {
            primaryLabel.transform = primaryLabel.transform.isIdentity ? self.transform(forView: primaryLabel) : .identity
            secondaryLabel.transform = secondaryLabel.transform.isIdentity ? self.transform(forView: secondaryLabel) : .identity
            NSLayoutConstraint.deactivate(!isLTCSwapped ? self.regularConstraints : self.swappedConstraints)
            NSLayoutConstraint.activate(!isLTCSwapped ? self.swappedConstraints : self.regularConstraints)
            self.view.layoutIfNeeded()
            
        }) { _ in }
        store.perform(action: CurrencyChange.toggle())
    }
}




 
