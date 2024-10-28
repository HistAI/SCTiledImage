//
//  SCTiledImageViewController.swift
//  SCTiledImage
//
//  Created by Yan Smaliak on 04/07/2023.
//

import UIKit

// MARK: - SCTiledImageViewController

public class SCTiledImageViewController: UIViewController {

    // MARK: - OverlayPosition

    public enum OverlayPosition {

        // MARK: - Cases

        case top
        case bottom
    }

    // MARK: - Public Properties

    public var currentTransform: CGAffineTransform {
        containerView.transform
    }

    public var containerSize: CGSize {
        containerView.bounds.size
    }

    public private(set) var containerView = SCTiledImageContainerView()

    public var dataSource: SCTiledImageViewDataSource? {
        containerView.dataSource
    }

    public weak var delegate: SCTiledImageDelegate?

    public var isRecenteringOnOrientationChangeEnabled = false

    public private(set) var isImageTransformed = false {
        didSet {
            delegate?.didChangeImageTransformation(isImageTransformed)
        }
    }

    public var defaultScale: CGFloat? {
        guard let imageSize = dataSource?.imageSize else { return nil }
        let minContainerSize = min(view.bounds.width, view.bounds.height)
        let minCanvasSize = max(imageSize.width, imageSize.height)
        return (minContainerSize / minCanvasSize) * initialScale
    }

    // MARK: - Private Properties

    private var centerDiff: CGPoint?
    private var initialScale: CGFloat = 1
    private var overlayViews: [UIView] = []
    private var overlayViewsRelativeInitialTransforms: [Int: CGAffineTransform] = [:]

