//
//  TasksViewController.swift
//  Tinylog
//
//  Created by Spiros Gerokostas on 18/10/15.
//  Copyright © 2015 Spiros Gerokostas. All rights reserved.
//
// swiftlint:disable force_unwrapping
import UIKit
import TTTAttributedLabel
// Consider refactoring the code to use the non-optional operators.
private func < <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}
// Consider refactoring the code to use the non-optional operators.
private func > <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}

class TasksViewController: CoreDataTableViewController,
    AddTaskViewDelegate,
    TTTAttributedLabelDelegate,
    EditTaskViewControllerDelegate {

    let kCellIdentifier = "CellIdentifier"
    var managedObjectContext: NSManagedObjectContext!
    var list: TLIList?
    var offscreenCells: NSMutableDictionary?
    var estimatedRowHeightCache: NSMutableDictionary?
    var currentIndexPath: IndexPath?
    var focusTextField: Bool?

    var topConstraint: NSLayoutConstraint?
    var heightConstraint: NSLayoutConstraint?

    var tasksFooterView: TasksFooterView? = {
        let tasksFooterView = TasksFooterView.newAutoLayout()
        return tasksFooterView
    }()

    var orientation: String = "portrait"
    var enableDidSelectRowAtIndexPath = true
    var didSetupContraints = false

    lazy var addTransparentLayer: UIView? = {
        let addTransparentLayer: UIView = UIView.newAutoLayout()
        addTransparentLayer.autoresizingMask = [
            UIView.AutoresizingMask.flexibleWidth,
            UIView.AutoresizingMask.flexibleBottomMargin]
        addTransparentLayer.backgroundColor = UIColor(white: 1.0, alpha: 0.9)
        addTransparentLayer.alpha = 0.0
        let tapGestureRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(TasksViewController.transparentLayerTapped(_:)))
        addTransparentLayer.addGestureRecognizer(tapGestureRecognizer)
        return addTransparentLayer
    }()

    lazy var noTasksLabel: UILabel? = {
        let noTasksLabel: UILabel = UILabel.newAutoLayout()
        noTasksLabel.font = UIFont.regularFontWithSize(18.0)
        noTasksLabel.textColor = UIColor.tinylogTextColor
        noTasksLabel.text = "Tap text field to create a new task."
        noTasksLabel.isHidden = true
        return noTasksLabel
    }()

    lazy var noListSelected: UILabel? = {
        let noListSelected: UILabel = UILabel.newAutoLayout()
        noListSelected.font = UIFont.regularFontWithSize(16.0)
        noListSelected.textColor = UIColor.tinylogTextColor
        noListSelected.textAlignment = NSTextAlignment.center
        noListSelected.text = "No List Selected"
        noListSelected.sizeToFit()
        noListSelected.isHidden = true
        return noListSelected
    }()

    lazy var addTaskView: AddTaskView? = {
        let header: AddTaskView = AddTaskView(
            frame: CGRect(
                x: 0.0,
                y: 0.0,
                width: self.tableView!.bounds.size.width,
                height: AddTaskView.height()))
        header.closeButton?.addTarget(
            self,
            action: #selector(TasksViewController.transparentLayerTapped(_:)),
            for: UIControl.Event.touchDown)
        header.delegate = self
        return header
    }()

    func getDetailViewSize() -> CGSize {
        var detailViewController: UIViewController
        if self.splitViewController?.viewControllers.count > 1 {
            detailViewController = (self.splitViewController?.viewControllers[1])!
        } else {
            detailViewController = (self.splitViewController?.viewControllers[0])!
        }
        return detailViewController.view.frame.size
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: Bundle!) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    var managedObject: TLIList? {
        willSet {

            if newValue != nil {
                self.noListSelected?.isHidden = true
            } else {
                self.noListSelected?.isHidden = false
            }

            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Task")
            let positionDescriptor  = NSSortDescriptor(key: "position", ascending: false)
            let displayLongTextDescriptor  = NSSortDescriptor(key: "displayLongText", ascending: true)
            fetchRequest.sortDescriptors = [positionDescriptor, displayLongTextDescriptor]
            fetchRequest.predicate  = NSPredicate(format: "list = %@ AND archivedAt = nil", newValue!)
            fetchRequest.fetchBatchSize = 20
            self.frc = NSFetchedResultsController(
                fetchRequest: fetchRequest,
                managedObjectContext: managedObjectContext,
                sectionNameKeyPath: nil,
                cacheName: nil)
            self.frc?.delegate = self

            do {
                try self.frc?.performFetch()
                self.tableView?.reloadData()
                if self.checkForEmptyResults() {
                    self.noTasksLabel?.isHidden = false
                } else {
                    self.noTasksLabel?.isHidden = true
                }
                self.tableView?.reloadData()
                updateFooterInfoText(newValue!)
            } catch let error as NSError {
                fatalError(error.localizedDescription)
            }
        }
        didSet {
        }
    }

    func configureFetch() {

        if list == nil {
            return
        }

        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Task")
        let positionDescriptor  = NSSortDescriptor(key: "position", ascending: false)
        let displayLongTextDescriptor  = NSSortDescriptor(key: "displayLongText", ascending: true)
        fetchRequest.sortDescriptors = [positionDescriptor, displayLongTextDescriptor]
        fetchRequest.predicate  = NSPredicate(format: "list = %@ AND archivedAt = nil", self.list!)
        fetchRequest.fetchBatchSize = 20
        self.frc = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        self.frc?.delegate = self

        do {
            try self.frc?.performFetch()
        } catch let error as NSError {
            fatalError(error.localizedDescription)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.tinylogLightGray
        self.tableView?.backgroundColor = UIColor.tinylogLightGray
        self.tableView?.separatorColor = UIColor(named: "tableViewSeparator")
        self.tableView?.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        self.tableView?.register(TaskTableViewCell.self, forCellReuseIdentifier: kCellIdentifier)
        self.tableView?.rowHeight = UITableView.automaticDimension
        self.tableView?.estimatedRowHeight = GenericTableViewCell.cellHeight
        self.tableView?.frame = CGRect(
            x: 0.0,
            y: 0.0,
            width: self.view.frame.size.width,
            height: self.view.frame.size.height - 50.0)
        self.tableView?.tableFooterView = UIView()

        tasksFooterView?.exportTasksButton?.addTarget(
            self,
            action: #selector(TasksViewController.exportTasks(_:)),
            for: UIControl.Event.touchDown)
        tasksFooterView?.archiveButton?.addTarget(
            self,
            action: #selector(TasksViewController.displayArchive(_:)),
            for: UIControl.Event.touchDown)

        let IS_IPAD = (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad)

        if IS_IPAD {
            self.title = managedObject?.title
        } else {
            self.title = list?.title
            configureFetch()
            updateFooterInfoText(list!)
        }

        setEditing(false, animated: false)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(TasksViewController.onChangeSize(_:)),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(TasksViewController.syncActivityDidEndNotification(_:)),
            name: NSNotification.Name.IDMSyncActivityDidEnd,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(TasksViewController.syncActivityDidBeginNotification(_:)),
            name: NSNotification.Name.IDMSyncActivityDidBegin,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(TasksViewController.appBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(TasksViewController.updateFonts),
            name: NSNotification.Name(
                rawValue: Notifications.fontDidChangeNotification),
            object: nil)
    }

    @objc func updateFonts() {
        self.tableView?.reloadData()
    }

    @objc func appBecomeActive() {
        startSync()
    }

    func startSync() {
        let syncManager: TLISyncManager = TLISyncManager.shared()
        if syncManager.canSynchronize() {
            syncManager.synchronize { (_) -> Void in
            }
        }
    }

    func updateFooterInfoText(_ list: TLIList) {
        //Fetch all objects from list

        let fetchRequestTotal: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Task")
        let positionDescriptor  = NSSortDescriptor(key: "position", ascending: false)
        fetchRequestTotal.sortDescriptors = [positionDescriptor]
        fetchRequestTotal.predicate  = NSPredicate(format: "archivedAt = nil AND list = %@", list)
        fetchRequestTotal.fetchBatchSize = 20

        do {
            let results: NSArray = try managedObjectContext.fetch(fetchRequestTotal) as NSArray

            let fetchRequestCompleted: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(
                entityName: "Task")
            fetchRequestCompleted.sortDescriptors = [positionDescriptor]
            fetchRequestCompleted.predicate  = NSPredicate(
                format: "archivedAt = nil AND completed = %@ AND list = %@",
                NSNumber(value: false as Bool), list)
            fetchRequestCompleted.fetchBatchSize = 20
            let resultsCompleted: NSArray = try managedObjectContext.fetch(fetchRequestCompleted) as NSArray

            let total: Int = results.count - resultsCompleted.count

            if total == results.count {
                tasksFooterView?.updateInfoLabel("All tasks completed")
            } else {
                if total > 1 {
                    tasksFooterView?.updateInfoLabel("\(total) completed tasks")
                } else {
                    tasksFooterView?.updateInfoLabel("\(total) completed task")
                }
            }
        } catch let error as NSError {
            fatalError(error.localizedDescription)
        }
    }

    @objc func syncActivityDidEndNotification(_ notification: Notification) {
        if TLISyncManager.shared().canSynchronize() {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            if self.checkForEmptyResults() {
                self.noTasksLabel?.isHidden = false
            } else {
                self.noTasksLabel?.isHidden = true
            }
            self.tableView?.reloadData()

            let IS_IPAD = (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad)

            if IS_IPAD {
                if let list = self.managedObject {
                    updateFooterInfoText(list)
                }
            } else {
                if let list = self.list {
                    updateFooterInfoText(list)
                }
            }
        }
    }

    @objc func syncActivityDidBeginNotification(_ notification: Notification) {
        if TLISyncManager.shared().canSynchronize() {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            if self.checkForEmptyResults() {
                self.noTasksLabel?.isHidden = false
            } else {
                self.noTasksLabel?.isHidden = true
            }
            self.tableView?.reloadData()
        }
    }

    override func loadView() {
        super.loadView()

        view.addSubview(noListSelected!)
        view.addSubview(noTasksLabel!)
        view.addSubview(tasksFooterView!)
        view.addSubview(addTransparentLayer!)

        view.setNeedsUpdateConstraints()
    }

    override func updateViewConstraints() {

        if !didSetupContraints {

            noListSelected?.autoCenterInSuperview()
            noTasksLabel?.autoCenterInSuperview()

            tasksFooterView?.autoMatch(.width, to: .width, of: self.view)
            tasksFooterView?.autoSetDimension(.height, toSize: 51.0)
            tasksFooterView?.autoPinEdge(toSuperviewEdge: .left)
            tasksFooterView?.autoPinEdge(toSuperviewEdge: .bottom)

            addTransparentLayer?.autoMatch(.width, to: .width, of: self.view)

            didSetupContraints = true
        }

        topConstraint?.autoRemove()
        heightConstraint?.autoRemove()

        let posY: CGFloat = AddTaskView.height() + topDistance

        topConstraint = addTransparentLayer?.autoPinEdge(toSuperviewEdge: .top, withInset: posY)
        heightConstraint = addTransparentLayer?.autoMatch(
            .height,
            to: .height,
            of: self.view,
            withOffset: -51.0 - posY)

        super.updateViewConstraints()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.checkForEmptyResults() {
            self.noTasksLabel?.isHidden = false
        } else {
            self.noTasksLabel?.isHidden = true
        }
        self.tableView?.reloadData()

        let IS_IPAD = (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad)

        if IS_IPAD {
            self.noListSelected?.isHidden = false
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        setEditing(false, animated: false)
    }

    @objc func displayArchive(_ button: ArchiveButton) {
        let viewController: ArchiveTasksViewController = ArchiveTasksViewController()
        viewController.managedObjectContext = managedObjectContext

        let IS_IPAD = (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad)

        if IS_IPAD {
            viewController.list = managedObject
        } else {
            viewController.list = list
        }

        let nc: UINavigationController = UINavigationController(rootViewController: viewController)
        nc.modalPresentationStyle = UIModalPresentationStyle.formSheet
        self.navigationController?.present(nc, animated: true, completion: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if focusTextField != nil {
            self.addTaskView?.textField?.becomeFirstResponder()
            focusTextField = false
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if UIDevice.current.orientation.isLandscape {
            self.orientation = "landscape"
        }
        if UIDevice.current.orientation.isPortrait {
            self.orientation = "portrait"
        }
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Code here will execute before the rotation begins.
        // Equivalent to placing it in the deprecated method -[willRotateToInterfaceOrientation:duration:]
        coordinator.animate(alongsideTransition: { (_) -> Void in
            // Place code here to perform animations during the rotation.
            // You can pass nil for this closure if not necessary.
            }, completion: { (_) -> Void in
                self.tableView?.reloadData()
                self.view.setNeedsUpdateConstraints()
        })
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if editing {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Done",
                style: UIBarButtonItem.Style.plain,
                target: self,
                action: #selector(TasksViewController.toggleEditMode(_:)))
        } else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Edit",
                style: UIBarButtonItem.Style.plain,
                target: self,
                action: #selector(TasksViewController.toggleEditMode(_:)))
        }
    }

    @objc func toggleEditMode(_ sender: UIBarButtonItem) {
        setEditing(!isEditing, animated: true)
    }

    func tableView(_ tableView: UITableView,
                   editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let archiveRowAction = UITableViewRowAction(
            style: UITableViewRowAction.Style.default,
            title: "Archive",
            handler: {_, indexpath in
                if let task: TLITask = self.frc?.object(at: indexpath) as? TLITask {
                    task.archivedAt = Date()
                    // Update counter list
                    // Fetch all objects from list
                    let fetchRequestTotal: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(
                        entityName: "Task")
                    let positionDescriptor  = NSSortDescriptor(key: "position", ascending: false)
                    fetchRequestTotal.sortDescriptors = [positionDescriptor]
                    fetchRequestTotal.predicate  = NSPredicate(
                        format: "archivedAt = nil AND list = %@", task.list!)
                    fetchRequestTotal.fetchBatchSize = 20
                    do {
                        let results: NSArray = try self.managedObjectContext.fetch(fetchRequestTotal)
                            as NSArray
                        let fetchRequestCompleted: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(
                            entityName: "Task")
                        fetchRequestCompleted.sortDescriptors = [positionDescriptor]
                        fetchRequestCompleted.predicate  = NSPredicate(
                            format: "archivedAt = nil AND completed = %@ AND list = %@",
                            NSNumber(value: true as Bool), task.list!)
                        fetchRequestCompleted.fetchBatchSize = 20
                        let resultsCompleted: NSArray = try self.managedObjectContext.fetch(
                            fetchRequestCompleted) as NSArray
                        let total: Int = results.count - resultsCompleted.count
                        task.list!.total = total as NSNumber?
                        try self.managedObjectContext.save()
                        self.setEditing(false, animated: true)
                        if self.checkForEmptyResults() {
                            self.noTasksLabel?.isHidden = false
                        } else {
                            self.noTasksLabel?.isHidden = true
                        }
                        self.tableView?.reloadData()
                    } catch let error as NSError {
                        fatalError(error.localizedDescription)
                    }
                }
        })
        archiveRowAction.backgroundColor = UIColor.tinylogMainColor
        return [archiveRowAction]
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func taskAtIndexPath(_ indexPath: IndexPath) -> TLITask? {
        if let task = self.frc?.object(at: indexPath) as? TLITask {
            return task
        }
        return nil
    }
    // swiftlint:disable force_cast
    func updateTask(_ task: TLITask, sourceIndexPath: IndexPath, destinationIndexPath: IndexPath) {
        var fetchedTasks: [AnyObject] = (self.frc?.fetchedObjects)!

        // Remove current list item

        fetchedTasks = fetchedTasks.filter { $0 as! TLITask != task }

        var sortedIndex = destinationIndexPath.row

        for sectionIndex in 0..<destinationIndexPath.section {
            sortedIndex += (self.frc?.sections?[sectionIndex].numberOfObjects)!

            if sectionIndex == sourceIndexPath.section {
                sortedIndex -= 1
            }
        }

        fetchedTasks.insert(task, at: sortedIndex)

        for(index, task) in fetchedTasks.enumerated() {
            let tmpTask = task as! TLITask
            tmpTask.position = fetchedTasks.count-index as NSNumber
        }
    }

    func tableView(_ tableView: UITableView,
                   moveRowAt sourceIndexPath: IndexPath,
                   to destinationIndexPath: IndexPath) {
        if sourceIndexPath.row == destinationIndexPath.row {
            return
        }

        // Disable fetched results controller

        self.ignoreNextUpdates = true
        let task = self.taskAtIndexPath(sourceIndexPath)!
        updateTask(task, sourceIndexPath: sourceIndexPath, destinationIndexPath: destinationIndexPath)
        // swiftlint:disable force_try
        try! managedObjectContext.save()
    }

    @objc func onChangeSize(_ notification: Notification) {
        self.tableView?.reloadData()
    }

    override func configureCell(_ cell: UITableViewCell, atIndexPath indexPath: IndexPath) {
        let task: TLITask = self.frc?.object(at: indexPath) as! TLITask

            let taskTableViewCell: TaskTableViewCell = cell as! TaskTableViewCell
            taskTableViewCell.managedObjectContext = managedObjectContext
            taskTableViewCell.currentTask = task

    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if enableDidSelectRowAtIndexPath {
            return self.addTaskView
        }
        return nil
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if enableDidSelectRowAtIndexPath {
            return AddTaskView.height()
        }
        return 0
    }

    func tableView(_ tableView: UITableView,
                   estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return floor(getEstimatedCellHeightFromCache(indexPath, defaultHeight: 52)!)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell: TaskTableViewCell = tableView.dequeueReusableCell(
                withIdentifier: kCellIdentifier) as! TaskTableViewCell
            cell.selectionStyle = UITableViewCell.SelectionStyle.none
            cell.checkBoxButton.addTarget(
                self,
                action: #selector(TasksViewController.toggleComplete(_:)),
                for: UIControl.Event.touchUpInside)
            cell.taskLabel.delegate = self
            configureCell(cell, atIndexPath: indexPath)

            let height = isEstimatedRowHeightInCache(indexPath)
            if height != nil {
                let cellSize: CGSize = cell.systemLayoutSizeFitting(
                    CGSize(width: self.view.frame.size.width, height: 0),
                    withHorizontalFittingPriority: UILayoutPriority(rawValue: 1000),
                    verticalFittingPriority: UILayoutPriority(rawValue: 52))
                putEstimatedCellHeightToCache(indexPath, height: cellSize.height)
            }
            return cell

    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if enableDidSelectRowAtIndexPath {

            let task: TLITask = self.frc?.object(at: indexPath) as! TLITask

            DispatchQueue.main.async {
                self.editTask(task, indexPath: indexPath)
            }
        }
    }

    @objc func toggleComplete(_ button: CheckBoxButton) {
        if enableDidSelectRowAtIndexPath {

            let button: CheckBoxButton = button as CheckBoxButton
            let indexPath: IndexPath?  = self.tableView?.indexPath(for: button.tableViewCell!)!

            if !(indexPath != nil) {
                return
            }

            let task: TLITask = self.frc?.object(at: indexPath!) as! TLITask

            if task.completed!.boolValue {
                task.completed = NSNumber(value: false as Bool)
                task.checkBoxValue = "false"
                task.completedAt = nil
            } else {
                task.completed = NSNumber(value: true as Bool)
                task.checkBoxValue = "true"
                task.completedAt = Date()
            }

            task.updatedAt = Date()

            let animation: CABasicAnimation = CABasicAnimation(keyPath: "transform.scale")
            animation.fromValue = NSNumber(value: 1.4 as Float)
            animation.toValue = NSNumber(value: 1.0 as Float)
            animation.duration = 0.2
            animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 1.3, 1, 1)
            button.layer.add(animation, forKey: "bounceAnimation")

            try! managedObjectContext.save()

            let IS_IPAD = (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad)

            if IS_IPAD {
                updateFooterInfoText(self.managedObject!)
            } else {
                updateFooterInfoText(self.list!)
            }
        }
    }

    // MARK: TLIAddTaskViewDelegate
    func addTaskViewDidBeginEditing(_ addTaskView: AddTaskView) {
        displayTransparentLayer()
    }

    func addTaskViewDidEndEditing(_ addTaskView: AddTaskView) {
        hideTransparentLayer()
    }

    func addTaskView(_ addTaskView: AddTaskView, title: NSString) {

        do {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Task")
            let positionDescriptor  = NSSortDescriptor(key: "position", ascending: false)

            let IS_IPAD = (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad)

            if IS_IPAD {
                fetchRequest.predicate = NSPredicate(format: "list = %@", self.managedObject!)
            } else {
                fetchRequest.predicate = NSPredicate(format: "list = %@", self.list!)
            }

            fetchRequest.sortDescriptors = [positionDescriptor]
            let results: NSArray = try managedObjectContext.fetch(fetchRequest) as NSArray

            if let task: TLITask = NSEntityDescription.insertNewObject(
                forEntityName: "Task",
                into: managedObjectContext) as? TLITask {
                task.displayLongText = title as String
                if IS_IPAD {
                    task.list = self.managedObject!
                } else {
                    task.list = self.list!
                }
                task.position = NSNumber(value: results.count + 1 as Int)
                task.createdAt = Date()
                task.checkBoxValue = "false"
                task.completed = false
                // swiftlint:disable force_try
                try! managedObjectContext.save()
                if self.checkForEmptyResults() {
                    self.noTasksLabel?.isHidden = false
                } else {
                    self.noTasksLabel?.isHidden = true
                }
                self.tableView?.reloadData()
                if IS_IPAD {
                    updateFooterInfoText(self.managedObject!)
                } else {
                    updateFooterInfoText(self.list!)
                }
            }
        } catch let error as NSError {
            fatalError(error.localizedDescription)
        }
    }

    func displayTransparentLayer() {
        self.tableView?.isScrollEnabled = false
        let addTransparentLayer: UIView = self.addTransparentLayer!
        UIView.animate(withDuration: 0.3, delay: 0.0,
            options: .allowUserInteraction, animations: {
                addTransparentLayer.alpha = 1.0
            }, completion: nil)
    }

    func hideTransparentLayer() {
        self.tableView?.isScrollEnabled = true
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: UIView.AnimationOptions.allowUserInteraction,
            animations: {
                self.addTransparentLayer!.alpha = 0.0
            }, completion: { finished in
                if finished {
                    //self.addTransparentLayer?.removeFromSuperview()
                }
        })
    }

    // MARK: TTTAttributedLabelDelegate

    func attributedLabel(_ label: TTTAttributedLabel!, didSelectLinkWith url: URL!) {
        if url.scheme == "http" {
            let path: URL = URL(string: NSString(format: "http://%@", url.host!) as String)!
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(path,
                                          options: [:],
                                          completionHandler: nil)
            } else {
                UIApplication.shared.openURL(path)
            }
        }
    }

    @objc func transparentLayerTapped(_ gesture: UITapGestureRecognizer) {
        self.addTaskView?.textField?.resignFirstResponder()
    }

    // MARK: Edit Task
    func editTask(_ task: TLITask, indexPath: IndexPath) {
        let editTaskViewController: EditTaskViewController = EditTaskViewController()
        editTaskViewController.managedObjectContext = managedObjectContext
        editTaskViewController.task = task
        editTaskViewController.indexPath = indexPath
        editTaskViewController.delegate = self
        let nc: UINavigationController = UINavigationController(rootViewController: editTaskViewController)
        nc.modalPresentationStyle = UIModalPresentationStyle.formSheet
        self.navigationController?.present(nc, animated: true, completion: nil)
    }

    func putEstimatedCellHeightToCache(_ indexPath: IndexPath, height: CGFloat) {
        initEstimatedRowHeightCacheIfNeeded()
        estimatedRowHeightCache?.setValue(height, forKey: NSString(format: "%ld", indexPath.row) as String)
    }

    func initEstimatedRowHeightCacheIfNeeded() {
        if estimatedRowHeightCache == nil {
            estimatedRowHeightCache = NSMutableDictionary()
        }
    }

    func getEstimatedCellHeightFromCache(_ indexPath: IndexPath, defaultHeight: CGFloat) -> CGFloat? {
        initEstimatedRowHeightCacheIfNeeded()

        let height: CGFloat? = estimatedRowHeightCache!.value(
            forKey: NSString(format: "%ld", indexPath.row) as String) as? CGFloat

        if height != nil {
            return height
        }

        return defaultHeight
    }

    func isEstimatedRowHeightInCache(_ indexPath: IndexPath) -> Bool? {
        let value = getEstimatedCellHeightFromCache(indexPath, defaultHeight: 0)
        if value > 0 {
            return true
        }
        return false
    }

    func tableViewReloadData() {
        estimatedRowHeightCache = NSMutableDictionary()
        self.tableView?.reloadData()
    }

    func onClose(_ editTaskViewController: EditTaskViewController, indexPath: IndexPath) {
        self.currentIndexPath = indexPath
        self.tableView?.reloadData()
    }

    @objc func exportTasks(_ sender: UIButton) {
        if self.managedObject != nil || self.list != nil {

            do {

                let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Task")
                let positionDescriptor  = NSSortDescriptor(key: "position", ascending: false)
                let displayLongTextDescriptor  = NSSortDescriptor(key: "displayLongText", ascending: true)
                fetchRequest.sortDescriptors = [positionDescriptor, displayLongTextDescriptor]

                let IS_IPAD = (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad)

                if IS_IPAD {
                    fetchRequest.predicate = NSPredicate(format: "list = %@", self.managedObject!)
                } else {
                    fetchRequest.predicate = NSPredicate(format: "list = %@", self.list!)
                }

                fetchRequest.fetchBatchSize = 20
                let tasks: NSArray = try managedObjectContext.fetch(fetchRequest) as NSArray

                var output: NSString = ""
                var listTitle: NSString = ""

                if IS_IPAD {
                    listTitle = self.managedObject!.title! as NSString
                } else {
                    listTitle = self.list!.title! as NSString
                }

                output = output.appending(NSString(format: "%@\n", listTitle) as String) as NSString

                for task in tasks {
                    let taskItem: TLITask = task as! TLITask
                    let displayLongText: NSString = NSString(format: "- %@\n", taskItem.displayLongText!)
                    output = output.appending(displayLongText as String) as NSString
                }

                let activityViewController: UIActivityViewController = UIActivityViewController(
                    activityItems: [output], applicationActivities: nil)
                activityViewController.excludedActivityTypes = [
                    UIActivity.ActivityType.postToTwitter,
                    UIActivity.ActivityType.postToFacebook,
                    UIActivity.ActivityType.postToWeibo,
                    UIActivity.ActivityType.copyToPasteboard,
                    UIActivity.ActivityType.assignToContact,
                    UIActivity.ActivityType.saveToCameraRoll,
                    UIActivity.ActivityType.addToReadingList,
                    UIActivity.ActivityType.postToFlickr,
                    UIActivity.ActivityType.postToVimeo,
                    UIActivity.ActivityType.postToTencentWeibo
                ]

                activityViewController.modalPresentationStyle = UIModalPresentationStyle.popover
                activityViewController.popoverPresentationController?.sourceRect = sender.bounds
                activityViewController.popoverPresentationController?.sourceView = sender
                activityViewController.popoverPresentationController?.permittedArrowDirections
                    = UIPopoverArrowDirection.any

                self.navigationController?.present(
                    activityViewController, animated: true, completion: nil)
            } catch let error as NSError {
                fatalError(error.localizedDescription)
            }
        }
    }
}