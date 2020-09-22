/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller: handles camera, preview and cutout UI.
*/

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

class MaskView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        layer.cornerRadius = 8
        layer.borderWidth = 2
        layer.borderColor = UIColor.white.cgColor
    }
}

extension ViewController {
    
    class OverlayView: UIView {

        let maskLayer: CAShapeLayer = {
            let mask = CAShapeLayer()
            mask.backgroundColor = UIColor.clear.cgColor
            mask.fillRule = .evenOdd
            return mask
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            setup()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setup()
        }

        func setup() {

        }

        func setMaskedWindow(rect: CGRect) {
            layer.mask = maskLayer
            maskLayer.path = UIBezierPath(rect: rect).cgPath
            let path = UIBezierPath(rect: self.frame)
            path.append(UIBezierPath(roundedRect: rect, cornerRadius: 8))
            maskLayer.path = path.cgPath
        }
    }
}



class ViewController: UIViewController {

    // MARK: - UI objects
    @IBOutlet weak var resultsView: InvoiceResultsView?
    @IBOutlet weak var cameraWindowView: MaskView!

    @IBInspectable var overlayColor: UIColor? {
        get { overlayView.backgroundColor }
        set { overlayView.backgroundColor = newValue }
    }

    var cameraView = PreviewView()
    var overlayView = OverlayView()

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
    
//    var maskLayer = CAShapeLayer()
    // Device orientation. Updated whenever the orientation changes to a
    // different supported orientation.
    var currentOrientation = UIDeviceOrientation.portrait
    
    // MARK: - Capture related objects
    private let captureSession = AVCaptureSession()
    let captureSessionQueue = DispatchQueue(label: "com.appmeat.invoice-scanner.CaptureSessionQueue")
    
    var captureDevice: AVCaptureDevice?
    
    var videoDataOutput = AVCaptureVideoDataOutput()
    let videoDataOutputQueue = DispatchQueue(label: "com.appmeat.invoice-scanner.VideoDataOutputQueue")
    
    // MARK: - Region of interest (ROI) and text orientation
    // Region of video data output buffer that recognition should be run on.
    // Gets recalculated once the bounds of the preview layer are known.
    var regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
    // Orientation of text to search for in the region of interest.
    var textOrientation = CGImagePropertyOrientation.up
    
    // MARK: - Coordinate transforms
    var bufferAspectRatio: Double!
    // Transform from UI orientation to buffer orientation.
    var uiRotationTransform = CGAffineTransform.identity
    // Transform bottom-left coordinates to top-left.
    var bottomToTopTransform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
    // Transform coordinates in ROI to global coordinates (still normalized).
    var roiToGlobalTransform = CGAffineTransform.identity
    
    // Vision -> AVF coordinate transform.
    var visionToAVFTransform = CGAffineTransform.identity
    
    // MARK: - View controller methods

    private func setupCameraView() {
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraView)
        view.sendSubviewToBack(cameraView)

        view.addConstraint(.init(item: cameraView,
                                 attribute: .height,
                                 relatedBy: .equal,
                                 toItem: cameraView,
                                 attribute: .width,
                                 multiplier: 1920 / 1080,
                                 constant: 0))

        view.addConstraint(.init(item: cameraView,
                                 attribute: .centerX,
                                 relatedBy: .equal,
                                 toItem: view,
                                 attribute: .centerX,
                                 multiplier: 1,
                                 constant: 0))

        view.addConstraint(.init(item: cameraView,
                                 attribute: .top,
                                 relatedBy: .equal,
                                 toItem: view,
                                 attribute: .top,
                                 multiplier: 1,
                                 constant: 0))

