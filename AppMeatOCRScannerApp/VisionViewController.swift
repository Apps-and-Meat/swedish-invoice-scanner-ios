/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Vision view controller.
			Recognizes text using a Vision VNRecognizeTextRequest request handler in pixel buffers from an AVCaptureOutput.
			Displays bounding boxes around recognized text results in real time.
*/

import Foundation
import UIKit

class InvoiceResultsView: UIView {
    @IBOutlet weak var referensLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var accountNumberLabel: UILabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        layer.cornerRadius = 8
    }
}

enum CaptureType: Hashable {
    case reference
    case amount
    case accountNumber
}

class VisionViewController: ViewController {

    @IBOutlet weak var resultsView: InvoiceResultsView?

    var reference: String? {
        didSet {
            resultsView?.referensLabel.text = String(reference?.split(separator: " ").first ?? "")
        }
    }

    var amount: String? {
        didSet {
            resultsView?.amountLabel.text = amount?.replacingOccurrences(of: " ", with: ",")
        }
    }

    var accountNumber: String? {
        didSet {
            resultsView?.accountNumberLabel.text = String(accountNumber?.split(separator: "#").first ?? "")
        }
    }
	
	// MARK: - Text recognition

    override func didFindString(string: String, type: CaptureType) {

        guard currentStringFor(type: type) != string else { return }

        captureSessionQueue.sync {
            DispatchQueue.main.async {
                switch type {
                case .accountNumber:
                    self.accountNumber = string
                case .amount:
                    self.amount = string
                case .reference:
                    self.reference = string
                }

                self.cameraView.alpha = 0
                UIView.animate(withDuration: 0.5) {
                    self.cameraView.alpha = 1
                }
            }
        }
    }

    private func currentStringFor(type: CaptureType) -> String? {
        switch type {
        case .accountNumber:
            return accountNumber
        case .amount:
            return amount
        case .reference:
            return reference
        }
    }

    @IBAction func didTapReset() {
        self.reference = nil
        self.accountNumber = nil
        self.amount = nil
    }
}
