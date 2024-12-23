//
//  ViewController.swift
//  Example
//
//  Created by Ilya Kharlamov on 14.04.2020.
//  Copyright © 2020 DIGITAL RETAIL TECHNOLOGIES, S.L. All rights reserved.
//

import Fastis
import UIKit

class ViewController: UIViewController {

    // MARK: - Outlets
    private lazy var containerView: UIStackView = {
        let view = UIStackView()
        view.backgroundColor = .clear
        view.axis = .vertical
        view.distribution = .fill
        view.alignment = .center
        view.spacing = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    var fastisController = FastisController(mode: .range)

    private lazy var currentDateLabel = UILabel()
    let calendar = Calendar(identifier: .islamicUmmAlQura)

    private lazy var chooseRangeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Choose range of dates", for: .normal)
        button.addTarget(self, action: #selector(self.chooseRange), for: .touchUpInside)
        return button
    }()

    private lazy var chooseSingleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Choose single date", for: .normal)
        button.addTarget(self, action: #selector(self.chooseSingleDate), for: .touchUpInside)
        return button
    }()

    // MARK: - Variables

    private var currentValue: FastisValue? {
        didSet {
            
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"

            if let rangeValue = self.currentValue as? FastisRange {
                /*
                 islamicUmmAlQura
                 let hijriFromDate = HijriDate.convertGregorianToHijri(date: rangeValue.fromDate)
                 let hijriToDate = HijriDate.convertGregorianToHijri(date: rangeValue.toDate)
                 self.currentDateLabel.text = "\(hijriFromDate.day)/\(hijriFromDate.month)/\(hijriFromDate.year)"
                 + " - " +
                 "\(hijriToDate.day)/\(hijriToDate.month)/\(hijriToDate.year)"
                 */

                /*
                 gregorian
                 self.currentDateLabel.text = formatter.string(from: rangeValue.fromDate) + " - " + formatter.string(from: rangeValue.toDate)
                 */

                

                if (fastisController.typeCalendar == Calendar(identifier: .islamicUmmAlQura)) {
                    let hijriFromDate = HijriDate.convertGregorianToHijri(date: rangeValue.fromDate)
                    let hijriToDate = HijriDate.convertGregorianToHijri(date: rangeValue.toDate)
                    self.currentDateLabel.text = "\(hijriFromDate.day)/\(hijriFromDate.month)/\(hijriFromDate.year)"
                    + " - " +
                    "\(hijriToDate.day)/\(hijriToDate.month)/\(hijriToDate.year)"
                } else {
                    self.currentDateLabel.text = formatter.string(from: rangeValue.fromDate) + " - " + formatter.string(from: rangeValue.toDate)
                }
            } else if let date = self.currentValue as? Date {
                /*
                 islamicUmmAlQura
                 let hijriFromDate = HijriDate.convertGregorianToHijri(date: date)
                 self.currentDateLabel.text = "\(hijriFromDate.day)/\(hijriFromDate.month)/\(hijriFromDate.year)"
                 */
                /*
                 gregorian
                 self.currentDateLabel.text = formatter.string(from: date)
                 */
                if (fastisController.typeCalendar == Calendar(identifier: .islamicUmmAlQura)) {
                    let hijriFromDate = HijriDate.convertGregorianToHijri(date: date)
                    self.currentDateLabel.text = "\(hijriFromDate.day)/\(hijriFromDate.month)/\(hijriFromDate.year)"
                } else {
                    self.currentDateLabel.text = formatter.string(from: date)
                }
            } else {
                self.currentDateLabel.text = "Choose a date"
            }
        }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureUI()
        self.configureSubviews()
        self.configureConstraints()
    }

    // MARK: - Configuration

    private func configureUI() {
        self.view.backgroundColor = .systemBackground
        self.navigationItem.title = "Fastis demo"
        self.navigationItem.largeTitleDisplayMode = .always
        self.currentValue = nil
    }

    private func configureSubviews() {
        self.containerView.addArrangedSubview(self.currentDateLabel)
        self.containerView.setCustomSpacing(32, after: self.currentDateLabel)
        self.containerView.addArrangedSubview(self.chooseRangeButton)
        self.containerView.addArrangedSubview(self.chooseSingleButton)
        self.view.addSubview(self.containerView)
    }

    private func configureConstraints() {
        NSLayoutConstraint.activate([
            self.containerView.centerXAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerXAnchor),
            self.containerView.centerYAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerYAnchor),
            self.containerView.leftAnchor.constraint(greaterThanOrEqualTo: self.view.safeAreaLayoutGuide.leftAnchor),
            self.containerView.topAnchor.constraint(greaterThanOrEqualTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.containerView.rightAnchor.constraint(lessThanOrEqualTo: self.view.safeAreaLayoutGuide.rightAnchor),
            self.containerView.bottomAnchor.constraint(lessThanOrEqualTo: self.view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    // MARK: - Actions

    @objc
    private func chooseRange() {
        var config = FastisConfig.default
        fastisController.typeCalendar?.firstWeekday = 1
        config.calendar = Calendar(identifier: fastisController.typeCalendar?.identifier == .islamicUmmAlQura ? .islamicUmmAlQura : .gregorian)
        fastisController = FastisController(mode: .range, config: config)
        fastisController.title = "Choose range"

   /*
    fastisController.minimumMonthDate = 0
    fastisController.maximumMonthDate = 0
    fastisController.minimumDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2024, month: 1, day: 1))
    fastisController.maximumDate =  calendar.date(from: DateComponents(year: 2024, month: 12, day: 31))
    */
        fastisController.minimumMonthDate = 0
        fastisController.maximumMonthDate = 0
        fastisController.minimumDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2024, month: 1, day: 1))
        fastisController.maximumDate =  calendar.date(from: DateComponents(year: 2024, month: 12, day: 31))
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy MM dd"
        fastisController.maximumDateDisplay =  dateFormatter.date(from: "2050 01 01")!
     
        fastisController.allowToChooseNilDate = true
        fastisController.dismissHandler = { [weak self] action in
            switch action {
            case .done(let newValue):
                self?.currentValue = newValue
            case .cancel:
                print("any actions")
            }
        }
        fastisController.present(above: self)
    }

    @objc
    private func chooseSingleDate() {
        let fastisController = FastisController(mode: .single)
        fastisController.title = "Choose date"
        fastisController.initialValue = self.currentValue as? Date
        fastisController.maximumDate = Date()

        fastisController.shortcuts = [.today, .yesterday, .tomorrow]
        fastisController.dismissHandler = { [weak self] action in
            switch action {
            case .done(let newValue):
                self?.currentValue = newValue
            case .cancel:
                print("any actions")
            }
        }
        fastisController.present(above: self)
    }

}


