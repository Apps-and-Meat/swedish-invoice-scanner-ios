/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Vision view controller.
			Recognizes text using a Vision VNRecognizeTextRequest request handler in pixel buffers from an AVCaptureOutput.
			Displays bounding boxes around recognized text results in real time.
*/

import Foundation
import UIKit
import AVFoundation
import Vision

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

	var request: VNRecognizeTextRequest!
	// Temporal string tracker
	let numberTracker = CameraScannerStringTracker()
	
	override func viewDidLoad() {
		request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)

		super.viewDidLoad()
	}
	
	// MARK: - Text recognition
	
	// Vision recognition handler.
	func recognizeTextHandler(request: VNRequest, error: Error?) {
        var values = [String.ExtractedInvoiceValue]()
		var boxes = [CGRect]()
		
		guard let results = request.results as? [VNRecognizedTextObservation] else {
			return
		}
		
		let maximumCandidates = 1
		
		for visionResult in results {
			guard let candidate = visionResult.topCandidates(maximumCandidates).first else { continue }
            
			if let result = candidate.string.extractInvoiceValue() {
                if let box = try? candidate.boundingBox(for: result.range)?.boundingBox, box.minX > 0.06 {
                    values.append(result)
                    boxes.append(box)
				}
			}
		}
		
		// Log any found numbers.
		numberTracker.logFrame(strings: values)
		show(boxes: boxes)
		
		// Check if we have any temporally stable numbers.
		if let sureExtractedValue = numberTracker.getStableString() {
            didFindString(string: sureExtractedValue.value, type: sureExtractedValue.type)
			numberTracker.reset(string: sureExtractedValue)
		}
	}

    func didFindString(string: String, type: CaptureType) {

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

	override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
			// Configure for running in real-time.
			request.recognitionLevel = .fast
			// Language correction won't help recognizing phone numbers. It also
			// makes recognition slower.
			request.usesLanguageCorrection = false
			// Only run on the region of interest for maximum speed.
			request.regionOfInterest = regionOfInterest
			
			let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: textOrientation, options: [:])
			do {
				try requestHandler.perform([request])
			} catch {
				print(error)
			}
		}
	}
}
