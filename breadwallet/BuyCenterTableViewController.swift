//
//  BuyCenterTableViewController.swift
//  breadwallet
//
//  Created by Kerry Washington on 9/27/18.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit

let buyCellReuseIdentifier = "buyCell"

class BuyCenterTableViewController: UITableViewController, BuyCenterTableViewCellDelegate {

    fileprivate let litecoinLogo = UIImageView(image:#imageLiteral(resourceName: "litecoinLogo"))
    private let store: Store
    private let walletManager: WalletManager
    private let mountPoint: String, bundleName: String
    private let partnerArray = Partner.dataArray()
    private let headerHeight : CGFloat = 140
  
    init(store: Store, walletManager: WalletManager, mountPoint: String, bundleName: String?) {
      self.store = store
      self.walletManager = walletManager
      self.mountPoint = mountPoint
      self.bundleName = bundleName ?? ""
      super.init(nibName: nil, bundle: nil)
    }
  
    required init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
  
    override func viewDidLoad() {
      super.viewDidLoad()
      self.tableView.separatorColor = UIColor.clear
      self.tableView.dataSource = self
      self.tableView.delegate = self
      self.tableView.register(BuyCenterTableViewCell.self, forCellReuseIdentifier: buyCellReuseIdentifier)
      self.tableView.backgroundColor = #colorLiteral(red: 0.9411764706, green: 0.9411764706, blue: 0.9411764706, alpha: 1)
      self.clearsSelectionOnViewWillAppear = false
    
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { return 160}

    override func numberOfSections(in tableView: UITableView) -> Int { return 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return partnerArray.count }
  
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
     
      let fr = CGRect(x: 0, y: 0, width: self.view.frame.width, height: headerHeight)
      let buyCenterHeaderView = BuyCenterHeaderView(frame: fr, height: headerHeight)
       buyCenterHeaderView.closeCallback = {
        self.dismiss(animated: true, completion: nil)
       }
      return buyCenterHeaderView
    }
  
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { return headerHeight }
 
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
      let cell = tableView.dequeueReusableCell(withIdentifier: buyCellReuseIdentifier, for: indexPath) as! BuyCenterTableViewCell
      let partnerData = partnerArray[indexPath.row]
      
        cell.partnerLabel.text = partnerData["title"] as? String
        cell.financialDetailsLabel.text = partnerData["details"] as? String
        cell.logoImageView.image = partnerData["logo"] as? UIImage
        cell.frameView.backgroundColor = (partnerData["baseColor"] as? UIColor)!
        cell.delegate = self
      
     return cell
    }

  func didClickPartnerCell(partner: String) {
    
    switch partner {
      case "Simplex":
        let simplexWebviewVC = BRWebViewController(partner: "Simplex", bundleName: bundleName, mountPoint: mountPoint, walletManager: walletManager, store: store, noAuthApiClient: nil)
        let nc = UINavigationController(rootViewController: simplexWebviewVC)
          nc.topViewController?.title = "Buy Litecoin"
        let backButton = UIBarButtonItem(image: #imageLiteral(resourceName: "Close"), style: .plain, target: self, action:#selector(dismissWebContainer))
          backButton.tintColor = UIColor.black
          nc.topViewController?.navigationItem.leftBarButtonItem = backButton
        present(nc, animated: true
        , completion: nil)
      case "Changelly":
        print("Changelly No Code Placeholder")
      case "Partner 3":
        let partner3 = BuyCenterWebViewController(nibName: nil, bundle: nil)
        present(partner3, animated: true) {
          //
       }
      default:
        fatalError("No Partner Chosen")
    }
  }
   // MARK: - Navigation
//   override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//
//   }
  
  @objc func dismissWebContainer() {
    dismiss(animated: true, completion: nil)
  }
}