        view.addConstraint(.init(item: cameraView,
                                 attribute: .bottom,
                                 relatedBy: .equal,
                                 toItem: view,
                                 attribute: .bottom,
                                 multiplier: 1,
                                 constant: 0))
    }

    private func setupOverlayView() {
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(overlayView, aboveSubview: cameraView)

        view.addConstraint(.init(item: overlayView,
                                 attribute: .left,
                                 relatedBy: .equal,
                                 toItem: view,
                                 attribute: .left,
                                 multiplier: 1,
                                 constant: 0))

        view.addConstraint(.init(item: overlayView,
                                 attribute: .trailing,
                                 relatedBy: .equal,
                                 toItem: view,
                                 attribute: .trailing,
                                 multiplier: 1,
                                 constant: 0))

        view.addConstraint(.init(item: overlayView,
                                 attribute: .top,
                                 relatedBy: .equal,
                                 toItem: view,
                                 attribute: .top,
                                 multiplier: 1,
                                 constant: 0))

        view.addConstraint(.init(item: overlayView,
                                 attribute: .bottom,
                                 relatedBy: .equal,
                                 toItem: view,
                                 attribute: .bottom,
                                 multiplier: 1,
                                 constant: 0))
    }



    override func viewDidLoad() {
        super.viewDidLoad()

        setupCameraView()
        setupOverlayView()
        
        // Set up preview view.
        cameraView.session = captureSession

//        maskLayer.backgroundColor = UIColor.clear.cgColor
//        maskLayer.fillRule = .evenOdd
//        cutoutView.layer.mask = maskLayer
        
        // Starting the capture session is a blocking call. Perform setup using
        // a dedicated serial dispatch queue to prevent blocking the main thread.
        captureSessionQueue.async {
            self.setupCamera()
            
            // Calculate region of interest now that the camera is setup.
            DispatchQueue.main.async {
                // Figure out initial ROI.
                self.calculateRegionOfInterest()
                self.updateCutout()
            }
        }
    }
    
    // MARK: - Setup
    
    func calculateRegionOfInterest() {

        let scanRect = view.convert(cameraWindowView.frame, to: cameraView)

        let width = Double(scanRect.width / cameraView.frame.width)
        let height = Double(scanRect.height / cameraView.frame.height)
        let x = (cameraView.frame.width - scanRect.maxX) / (cameraView.frame.width)
        let y = (cameraView.frame.height - scanRect.maxY) / (cameraView.frame.height)

        regionOfInterest.origin = CGPoint(x: x, y: y)
        regionOfInterest.size = CGSize(width: width, height: height)
        setupOrientationAndTransform()
    }
    
    func updateCutout() {
        overlayView.setMaskedWindow(rect: cameraWindowView.frame)
    }
    
    func setupOrientationAndTransform() {
        // Recalculate the affine transform between Vision coordinates and AVF coordinates.

        // Compensate for region of interest.
        let roi = regionOfInterest
        roiToGlobalTransform = CGAffineTransform(translationX: roi.origin.x, y: roi.origin.y).scaledBy(x: roi.width, y: roi.height)

        // Compensate for orientation (buffers always come in the same orientation).
        textOrientation = CGImagePropertyOrientation.right
        uiRotationTransform = CGAffineTransform(translationX: 0, y: 1).rotated(by: -CGFloat.pi / 2)

        // Full Vision ROI to AVF transform.
        visionToAVFTransform = roiToGlobalTransform.concatenating(bottomToTopTransform).concatenating(uiRotationTransform)
    }
    
    func setupCamera() {
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back) else {
            print("Could not create capture device.")
            return
        }
        self.captureDevice = captureDevice
        
        // NOTE:
        // Requesting 4k buffers allows recognition of smaller text but will
        // consume more power. Use the smallest buffer size necessary to keep
        // down battery usage.
        if captureDevice.supportsSessionPreset(.hd4K3840x2160) {
            captureSession.sessionPreset = AVCaptureSession.Preset.hd4K3840x2160
            bufferAspectRatio = 3840.0 / 2160.0
        } else {
            captureSession.sessionPreset = AVCaptureSession.Preset.hd1920x1080
            bufferAspectRatio = 1920.0 / 1080.0
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            print("Could not create device input.")
            return
        }
        if captureSession.canAddInput(deviceInput) {
            captureSession.addInput(deviceInput)
        }
        
        // Configure video data output.
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            videoDataOutput.connection(with: AVMediaType.video)?.preferredVideoStabilizationMode = .off
        } else {
            print("Could not add VDO output")
            return
        }
        
        // Set zoom and autofocus to help focus on very small text.
        do {
            try captureDevice.lockForConfiguration()
            captureDevice.videoZoomFactor = 1
            captureDevice.autoFocusRangeRestriction = .near
            captureDevice.unlockForConfiguration()
        } catch {
            print("Could not set zoom level due to error: \(error)")
            return
        }
        
        captureSession.startRunning()
    }
    
    // MARK: - UI drawing and interaction
    
    enum CaptureType: Hashable {
        case reference
        case amount
        case accountNumber
    }
    
    func showString(string: String, type: CaptureType) {
        
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

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // This is implemented in VisionViewController.
    }
}
