//
//  FastisController.swift
//  Fastis
//
//  Created by Ilya Kharlamov on 10.04.2020.
//  Copyright © 2020 DIGITAL RETAIL TECHNOLOGIES, S.L. All rights reserved.
//

import JTAppleCalendar
import UIKit

/**
 Main controller of Fastis framework. Use it to create and present dade picker

 Usage example:
 ```swift
 let fastisController = FastisController(mode: .range)
 fastisController.title = "Choose range"
 fastisController.maximumDate = Date()
 fastisController.allowToChooseNilDate = true
 fastisController.shortcuts = [.today, .lastWeek]
 fastisController.dismissHandler = { [weak self] action in
     switch action {
     case .done(let newValue):
        ...
     case .cancel:
        ...
     }
 }
 fastisController.present(above: self)
 ```

 **Single and range modes**

 If you want to get a single date you have to use `Date` type:

 ```swift
 let fastisController = FastisController(mode: .single)
 fastisController.initialValue = Date()
 fastisController.closeOnSelectionImmediately = true
 fastisController.dismissHandler = { [weak self] action in
     switch action {
     case .done(let resultDate):
        print(resultDate) // resultDate is Date
     case .cancel:
        ...
     }
 }
 ```

 If you want to get a date range you have to use `FastisRange` type:

 ```swift
 let fastisController = FastisController(mode: .range)
 fastisController.initialValue = FastisRange(from: Date(), to: Date()) // or .from(Date(), to: Date())
 fastisController.dismissHandler = { [weak self] action in
     switch action {
     case .done(let resultRange):
        print(resultRange) // resultRange is FastisRange
     case .cancel:
        ...
     }
 }
 ```
 */

open class FastisController<Value: FastisValue>: UIViewController, JTACMonthViewDelegate, JTACMonthViewDataSource {

    // MARK: - Outlets

    private lazy var cancelBarButtonItem: UIBarButtonItem = {
        if let customButton = self.appearance.customCancelButton {
            customButton.target = self
            customButton.action = #selector(self.cancel)
            return customButton
        }

        let barButtonItem = UIBarButtonItem(
            title: self.appearance.cancelButtonTitle,
            style: .plain,
            target: self,
            action: #selector(self.cancel)
        )
        barButtonItem.tintColor = self.appearance.barButtonItemsColor
        return barButtonItem
    }()

    private lazy var doneBarButtonItem: UIBarButtonItem = {
        if let customButton = self.appearance.customDoneButton {
            customButton.target = self
            customButton.action = #selector(self.done)
            return customButton
        }

        let barButtonItem = UIBarButtonItem(
            title: self.appearance.doneButtonTitle,
            style: .done,
            target: self,
            action: #selector(self.done)
        )
        barButtonItem.tintColor = self.appearance.barButtonItemsColor
        barButtonItem.isEnabled = self.allowToChooseNilDate
        return barButtonItem
    }()

    private lazy var calendarView: JTACMonthView = {
        let monthView = JTACMonthView()
        monthView.translatesAutoresizingMaskIntoConstraints = false
        monthView.backgroundColor = self.appearance.backgroundColor
        monthView.ibCalendarDelegate = self
        monthView.ibCalendarDataSource = self
        monthView.minimumLineSpacing = 2
        monthView.minimumInteritemSpacing = 0
        monthView.showsVerticalScrollIndicator = false
        monthView.cellSize = 46
        monthView.allowsMultipleSelection = Value.mode == .range
        monthView.allowsRangedSelection = true
        monthView.rangeSelectionMode = .continuous
        monthView.contentInsetAdjustmentBehavior = .always
        return monthView
    }()

