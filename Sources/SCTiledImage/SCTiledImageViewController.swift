//
//  SCTiledImageViewController.swift
//  SCTiledImage
//
//  Created by Yan Smaliak on 04/07/2023.
//

import UIKit

// MARK: - SCTiledImageViewController

public class SCTiledImageViewController: UIViewController {

    // MARK: - Public Properties

    public var isRecenteringOnOrientationChangeEnabled = false
    public var onImageTransformationChange: ((Bool) -> Void)?
    public private(set) var isImageTransformed = false {
        didSet {
            onImageTransformationChange?(isImageTransformed)
        }
    }

    // MARK: - Private Properties

    private var containerView = SCTiledImageContainerView()
    private var centerDiff: CGPoint?
    private var initialScale: CGFloat = 1
    private var overlayView: UIView?
    private var overlayViewRelativeInitialTransform: CGAffineTransform?

    private var defaultScale: CGFloat? {
        guard let imageSize = containerView.dataSource?.imageSize else { return nil }

        let minContainerSize = min(view.bounds.width, view.bounds.height)
        let minCanvasSize = max(imageSize.width, imageSize.height)
        return (minContainerSize / minCanvasSize) * initialScale
    }

    // MARK: - Life Cycle

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = true
    }

    // MARK: - Public Methods

    public func setup(dataSource: SCTiledImageViewDataSource, initialScale: CGFloat = 1, backgroundColor: UIColor = .systemBackground) {
        self.initialScale = initialScale
        view.backgroundColor = backgroundColor

        removeContainerView()

        containerView = SCTiledImageContainerView()
        containerView.setup(dataSource: dataSource)

        view.addSubview(containerView)

        containerView.transform = CGAffineTransform(scaleX: defaultScale!, y: defaultScale!)

        containerView.center = CGPoint(x: view.center.x - view.frame.minX, y: view.center.y - view.frame.minY)

        centerDiff = CGPoint(x: containerView.center.x - view.center.x, y: containerView.center.y - view.center.y)

        setupGestureRecognizers()

        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    public func reset() {
        guard let defaultScale else { return }

        UIView.animate(withDuration: Constants.AnimationDuration.default, animations: { [weak self] in
            guard let self else { return }

            containerView.transform = CGAffineTransform(scaleX: defaultScale, y: defaultScale)
            containerView.center = CGPoint(x: view.center.x - view.frame.minX, y: view.center.y - view.frame.minY)

            if let overlayView, let overlayViewRelativeInitialTransform {
                overlayView.transform = CGAffineTransform(
                    overlayViewRelativeInitialTransform.a * defaultScale,
                    overlayViewRelativeInitialTransform.b * defaultScale,
                    overlayViewRelativeInitialTransform.c * defaultScale,
                    overlayViewRelativeInitialTransform.d * defaultScale,
                    overlayViewRelativeInitialTransform.tx * defaultScale,
                    overlayViewRelativeInitialTransform.ty * defaultScale
                )
                overlayView.center = containerView.center
            }
        }, completion: { [weak self] _ in
            guard let self else { return }
            centerDiff = CGPoint(x: containerView.center.x - view.center.x, y: containerView.center.y - view.center.y)
            isImageTransformed = false
        })
    }

    public func recenter() {
        guard let centerDiff else { return }

        Task {
            await MainActor.run {
                UIView.animate(withDuration: Constants.AnimationDuration.default) { [weak self] in
                    guard let self else { return }
                    containerView.center = CGPoint(x: view.center.x + centerDiff.x, y: view.center.y + centerDiff.y)
                    overlayView?.center = CGPoint(x: view.center.x + centerDiff.x, y: view.center.y + centerDiff.y)
                }
            }
        }
    }

    public func addOverlayView(_ overlayView: UIView) {
        removeOverlayView()

        self.overlayView = overlayView
        self.overlayView!.layer.zPosition = 999
        view.addSubview(self.overlayView!)

        if let defaultScale {
            overlayViewRelativeInitialTransform = CGAffineTransform(
                overlayView.transform.a / defaultScale,
                overlayView.transform.b / defaultScale,
                overlayView.transform.c / defaultScale,
                overlayView.transform.d / defaultScale,
                overlayView.transform.tx / defaultScale,
                overlayView.transform.ty / defaultScale
            )
        }

        self.overlayView!.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.overlayView!.topAnchor.constraint(equalTo: containerView.topAnchor),
            self.overlayView!.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            self.overlayView!.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            self.overlayView!.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }

    public func removeOverlayView() {
        overlayView?.removeFromSuperview()
        overlayView = nil
    }

    public func removeContainerView() {
        containerView.removeFromSuperview()
    }

    // MARK: - Private Methods

    private func setupGestureRecognizers() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        view.addGestureRecognizer(panGesture)

        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        view.addGestureRecognizer(pinchGesture)

        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation))
        view.addGestureRecognizer(rotationGesture)
    }

    @objc private func orientationChanged() {
        let orientation = UIDevice.current.orientation
        guard orientation.isPortrait || orientation.isLandscape, isRecenteringOnOrientationChangeEnabled else { return }
        recenter()
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: recognizer.view)
        containerView.center = CGPoint(x: containerView.center.x + translation.x, y: containerView.center.y + translation.y)
        recognizer.setTranslation(CGPoint.zero, in: recognizer.view)
        centerDiff = CGPoint(x: containerView.center.x - view.center.x, y: containerView.center.y - view.center.y)

        isImageTransformed = true
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard recognizer.state == .began || recognizer.state == .changed else { return }

        let pinchCenter = CGPoint(
            x: recognizer.location(in: containerView).x - containerView.bounds.midX,
            y: recognizer.location(in: containerView).y - containerView.bounds.midY
        )

        let scale: CGFloat
        if ProcessInfo.processInfo.isiOSAppOnMac {
            scale = 1 + (recognizer.scale - 1) / 5
        } else {
            scale = recognizer.scale
        }

        let transform = containerView.transform
            .translatedBy(x: pinchCenter.x, y: pinchCenter.y)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -pinchCenter.x, y: -pinchCenter.y)

        containerView.transform = transform

        if let overlayView {
            let overlayPinchCenter = CGPoint(
                x: recognizer.location(in: overlayView).x - overlayView.bounds.midX,
                y: recognizer.location(in: overlayView).y - overlayView.bounds.midY
            )

            let overlayTransform = overlayView.transform
                .translatedBy(x: overlayPinchCenter.x, y: overlayPinchCenter.y)
                .scaledBy(x: scale, y: scale)
                .translatedBy(x: -overlayPinchCenter.x, y: -overlayPinchCenter.y)

            overlayView.transform = overlayTransform
        }

        recognizer.scale = 1.0

        centerDiff = CGPoint(x: containerView.center.x - view.center.x, y: containerView.center.y - view.center.y)

        isImageTransformed = true
    }

    @objc private func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
        guard recognizer.state == .began || recognizer.state == .changed else { return }

        let rotationCenter = CGPoint(
            x: recognizer.location(in: containerView).x - containerView.bounds.midX,
            y: recognizer.location(in: containerView).y - containerView.bounds.midY
        )

        let transform = containerView.transform
            .translatedBy(x: rotationCenter.x, y: rotationCenter.y)
            .rotated(by: recognizer.rotation)
            .translatedBy(x: -rotationCenter.x, y: -rotationCenter.y)

        containerView.transform = transform

        if let overlayView {
            let overlayRotationCenter = CGPoint(
                x: recognizer.location(in: overlayView).x - overlayView.bounds.midX,
                y: recognizer.location(in: overlayView).y - overlayView.bounds.midY
            )

            let overlayTransform = overlayView.transform
                .translatedBy(x: overlayRotationCenter.x, y: overlayRotationCenter.y)
                .rotated(by: recognizer.rotation)
                .translatedBy(x: -overlayRotationCenter.x, y: -overlayRotationCenter.y)

            overlayView.transform = overlayTransform
        }

        recognizer.rotation = 0

        centerDiff = CGPoint(x: containerView.center.x - view.center.x, y: containerView.center.y - view.center.y)

        isImageTransformed = true
    }
}

// MARK: - SCTiledImageViewController (UIGestureRecognizerDelegate)

extension SCTiledImageViewController: UIGestureRecognizerDelegate {

    // MARK: - Internal Methods

    public func gestureRecognizer(
        _: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith shouldRecognizeSimultaneouslyWithGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}