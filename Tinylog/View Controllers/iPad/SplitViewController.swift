//
//  SplitViewController.swift
//  Tinylog
//
//  Created by Spiros Gerokostas on 18/10/15.
//  Copyright © 2015 Spiros Gerokostas. All rights reserved.
//

import UIKit

class SplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    var listsViewController: ListsViewController?
    var listViewController: TasksViewController?

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        listsViewController = ListsViewController()
        listsViewController?.managedObjectContext = AppDelegate.sharedAppDelegate().coreDataManager.managedObjectContext
        listViewController = TasksViewController()

        // swiftlint:disable force_unwrapping
        let listsVC: UINavigationController = UINavigationController(rootViewController: listsViewController!)
        let listVC: UINavigationController = UINavigationController(rootViewController: listViewController!)

        self.viewControllers = [listsVC, listVC]
        self.delegate = self
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    class func sharedSplitViewController() -> SplitViewController {
        guard let splitViewController = AppDelegate.sharedAppDelegate().window?.rootViewController
            as? SplitViewController else {
            fatalError()
        }
        return splitViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func splitViewController(
        _ svc: UISplitViewController,
        shouldHide vc: UIViewController,
        in orientation: UIInterfaceOrientation) -> Bool {
        return false
    }
}