    private lazy var weekView: WeekView = {
        let view = WeekView(calendar: self.config.calendar, config: self.config.weekView, localIdentifier: self.localIdentifier?.identifier)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var currentValueView: CurrentValueView<Value> = {
        let view = CurrentValueView<Value>(config: self.config.currentValueView)
        view.currentValue = self.value
        view.typeCalendar = self.typeCalendar
        view.localIdentifier = self.localIdentifier
        view.translatesAutoresizingMaskIntoConstraints = false
        view.onClear = { [weak self] in
            self?.clear()
        }
        return view
    }()

    private lazy var shortcutContainerView: ShortcutContainerView<Value> = {
        let view = ShortcutContainerView<Value>(
            config: self.config.shortcutContainerView,
            itemConfig: self.config.shortcutItemView,
            shortcuts: self.shortcuts
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        if let value = self.value {
            view.selectedShortcut = self.shortcuts.first(where: { $0.isEqual(to: value) })
        }
        view.onSelect = { [weak self] selectedShortcut in
            guard let self else { return }
            let newValue = selectedShortcut.action()
            if !newValue.outOfRange(minDate: self.privateMinimumDate, maxDate: self.privateMaximumDate) {
                self.value = newValue
                self.selectValue(newValue, in: self.calendarView)
            }
        }
        return view
    }()

    // MARK: - Variables

    private let config: FastisConfig
    private var appearance: FastisConfig.Controller = FastisConfig.default.controller
    private let dayCellReuseIdentifier = "DayCellReuseIdentifier"
    private let monthHeaderReuseIdentifier = "MonthHeaderReuseIdentifier"
    private var viewConfigs: [IndexPath: DayCell.ViewConfig] = [:]
    private var privateMinimumDate: Date?
    private var privateMaximumDate: Date?
    private var privateSelectMonthOnHeaderTap = false
    private var dayFormatter = DateFormatter()
    private var value: Value? {
        didSet {
            self.updateSelectedShortcut()
            self.currentValueView.currentValue = self.value
            self.currentValueView.typeCalendar = self.typeCalendar
            self.currentValueView.localIdentifier = self.localIdentifier
            self.doneBarButtonItem.isEnabled = self.allowToChooseNilDate || self.value != nil
        }
    }

    private var isDone = false
    private var privateCloseOnSelectionImmediately = false

    /**
     Shortcuts array

     You can use prepared shortcuts depending on the current mode.

     - For `.single` mode: `.today`, `.tomorrow`, `.yesterday`
     - For `.range` mode: `.today`, `.lastWeek`, `.lastMonth`

     Or you can create your own shortcuts:

     ```
     var customShortcut = FastisShortcut(name: "Today") {
         let now = Date()
         return FastisRange(from: now.startOfDay(), to: now.endOfDay())
     }
     ```
     */
     public var shortcuts: [FastisShortcut<Value>] = []
     public var minimumMonthDate: Int?
     public var maximumMonthDate: Int?
     public var typeCalendar: Calendar?
     public var localIdentifier: Locale?
     public var dateSelected: Date?
     public var dayNumber: Int?



    /**
     Allow to choose `nil` date

     When `allowToChooseNilDate` is `true`:
     * "Done" button will be always enabled
     * You will be able to reset selection by you tapping on selected date again
     */
    public var allowToChooseNilDate = false

    /**
     The block to execute after the dismissal finishes, return two variable .done(FastisValue?) and .cancel
     */
    public var dismissHandler: ((DismissAction) -> Void)?

    /**
     The block to execute after "Done" button will be tapped
     */
    @available(*, unavailable, message: "use dismissHandler: ((DismissAction) -> Void)?")
    public var doneHandler: ((Value?) -> Void)? {
        get { nil }
        // swiftlint:disable:next unused_setter_value
        set { }
    }

    /**
     And initial value which will be selected by default
     */
    public var initialValue: Value?

    /**
     Minimal selection date. Dates less then current will be marked as unavailable
     */
    public var minimumDate: Date? {
        get {
            self.privateMinimumDate
        }
        set {
            self.privateMinimumDate = newValue?.startOfDay()
        }
    }

    /**
     Allow date range changes

     Set this variable to `false` if you want to disable date range changes.
     Next tap after selecting range will start new range selection.
     */
    public var allowDateRangeChanges = true

    /**
     Maximum selection date. Dates greater then current will be marked as unavailable
     */
    public var maximumDate: Date? {
        get {
            self.privateMaximumDate
        }
        set {
            self.privateMaximumDate = newValue?.endOfDay()
        }
    }

    // MARK: - Lifecycle

    /// Initiate FastisController
    /// - Parameter config: Configuration parameters
    public init(config: FastisConfig = .default) {
        self.config = config
        self.appearance = config.controller
        self.dayFormatter.calendar = typeCalendar
        self.dayFormatter.locale = localIdentifier?.identifier == "ar_EG" ? Locale(identifier: "ar_EG") : config.calendar.locale
        self.dayFormatter.dateFormat = "d"
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.configureUI()
        self.configureSubviews()
        self.configureConstraints()
        self.configureInitialState()
    }

    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if self.isDone {
            self.dismissHandler?(.done(self.value))
        } else {
            self.dismissHandler?(.cancel)
        }

    }

    /**
     Present FastisController above current top view controller

     - Parameters:
        - viewController: view controller which will present FastisController
        - flag: Pass true to animate the presentation; otherwise, pass false.
        - completion: The block to execute after the presentation finishes. This block has no return value and takes no parameters. You may specify nil for this parameter.
     */
    public func present(above viewController: UIViewController, animated flag: Bool = true, completion: (() -> Void)? = nil) {
        let navVc = UINavigationController(rootViewController: self)
        navVc.modalPresentationStyle = .formSheet
        if viewController.preferredContentSize != .zero {
            navVc.preferredContentSize = viewController.preferredContentSize
        } else {
            navVc.preferredContentSize = CGSize(width: 445, height: 550)
        }

        viewController.present(navVc, animated: flag, completion: completion)
    }

    // MARK: - Configuration

    private func configureUI() {
        self.view.backgroundColor = self.appearance.backgroundColor
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationItem.leftBarButtonItem = self.cancelBarButtonItem
        self.navigationItem.rightBarButtonItem = self.doneBarButtonItem
    }

    private func configureSubviews() {
        self.calendarView.register(DayCell.self, forCellWithReuseIdentifier: self.dayCellReuseIdentifier)
        self.calendarView.register(
            MonthHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: self.monthHeaderReuseIdentifier
        )
        if !self.privateCloseOnSelectionImmediately {
            self.view.addSubview(self.currentValueView)
        }
        self.weekView.localIdentifier = localIdentifier
        self.view.addSubview(self.weekView)
        self.view.addSubview(self.calendarView)
        if !self.shortcuts.isEmpty {
            self.view.addSubview(self.shortcutContainerView)
        }
    }

    private func configureConstraints() {
        if !self.privateCloseOnSelectionImmediately {
            NSLayoutConstraint.activate([
                self.currentValueView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
                self.currentValueView.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 12),
                self.currentValueView.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -12)
            ])
            NSLayoutConstraint.activate([
                self.weekView.topAnchor.constraint(equalTo: self.currentValueView.bottomAnchor),
                self.weekView.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 12),
                self.weekView.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -12)
            ])
        } else {
            NSLayoutConstraint.activate([
                self.weekView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
                self.weekView.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 12),
                self.weekView.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -12)
            ])
        }
        if !self.shortcuts.isEmpty {
            NSLayoutConstraint.activate([
                self.shortcutContainerView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
                self.shortcutContainerView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
                self.shortcutContainerView.rightAnchor.constraint(equalTo: self.view.rightAnchor)
            ])
        }
        NSLayoutConstraint.activate([
            self.calendarView.topAnchor.constraint(equalTo: self.weekView.bottomAnchor),
            self.calendarView.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 16),
            self.calendarView.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -16)
        ])
        if !self.shortcuts.isEmpty {
            NSLayoutConstraint.activate([
                self.calendarView.bottomAnchor.constraint(equalTo: self.shortcutContainerView.topAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                self.calendarView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            ])
        }
    }

    private func configureInitialState() {
        self.value = self.initialValue
        if let date = self.value as? Date {
            self.calendarView.selectDates([date])
            self.calendarView.scrollToHeaderForDate(date)
        } else if let rangeValue = self.value as? FastisRange {
            self.selectRange(rangeValue, in: self.calendarView)
            self.calendarView.scrollToHeaderForDate(rangeValue.fromDate)
        } else {
            let nowDate = Date()
            let targetDate = self.privateMaximumDate ?? nowDate
            if targetDate < nowDate {
                self.calendarView.scrollToHeaderForDate(targetDate)
            } else {
                self.calendarView.scrollToHeaderForDate(Date())
            }
        }
    }

    private func configureCell(_ cell: JTACDayCell, forItemAt date: Date, cellState: CellState, indexPath: IndexPath) {
        guard let cell = cell as? DayCell else { return }
        if let cachedConfig = self.viewConfigs[indexPath] {
            cell.configure(for: cachedConfig)
        } else {
            cell.localIdentifier = localIdentifier
            var newConfig = DayCell.makeViewConfig(
                for: cellState,
                minimumDate: self.privateMinimumDate,
                maximumDate: self.privateMaximumDate,
                rangeValue: self.value as? FastisRange,
                calendar: self.config.calendar
            )

            if newConfig.dateLabelText != nil {
                if (typeCalendar == Calendar(identifier: .gregorian)) {
                    newConfig.dateLabelText = self.dayFormatter.string(from: date)
                } else {
                    let islamicCalendar = Calendar(identifier: .islamicUmmAlQura)
                    let dayDate = islamicCalendar.component(.day, from: date)
                     newConfig.dateLabelText =  "\(dayDate)"
                }
                /*
                 islamicUmmAlQura
                 let islamicCalendar = Calendar(identifier: .islamicUmmAlQura)
                 let dayDate = islamicCalendar.component(.day, from: date)
                  newConfig.dateLabelText =  "\(dayDate)"
                 */
                /*
                 gregorian
                 self.dayFormatter.string(from: date)
                 */
            }

            if typeCalendar?.isDateInToday(date) ?? false {
                newConfig.isToday = true
            }

            self.viewConfigs[indexPath] = newConfig
            cell.applyConfig(self.config)
            cell.configure(for: newConfig)
        }
    }

    // MARK: - Actions
    private func updateSelectedShortcut() {
        guard !self.shortcuts.isEmpty else { return }
        if let value = self.value {
            self.shortcutContainerView.selectedShortcut = self.shortcuts.first(where: { $0.isEqual(to: value) })
        } else {
            self.shortcutContainerView.selectedShortcut = nil
        }
    }

    @objc
    private func cancel() {
        self.dismiss(animated: true)
    }

    @objc
    private func done() {
        self.isDone = true
        self.dismiss(animated: true)
    }

    private func selectValue(_ value: Value?, in calendar: JTACMonthView) {
        if let date = value as? Date {
            calendar.selectDates([date])
        } else if let range = value as? FastisRange {
            self.selectRange(range, in: calendar)
        }
    }

    private func handleDateTap(in calendar: JTACMonthView, date: Date) {

        switch Value.mode {
        case .single:
            let oldDate = self.value as? Date
            if oldDate == date, self.allowToChooseNilDate {
                self.clear()
            } else {
                self.value = date as? Value
                self.selectValue(date as? Value, in: calendar)
            }

            if self.privateCloseOnSelectionImmediately, self.value != nil {
                self.done()
            }

        case .range:

            if self.allowToChooseNilDate,
               let oldValue = self.value as? FastisRange,
               date.isInSameDay(in: self.config.calendar, date: oldValue.fromDate),
               date.isInSameDay(in: self.config.calendar, date: oldValue.toDate)
            {
                self.clear()

            } else {

                let newValue: FastisRange = {
                    guard let oldValue = self.value as? FastisRange else {
                        return .from(date.startOfDay(in: self.config.calendar), to: date.endOfDay(in: self.config.calendar))
                    }

                    let dateRangeChangesDisabled = !self.allowDateRangeChanges
                    let rangeSelected = !oldValue.fromDate.isInSameDay(date: oldValue.toDate)
                    if dateRangeChangesDisabled, rangeSelected {
                        return .from(date.startOfDay(in: self.config.calendar), to: date.endOfDay(in: self.config.calendar))
                    } else if date.isInSameDay(in: self.config.calendar, date: oldValue.fromDate) {
                        let newToDate = date.endOfDay(in: self.config.calendar)
                        return .from(oldValue.fromDate, to: newToDate)
                    } else if date.isInSameDay(in: self.config.calendar, date: oldValue.toDate) {
                        let newFromDate = date.startOfDay(in: self.config.calendar)
                        return .from(newFromDate, to: oldValue.toDate)
                    } else if date < oldValue.fromDate {
                        let newFromDate = date.startOfDay(in: self.config.calendar)
                        return .from(newFromDate, to: oldValue.toDate)
                    } else {
                        let newToDate = date.endOfDay(in: self.config.calendar)
                        return .from(oldValue.fromDate, to: newToDate)
                    }

                }()

                self.value = newValue as? Value
                self.selectValue(newValue as? Value, in: calendar)

            }

        }

    }

    private func selectRange(_ range: FastisRange, in calendar: JTACMonthView) {
        calendar.deselectAllDates(triggerSelectionDelegate: false)
        calendar.selectDates(
            from: range.fromDate,
            to: range.toDate,
            triggerSelectionDelegate: true,
            keepSelectionIfMultiSelectionAllowed: false
        )
        calendar.visibleDates { segment in
            UIView.performWithoutAnimation {
                calendar.reloadItems(at: (segment.outdates + segment.indates).map(\.indexPath))
            }
        }
    }

    private func clear() {
        self.value = nil
        self.viewConfigs.removeAll()
        self.calendarView.deselectAllDates()
        self.calendarView.reloadData()
    }

    // MARK: - JTACMonthViewDelegate

    public func configureCalendar(_ calendar: JTACMonthView) -> ConfigurationParameters {

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy MM dd"
//        dateFormatter.calendar = typeCalendar
        dateFormatter.timeZone = self.config.calendar.timeZone
        dateFormatter.locale = localIdentifier?.identifier == "ar_EG" ? Locale(identifier: "ar_EG") : self.config.calendar.locale
        var startDate = dateFormatter.date(from: "2000 01 01")!
        var endDate = dateFormatter.date(from: "2030 12 01")!

        if let maximumDate = self.privateMaximumDate,
           let maximumMonth =  self.maximumMonthDate,
           let endOfNextMonth = self.config.calendar.date(byAdding: .month, value: maximumMonth, to: maximumDate)?
           .endOfMonth(in: self.config.calendar)
        {
            endDate = endOfNextMonth
        }

        if let minimumDate = self.privateMinimumDate,
           let minimumMonth =  self.minimumMonthDate,
           let startOfPreviousMonth = self.config.calendar.date(byAdding: .month, value: -minimumMonth, to: minimumDate)?
           .startOfMonth(in: self.config.calendar)
        {
            startDate = startOfPreviousMonth
        }

        let parameters = ConfigurationParameters(
            startDate: startDate,
            endDate: endDate,
            numberOfRows: 6,
            calendar: self.config.calendar,
            generateInDates: .forAllMonths,
            generateOutDates: .tillEndOfRow,
            firstDayOfWeek: nil,
            hasStrictBoundaries: true
        )
        return parameters
    }

    public func calendar(
        _ calendar: JTACMonthView,
        headerViewForDateRange range: (start: Date, end: Date),
        at indexPath: IndexPath
    ) -> JTACMonthReusableView {
        let header = calendar.dequeueReusableJTAppleSupplementaryView(
            withReuseIdentifier: self.monthHeaderReuseIdentifier,
            for: indexPath
        ) as! MonthHeader

        header.localIdentifier = self.localIdentifier
        header.typeCalender = self.typeCalendar
        header.applyConfig(self.config.monthHeader)
        header.configure(for: range.start)
        if self.privateSelectMonthOnHeaderTap, Value.mode == .range {
            header.tapHandler = { [weak self, weak calendar] in
                guard let self, let calendar else { return }
                var fromDate = range.start.startOfMonth(in: self.config.calendar)
                var toDate = range.start.endOfMonth(in: self.config.calendar)
                if let minDate = self.minimumDate {
                    if toDate < minDate { return } else if fromDate < minDate {
                        fromDate = minDate.startOfDay(in: self.config.calendar)
                    }
                }
                if let maxDate = self.maximumDate {
                    if fromDate > maxDate { return } else if toDate > maxDate {
                        toDate = maxDate.endOfDay(in: self.config.calendar)
                    }
                }
                let newValue: FastisRange = .from(fromDate, to: toDate)
                self.value = newValue as? Value
                self.selectRange(newValue, in: calendar)
            }
        }
        return header
    }

    public func calendar(_ calendar: JTACMonthView, cellForItemAt date: Date, cellState: CellState, indexPath: IndexPath) -> JTACDayCell {
        let cell = calendar.dequeueReusableJTAppleCell(withReuseIdentifier: self.dayCellReuseIdentifier, for: indexPath)
        self.configureCell(cell, forItemAt: date, cellState: cellState, indexPath: indexPath)
        return cell
    }

    public func calendar(
        _ calendar: JTACMonthView,
        willDisplay cell: JTACDayCell,
        forItemAt date: Date,
        cellState: CellState,
        indexPath: IndexPath
    ) {
        self.configureCell(cell, forItemAt: date, cellState: cellState, indexPath: indexPath)
    }

    public func calendar(
        _ calendar: JTACMonthView,
        didSelectDate date: Date,
        cell: JTACDayCell?,
        cellState: CellState,
        indexPath: IndexPath
    ) {
        if (dayNumber != nil) {
            dateSelected = date
            let componentDate = getDate(from: dayNumber ?? 0, fromDate: dateSelected!).get(.day, .month, .year)
                maximumDate = typeCalendar?.date(from: DateComponents(year: componentDate.year, month: componentDate.month, day: componentDate.day))
        }

        if cellState.selectionType == .some(.userInitiated) {
            self.handleDateTap(in: calendar, date: date)
        } else if let cell {
            self.configureCell(cell, forItemAt: date, cellState: cellState, indexPath: indexPath)
        }
    }

    public func calendar(
        _ calendar: JTACMonthView,
        didDeselectDate date: Date,
        cell: JTACDayCell?,
        cellState: CellState,
        indexPath: IndexPath
    ) {
        if cellState.selectionType == .some(.userInitiated), Value.mode == .range {
            self.handleDateTap(in: calendar, date: date)
        } else if let cell {
            self.configureCell(cell, forItemAt: date, cellState: cellState, indexPath: indexPath)
        }
    }

    public func calendar(
        _ calendar: JTACMonthView,
        shouldSelectDate date: Date,
        cell: JTACDayCell?,
        cellState: CellState,
        indexPath: IndexPath
    ) -> Bool {
        self.viewConfigs.removeAll()
        return true
    }

    public func calendar(
        _ calendar: JTACMonthView,
        shouldDeselectDate date: Date,
        cell: JTACDayCell?,
        cellState: CellState,
        indexPath: IndexPath
    ) -> Bool {
        self.viewConfigs.removeAll()
        return true
    }

    public func calendarSizeForMonths(_ calendar: JTACMonthView?) -> MonthSize? {
        self.config.monthHeader.height
    }

    func getMonths(from days: Int) -> Int {
        // Calculate the number of months and days from the given number of days
        let months = days / 30
        let remainingDays = days % 30

        // If there are 29 or more days remaining, add one to the month count
        if remainingDays >= 29 {
            return months + 1
        } else {
            return months
        }
    }

    func getDate(from days: Int, fromDate date: Date) -> Date {
        let calendar = Calendar.current
        let now = date
        let dateComponents = DateComponents(day: days)

        if let futureDate = calendar.date(byAdding: dateComponents, to: now) {
            return futureDate
        } else {
            print("Unable to calculate future date.")
            return now
        }
    }

}