    // MARK: - Life Cycle

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = true
    }

    override public func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: containerView)
        delegate?.didBeginTouches(at: location)
    }

    override public func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: containerView)
        delegate?.didMoveTouches(to: location)
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: containerView)
        delegate?.didEndTouches(at: location)
    }

    // MARK: - Public Methods

    public func setup(dataSource: SCTiledImageViewDataSource, initialScale: CGFloat = 1) {
        self.initialScale = initialScale

        removeContainerView()

        containerView = SCTiledImageContainerView()
        containerView.setup(dataSource: dataSource)

        guard let defaultScale else { return }

        delegate?.didSetDefaultScale(to: defaultScale)

        view.addSubview(containerView)

        containerView.transform = CGAffineTransform(scaleX: defaultScale, y: defaultScale)
        containerView.center = CGPoint(x: view.center.x - view.frame.minX, y: view.center.y - view.frame.minY)
        centerDiff = CGPoint(x: containerView.center.x - view.center.x, y: containerView.center.y - view.center.y)

        setupGestureRecognizers()

        isImageTransformed = false

        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    public func reset(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let defaultScale else { return }

        UIView.animate(withDuration: animated ? Constants.AnimationDuration.default : .zero, animations: { [weak self] in
            guard let self else { return }

            let center = CGPoint(x: view.center.x - view.frame.minX, y: view.center.y - view.frame.minY)
            containerView.transform = CGAffineTransform(scaleX: defaultScale, y: defaultScale)
            containerView.center = center

            for overlayView in overlayViews {
                if let overlayViewRelativeInitialTransform = overlayViewsRelativeInitialTransforms[overlayView.hash] {
                    overlayView.transform = CGAffineTransform(
                        overlayViewRelativeInitialTransform.a * defaultScale,
                        overlayViewRelativeInitialTransform.b * defaultScale,
                        overlayViewRelativeInitialTransform.c * defaultScale,
                        overlayViewRelativeInitialTransform.d * defaultScale,
                        overlayViewRelativeInitialTransform.tx * defaultScale,
                        overlayViewRelativeInitialTransform.ty * defaultScale
                    )
                    overlayView.center = center
                }
            }
        }, completion: { [weak self] _ in
            guard let self else { return }
            centerDiff = CGPoint(x: containerView.center.x - view.center.x, y: containerView.center.y - view.center.y)
            isImageTransformed = false
            delegate?.didApplyTransformation(.none)
            completion?()
        })
    }

    public func recenter() {
        guard let centerDiff else { return }

        Task {
            await MainActor.run {
                UIView.animate(withDuration: Constants.AnimationDuration.default) { [weak self] in
                    guard let self else { return }

                    let center = CGPoint(x: view.center.x + centerDiff.x, y: view.center.y + centerDiff.y)
                    containerView.center = center
                    for overlayView in overlayViews {
                        overlayView.center = center
                    }
                }
            }
        }
    }

    public func addOverlayView(_ overlayView: UIView, position: OverlayPosition, isTrueSize: Bool = true) {
        guard let defaultScale,
              !view.subviews.contains(overlayView),
              view.subviews.contains(containerView),
              dataSource != nil else { return }
        removeOverlayView(overlayView)

        switch position {
        case .top:
            let previousTopOverlayView = overlayViews.max(by: { $0.layer.zPosition > $1.layer.zPosition })
            let zPosition = max(previousTopOverlayView?.layer.zPosition ?? 999, 999) + 1
            overlayView.layer.zPosition = zPosition
        case .bottom:
            let previousBottomOverlayView = overlayViews.min(by: { $0.layer.zPosition < $1.layer.zPosition })
            let zPosition = min(previousBottomOverlayView?.layer.zPosition ?? .zero, .zero) - 1
            overlayView.layer.zPosition = zPosition
        }

        overlayViews.append(overlayView)
        view.addSubview(overlayView)

        overlayViewsRelativeInitialTransforms[overlayView.hash] = CGAffineTransform(
            overlayView.transform.a / defaultScale,
            overlayView.transform.b / defaultScale,
            overlayView.transform.c / defaultScale,
            overlayView.transform.d / defaultScale,
            overlayView.transform.tx / defaultScale,
            overlayView.transform.ty / defaultScale
        )

        if isTrueSize {
            overlayView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                overlayView.topAnchor.constraint(equalTo: containerView.topAnchor),
                overlayView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                overlayView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                overlayView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            ])
        } else {
            overlayView.translatesAutoresizingMaskIntoConstraints = false
            let imageSize = dataSource?.imageSize ?? .zero
            NSLayoutConstraint.activate([
                overlayView.widthAnchor.constraint(equalToConstant: imageSize.width * defaultScale),
                overlayView.heightAnchor.constraint(equalToConstant: imageSize.height * defaultScale),
                overlayView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                overlayView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            ])
        }
    }

    public func removeOverlayView(_ overlayView: UIView?) {
        guard let overlayView else { return }

        if overlayViews.contains(overlayView) {
            overlayView.removeFromSuperview()
            overlayViewsRelativeInitialTransforms.removeValue(forKey: overlayView.hash)
            overlayViews.removeAll(where: { $0 == overlayView })
        }
    }

    public func removeContainerView() {
        containerView.removeFromSuperview()
    }

    public func isUserInteractionEnabledForOverlays(_ isEnabled: Bool) {
        for overlayView in overlayViews {
            overlayView.isUserInteractionEnabled = isEnabled
        }
    }

    public func zoomAndScroll(to point: CGPoint, withScale scale: CGFloat, andOffset offset: CGPoint, animated: Bool = true) {
        guard let defaultScale, let imageSize = dataSource?.imageSize else { return }

        let transform = CGAffineTransform(scaleX: defaultScale, y: defaultScale).scaledBy(x: scale, y: scale)

        let center = CGPoint(x: view.center.x - view.frame.minX, y: view.center.y - view.frame.minY)
        let newCenter = CGPoint(
            x: center.x + (imageSize.width / 2 - point.x) * defaultScale * scale + offset.x,
            y: center.y + (imageSize.height / 2 - point.y) * defaultScale * scale + offset.y
        )

        let performTransform = { [weak self] in
            guard let self else { return }

            containerView.center = newCenter
            containerView.transform = transform

            for overlayView in overlayViews {
                if let overlayViewRelativeInitialTransform = overlayViewsRelativeInitialTransforms[overlayView.hash] {
                    overlayView.transform = CGAffineTransform(
                        overlayViewRelativeInitialTransform.a * defaultScale * scale,
                        overlayViewRelativeInitialTransform.b * defaultScale * scale,
                        overlayViewRelativeInitialTransform.c * defaultScale * scale,
                        overlayViewRelativeInitialTransform.d * defaultScale * scale,
                        overlayViewRelativeInitialTransform.tx * defaultScale * scale,
                        overlayViewRelativeInitialTransform.ty * defaultScale * scale
                    )
                    overlayView.center = newCenter
                }
            }
        }

        delegate?.didApplyTransformation(.identityRotation)
        delegate?.didApplyTransformation(.zoom(scale))

        UIView.animate(withDuration: animated ? Constants.AnimationDuration.default : .zero) {
            performTransform()
        }

        centerDiff = CGPoint(x: containerView.center.x - view.center.x, y: containerView.center.y - view.center.y)
        isImageTransformed = true
    }

    public func centerCoordinatesInContainer(offset: CGPoint = .zero, shouldBeInBounds: Bool = false) -> CGPoint {
        let initialCenter = CGPoint(x: view.center.x - view.frame.minX, y: view.center.y - view.frame.minY)
        let withOffset = CGPoint(x: initialCenter.x + offset.x, y: initialCenter.y + offset.y)
        var centerInContainer = view.convert(withOffset, to: containerView)

        if shouldBeInBounds {
            let containerBounds = containerView.bounds
            let clampedX = min(max(centerInContainer.x, containerBounds.minX), containerBounds.maxX)
            let clampedY = min(max(centerInContainer.y, containerBounds.minY), containerBounds.maxY)
            centerInContainer = CGPoint(x: clampedX, y: clampedY)
        }

        return centerInContainer
    }

    public func convertViewToImageCoordinates(fromView view: UIView, point: CGPoint) -> CGPoint? {
        guard let dataSource else { return nil }

        let containerPoint = view.convert(point, to: containerView)
        let imagePoint = CGPoint(
            x: containerPoint.x * (dataSource.imageSize.width / containerView.bounds.width),
            y: containerPoint.y * (dataSource.imageSize.height / containerView.bounds.height)
        )

        return imagePoint
    }

    public func convertImageToViewCoordinates(_ imagePoint: CGPoint, toView view: UIView) -> CGPoint? {
        guard let dataSource else { return nil }

        let containerPoint = CGPoint(
            x: imagePoint.x * (containerView.bounds.width / dataSource.imageSize.width),
            y: imagePoint.y * (containerView.bounds.height / dataSource.imageSize.height)
        )

        return containerView.convert(containerPoint, to: view)
    }

    public func rotate(radians: CGFloat, animated: Bool) {
        delegate?.didApplyTransformation(.rotation(radians))

        let containerTransform = containerView.transform.rotated(by: radians)

        let applyRotation = { [weak self] in
            guard let self else { return }

            containerView.transform = containerTransform

            for overlayView in self.overlayViews {
                if let initialRelativeTransform = self.overlayViewsRelativeInitialTransforms[overlayView.hash] {
                    let resetScaleTransform = CGAffineTransform(
                        scaleX: 1.0 / initialRelativeTransform.a,
                        y: 1.0 / initialRelativeTransform.d
                    )
                    let resetOverlayTransform = overlayView.transform.concatenating(resetScaleTransform)

                    let rotatedTransform = resetOverlayTransform.rotated(by: radians)

                    let finalTransform = rotatedTransform.concatenating(initialRelativeTransform)
                    overlayView.transform = finalTransform
                }
            }
        }

        if animated {
            UIView.animate(withDuration: Constants.AnimationDuration.default, animations: applyRotation)
        } else {
            applyRotation()
        }

        centerDiff = CGPoint(x: containerView.center.x - view.center.x, y: containerView.center.y - view.center.y)
        isImageTransformed = true
    }

    // MARK: - Private Methods

    private func setupGestureRecognizers() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        panGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(panGesture)

        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        pinchGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(pinchGesture)

        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation))
        rotationGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(rotationGesture)
    }

    @objc private func orientationChanged() {
        let orientation = UIDevice.current.orientation
        guard orientation.isPortrait || orientation.isLandscape, isRecenteringOnOrientationChangeEnabled else { return }
        recenter()
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        if let delegate, delegate.shouldIgnorePanGesture() {
            return
        }

        let translation = recognizer.translation(in: recognizer.view)
        let center = CGPoint(x: containerView.center.x + translation.x, y: containerView.center.y + translation.y)
        containerView.center = center

        for overlayView in overlayViews {
            overlayView.center = center
        }

        recognizer.setTranslation(.zero, in: recognizer.view)
        centerDiff = CGPoint(x: containerView.center.x - view.center.x, y: containerView.center.y - view.center.y)

        isImageTransformed = true
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard recognizer.state == .began || recognizer.state == .changed else { return }

        if let delegate, delegate.shouldIgnorePinchGesture() {
            return
        }

        let scale: CGFloat
        if ProcessInfo.processInfo.isiOSAppOnMac {
            scale = 1 + (recognizer.scale - 1) / 5
        } else {
            scale = recognizer.scale
        }

        delegate?.didApplyTransformation(.scale(scale))

        let pinchCenter = CGPoint(
            x: recognizer.location(in: containerView).x - containerView.bounds.midX,
            y: recognizer.location(in: containerView).y - containerView.bounds.midY
        )

        let transform = containerView.transform
            .translatedBy(x: pinchCenter.x, y: pinchCenter.y)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -pinchCenter.x, y: -pinchCenter.y)

        containerView.transform = transform

        for overlayView in overlayViews {
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

        if let delegate, delegate.shouldIgnoreRotationGesture() {
            return
        }

        delegate?.didApplyTransformation(.rotation(recognizer.rotation))

        let rotationCenter = CGPoint(
            x: recognizer.location(in: containerView).x - containerView.bounds.midX,
            y: recognizer.location(in: containerView).y - containerView.bounds.midY
        )

        let transform = containerView.transform
            .translatedBy(x: rotationCenter.x, y: rotationCenter.y)
            .rotated(by: recognizer.rotation)
            .translatedBy(x: -rotationCenter.x, y: -rotationCenter.y)

        containerView.transform = transform

        for overlayView in overlayViews {
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
        shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
