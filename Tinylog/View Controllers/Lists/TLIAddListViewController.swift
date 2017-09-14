//
//  TLIAddListViewController.swift
//  Tinylog
//
//  Created by Spiros Gerokostas on 18/10/15.
//  Copyright © 2015 Spiros Gerokostas. All rights reserved.
//

import UIKit

class TLIAddListViewController: UITableViewController, UITextFieldDelegate {

    var managedObjectContext: NSManagedObjectContext!
    var name: UITextField?
    var menuColorsView: TLIMenuColorsView?
    var delegate: TLIAddListViewControllerDelegate?
    var mode: String?
    var list: TLIList?

    init() {
        super.init(style: UITableViewStyle.grouped)
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.tinylogLightGray
        self.tableView.separatorColor = UIColor.tinylogTableViewLineColor

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: UIBarButtonItemStyle.plain,
            target: self,
            action: #selector(TLIAddListViewController.cancel(_:)))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: UIBarButtonItemStyle.plain,
            target: self,
            action: #selector(TLIAddListViewController.save(_:)))

        menuColorsView = TLIMenuColorsView(
            frame: CGRect(x: 12.0, y: 200.0, width: self.view.frame.width, height: 51.0))
        self.tableView.tableFooterView = menuColorsView

        if mode == "create" {
            self.title = "Add List"
        } else if mode == "edit" {
            self.title = "Edit List"
            if let list = list {
                // swiftlint:disable force_unwrapping
                self.menuColorsView!.currentColor = list.color
                let index: Int = self.menuColorsView!.findIndexByColor(list.color!)
                self.menuColorsView?.setSelectedIndex(index)
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        self.name?.becomeFirstResponder()
    }

    @objc func cancel(_ button: UIButton) {
        self.name?.resignFirstResponder()
        self.dismiss(animated: true, completion: nil)
    }

    @objc func save(_ button: UIButton) {
        if mode == "create" {
            createList()
        } else if mode == "edit" {
            saveList()
        }
    }

    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath) {
        if let textFieldCell: TLITextFieldCell = cell as? TLITextFieldCell {
            if indexPath.row == 0 {
                if list != nil {
                    textFieldCell.textField?.text = list?.title
                } else {
                    textFieldCell.textField?.text = ""
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: TLITextFieldCell = TLITextFieldCell(
            style: UITableViewCellStyle.default,
            reuseIdentifier: "CellIdentifier")
        configureCell(cell, indexPath: indexPath)
        return cell
    }

    func configureCell(_ cell: TLITextFieldCell, indexPath: IndexPath) {
        if indexPath.row == 0 {
            cell.textField?.placeholder = "Name"
            cell.backgroundColor = UIColor.white
            cell.textField?.returnKeyType = UIReturnKeyType.go
            cell.textField?.delegate = self
            name = cell.textField
            return
        }
    }

    // MARK: UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.name {
            if mode == "create" {
                createList()
            } else if mode == "edit" {
                saveList()
            }
        }
        return false
    }

    func saveList() {
        if list != nil {
            list?.title = self.name!.text
            list?.color = self.menuColorsView!.currentColor!
            // swiftlint:disable force_try
            try! managedObjectContext.save()
            self.name?.resignFirstResponder()
            self.dismiss(animated: true, completion: nil)
        }
    }

    func createList() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "List")
        let positionDescriptor  = NSSortDescriptor(key: "position", ascending: false)
        fetchRequest.sortDescriptors = [positionDescriptor]
        fetchRequest.fetchLimit = 1

        do {
            var position: Int = 0
            if let results = try managedObjectContext.fetch(fetchRequest) as? [TLIList] {
                if results.isEmpty {
                    position = 0
                } else {
                    if let pos = results[0].position {
                        position = pos.intValue
                    }
                }
            }

            if let list: TLIList = NSEntityDescription.insertNewObject(
                forEntityName: "List",
                into: managedObjectContext) as? TLIList {
                if let name = self.name {
                    list.title = name.text
                }
                list.position = position + 1 as NSNumber
                if let menuColorsView = self.menuColorsView,
                    let currentColor = menuColorsView.currentColor {
                    list.color = currentColor
                }
                list.createdAt = Date()
                try! managedObjectContext.save()
                self.name?.resignFirstResponder()
                self.dismiss(animated: true, completion: { () -> Void in
                    self.delegate?.onClose(self, list: list)
                    return
                })
            }
        } catch let error as NSError {
            fatalError(error.localizedDescription)
        }
    }
}