public extension FastisController where Value == FastisRange {

    /// Initiate FastisController
    /// - Parameters:
    ///   - mode: Choose `.range` or `.single` mode
    ///   - config: Custom configuration parameters. Default value is equal to `FastisConfig.default`
    convenience init(mode: FastisModeRange, config: FastisConfig = .default) {
        self.init(config: config)
        self.selectMonthOnHeaderTap = true
    }

    /**
     Set this variable to `true` if you want to allow select date ranges by tapping on months
     */
    var selectMonthOnHeaderTap: Bool {
        get {
            self.privateSelectMonthOnHeaderTap
        }
        set {
            self.privateSelectMonthOnHeaderTap = newValue
        }
    }
}

public extension FastisController where Value == Date {

    /// Initiate FastisController
    /// - Parameters:
    ///   - mode: Choose .range or .single mode
    ///   - config: Custom configuration parameters. Default value is equal to `FastisConfig.default`
    convenience init(mode: FastisModeSingle, config: FastisConfig = .default) {
        self.init(config: config)
    }

    /**
     Set this variable to `true` if you want to hide view of the selected date and close the controller right after the date is selected.

     Default value — `"False"`
     */
    var closeOnSelectionImmediately: Bool {
        get {
            self.privateCloseOnSelectionImmediately
        }
        set {
            self.privateCloseOnSelectionImmediately = newValue
        }
    }

}

public extension FastisConfig {

    /**
     Configuration of base view controller (`cancelButtonTitle`, `doneButtonTitle`, etc.)

     Configurable in FastisConfig.``FastisConfig/controller-swift.property`` property
     */
    struct Controller {

        /**
         Cancel button title

         Default value — `"Cancel"`
         */
        public var cancelButtonTitle = "Cancel"

        /**
         Done button title

         Default value — `"Done"`
         */
        public var doneButtonTitle = "Done"

        /**
         Controller's background color

         Default value — `.systemBackground`
         */
        public var backgroundColor: UIColor = .systemBackground

        /**
         Bar button items tint color

         Default value — `.systemBlue`
         */
        public var barButtonItemsColor: UIColor = .systemBlue

        /**
         Custom cancel button in navigation bar

         Default value — `nil`
         */
        public var customCancelButton: UIBarButtonItem?

        /**
         Custom done button in navigation bar

         Default value — `nil`
         */
        public var customDoneButton: UIBarButtonItem?

    }
}

public extension FastisController {

    /**
     Parameter to return in the dismissHandler

     `.done(Value?)` - If a date is selected.
     `.cancel` - if controller closed without date selection
     */
    enum DismissAction {
        case done(Value?)
        case cancel
    }
}
