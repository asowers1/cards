// CardStackController.swift
//
// Copyright (c) 2015 Karma Mobility Inc. (https://yourkarma.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit
import pop

struct Card {
    let viewController: UIViewController

    let containerView: UIView
    var topConstraint: NSLayoutConstraint

    let dismissButton: UIButton
}

extension UIViewController {
    public var cardStackController: CardStackController? {
        if let cardStackController = self.parentViewController as? CardStackController {
            return cardStackController
        } else {
            return self.parentViewController?.cardStackController
        }
    }
}

public class CardStackController: UIViewController {
    public var topViewController: UIViewController? {
        return self.topCard?.viewController
    }

    public var topViewControllerCanBeDismissed: Bool {
        get {
            return self.topCard?.dismissButton.enabled ?? false
        }
        set {
            self.topCard?.dismissButton.enabled = newValue
        }
    }

    public init(rootViewController: UIViewController) {
        super.init(nibName: nil, bundle: nil)
        self.pushViewController(rootViewController, animated: false, completion: nil)
    }

    public required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    public var cardStackTransitionCoordinator: TransitionCoordinator?

    var cards: [Card] = []
    var topCard: Card? {
        return self.cards.last
    }
    var cardAppearanceCalculator: CardAppearanceCalculator = CardAppearanceCalculator()

    var rootViewController: UIViewController? {
        didSet {
            if let rootViewController = self.rootViewController {
                self.addChildViewController(rootViewController)
                self.view.addSubview(rootViewController.view)

                self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|[root]|", options: .allZeros, metrics: nil, views: ["root": rootViewController.view]))
                self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[root]|", options: .allZeros, metrics: nil, views: ["root": rootViewController.view]))

                rootViewController.didMoveToParentViewController(self)
            } else {
                oldValue?.willMoveToParentViewController(nil)
                oldValue?.view.removeFromSuperview()
                oldValue?.removeFromParentViewController()
            }
        }
    }

    // The edge of the container view is slightly extended so that it's bottom rounded corners aren't visible.
    // This has no effect on the child view controller's view because it subtracts this amount from it's height.
    let extendedEdgeDistance: CGFloat = 10.0

    var panGestureRecognizer: UIPanGestureRecognizer!

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.panGestureRecognizer = UIPanGestureRecognizer(target: self, action: "handlePan:")
        self.view.addGestureRecognizer(self.panGestureRecognizer)
    }

    public func pushViewController(viewController: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        if rootViewController == nil {
            self.rootViewController = viewController
        } else {
            self.cardStackTransitionCoordinator = TransitionCoordinator()

            let topViewController: UIViewController?

            if let topCard = self.topCard {
                topViewController = topCard.viewController
            } else {
                topViewController = self.rootViewController
            }
            topViewController?.beginAppearanceTransition(false, animated: animated)

            let dismissButton = self.makeDismissButton()
            let containerView = self.makeContainerForChildView(viewController.view, withDismissButton: dismissButton)
            let topConstraint = NSLayoutConstraint(item: containerView, attribute: .Top, relatedBy: .Equal, toItem: self.topLayoutGuide, attribute: .Bottom, multiplier: 1.0, constant: self.cardAppearanceCalculator.verticalTopOffsetForTraitCollection(self.traitCollection))
            let card = Card(viewController: viewController, containerView: containerView, topConstraint: topConstraint, dismissButton: dismissButton)

            self.addChildViewController(viewController)
            self.presentCard(card, overCards: self.cards, animated: animated) {
                viewController.didMoveToParentViewController(self)
                topViewController?.endAppearanceTransition()
                completion?()
            }
        }
    }

    public func popViewController(animated: Bool, completion: (() -> Void)? = nil) {
        self.popViewController(animated, velocity: nil, completion: completion)
    }

    func popViewController(animated: Bool, velocity: CGFloat?, completion: (() -> Void)? = nil) {
        if let topCard = self.topCard {
            self.cardStackTransitionCoordinator = TransitionCoordinator()

            let topViewController = topCard.viewController
            let remainingCards = Array(self.cards[0..<self.cards.endIndex - 1])

            let newTopViewController: UIViewController?
            if let newTopCard = remainingCards.last {
                newTopViewController = newTopCard.viewController
            } else {
                newTopViewController = self.rootViewController
            }
            newTopViewController?.beginAppearanceTransition(true, animated: animated)

            topViewController.willMoveToParentViewController(nil)

            self.dismissCard(topCard, remainingCards: remainingCards, animated: animated, velocity: velocity) {
                topViewController.removeFromParentViewController()
                newTopViewController?.endAppearanceTransition()
                completion?()
            }
        }
    }

    public override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        for card in self.cards {
            card.topConstraint.constant = self.cardAppearanceCalculator.verticalTopOffsetForTraitCollection(self.traitCollection)
            self.view.layoutIfNeeded()
        }
    }

    func presentCard(card: Card, overCards cards: [Card], animated: Bool, completion: (() -> Void)) {
        self.cards.append(card)

        let containerView = card.containerView

        self.view.addSubview(containerView)

        self.view.addConstraint(card.topConstraint)
        self.view.addConstraint(NSLayoutConstraint(item: containerView, attribute: .Bottom, relatedBy: .Equal, toItem: self.bottomLayoutGuide, attribute: .Bottom, multiplier: 1.0, constant: self.extendedEdgeDistance))
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|[container]|", options: .allZeros, metrics: nil, views: ["container": containerView]))
        self.view.layoutIfNeeded()

        self.cardStackTransitionCoordinator?.transitionWillBegin()

        if animated {
            // Applying the transform directly, instead of using fromValue, prevents a brief flash
            // where the view is visible in it's final location.
            containerView.layer.transform = CATransform3DMakeTranslation(0.0, containerView.bounds.height - self.extendedEdgeDistance, 0.0)

            let presentAnimation = POPSpringAnimation(propertyNamed: kPOPLayerTranslationY)
            presentAnimation.toValue = 0.0
            presentAnimation.springSpeed = 12.0
            presentAnimation.springBounciness = 2.0
            containerView.layer.pop_addAnimation(presentAnimation, forKey: "presentAnimation")
            presentAnimation.completionBlock = { _ in
                self.cardStackTransitionCoordinator?.transitionDidEnd()
                self.cardStackTransitionCoordinator = nil
                completion()
            }

        } else {
            self.cardStackTransitionCoordinator?.transitionDidEnd()
            completion()
        }

        self.moveCardsBack(cards, animated: animated)
    }

    func moveCardsBack(cards: [Card], animated: Bool) {
        let springSpeed: CGFloat = 12.0
        let springBounciness: CGFloat = 2.0

        for (i, card) in enumerate(reverse(cards)) {
            let dismissButton = card.dismissButton

            // Disable the dismiss button without showing the disabled state
            dismissButton.userInteractionEnabled = false

            let containerView = card.containerView
            let index = CGFloat(i)

            // + 1 because the first card is not part of the cards array
            let offset = self.offsetForCardAtIndex(i + 1)
            let scale = self.scaleForCardAtIndex(i + 1)
            let opacity = self.opacityForCardAtIndex(i + 1)

            if animated {
                let moveUpAnimation = POPSpringAnimation(propertyNamed: kPOPLayerTranslationY)
                moveUpAnimation.toValue = offset
                moveUpAnimation.springSpeed = springSpeed
                moveUpAnimation.springBounciness = springBounciness
                containerView.layer.pop_addAnimation(moveUpAnimation, forKey: "moveUpAnimation")

                let scaleBackAnimation = POPSpringAnimation(propertyNamed: kPOPLayerScaleXY)
                scaleBackAnimation.toValue = NSValue(CGPoint: CGPoint(x: scale, y: scale))
                scaleBackAnimation.springSpeed = springSpeed
                scaleBackAnimation.springBounciness = springBounciness
                containerView.layer.pop_addAnimation(scaleBackAnimation, forKey: "scaleDownAnimation")

                let opacityDownAnimation = POPSpringAnimation(propertyNamed: kPOPViewAlpha)
                opacityDownAnimation.toValue = opacity
                opacityDownAnimation.springSpeed = springSpeed
                opacityDownAnimation.springBounciness = springBounciness
                containerView.pop_addAnimation(opacityDownAnimation, forKey: "opacityDownAnimation")

                let dismissButtonOpacityAnimation = POPBasicAnimation(propertyNamed: kPOPViewAlpha)
                dismissButtonOpacityAnimation.duration = 0.5
                dismissButtonOpacityAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
                dismissButtonOpacityAnimation.toValue = 0.0
                dismissButton.pop_addAnimation(dismissButtonOpacityAnimation, forKey: "dismissButtonDisappearAnimation")
            } else {
                let scaleTransform = CGAffineTransformMakeScale(scale, scale)
                let translationTransform = CGAffineTransformMakeTranslation(0.0, offset)
                let combinedTransform = CGAffineTransformConcat(scaleTransform, translationTransform)

                containerView.transform = combinedTransform
                containerView.alpha = opacity
                dismissButton.alpha = 0.0
            }
        }
    }

    func dismissCard(card: Card, remainingCards: [Card], animated: Bool, velocity: CGFloat?, completion: (() -> Void)) {
        self.cardStackTransitionCoordinator?.transitionWillBegin()

        let containerView = card.containerView
        self.cards.removeLast()

        if animated {
            let dismissAnimation = POPSpringAnimation(propertyNamed: kPOPLayerTranslationY)
            dismissAnimation.toValue = containerView.frame.height - self.extendedEdgeDistance
            dismissAnimation.springSpeed = 12.0
            dismissAnimation.springBounciness = 0.0

            if let velocity = velocity {
                dismissAnimation.velocity = velocity
            }

            containerView.layer.pop_addAnimation(dismissAnimation, forKey: "dismissAnimation")
            dismissAnimation.completionBlock = { _ in
                containerView.removeFromSuperview()
                self.cardStackTransitionCoordinator?.transitionDidEnd()
                completion()
            }

        } else {
            containerView.removeFromSuperview()
            self.cardStackTransitionCoordinator?.transitionDidEnd()
            self.cardStackTransitionCoordinator = nil
            completion()
        }

        self.moveCardsForward(self.cards, animated: animated)
    }

    func moveCardsForward(cards: [Card], animated: Bool) {
        for (index, card) in enumerate(reverse(cards)) {
            let containerView = card.containerView
            let dismissButton = card.dismissButton

            let offset = self.offsetForCardAtIndex(index)
            let scale = self.scaleForCardAtIndex(index)
            let opacity = self.opacityForCardAtIndex(index)

            if animated {
                let springSpeed: CGFloat = 12.0
                let springBounciness: CGFloat = 0.0

                let moveUpAnimation = POPSpringAnimation(propertyNamed: kPOPLayerTranslationY)
                moveUpAnimation.toValue = offset
                moveUpAnimation.springSpeed = springSpeed
                moveUpAnimation.springBounciness = springBounciness
                containerView.layer.pop_addAnimation(moveUpAnimation, forKey: "moveDownAnimation")

                let scaleBackAnimation = POPSpringAnimation(propertyNamed: kPOPLayerScaleXY)
                scaleBackAnimation.toValue = NSValue(CGPoint: CGPoint(x: scale, y: scale))
                scaleBackAnimation.springSpeed = springSpeed
                scaleBackAnimation.springBounciness = springBounciness
                containerView.layer.pop_addAnimation(scaleBackAnimation, forKey: "scaleUpAnimation")

                let opacityDownAnimation = POPSpringAnimation(propertyNamed: kPOPViewAlpha)
                opacityDownAnimation.toValue = opacity
                opacityDownAnimation.springSpeed = springSpeed
                opacityDownAnimation.springBounciness = springBounciness
                containerView.pop_addAnimation(opacityDownAnimation, forKey: "opacityUpAnimation")

                if index == 0 {
                    let dismissButtonOpacityAnimation = POPBasicAnimation(propertyNamed: kPOPViewAlpha)
                    dismissButtonOpacityAnimation.duration = 0.3
                    dismissButtonOpacityAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
                    dismissButtonOpacityAnimation.toValue = 1.0
                    dismissButton.pop_addAnimation(dismissButtonOpacityAnimation, forKey: "dismissButtonAppearAnimation")
                }

            } else {
                let scaleTransform = CGAffineTransformMakeScale(scale, scale)
                let translationTransform = CGAffineTransformMakeTranslation(0.0, offset)
                let combinedTransform = CGAffineTransformConcat(scaleTransform, translationTransform)
                containerView.transform = combinedTransform
                containerView.alpha = opacity

                dismissButton.alpha = index == 0 ? 1.0 : 0.0
            }

            dismissButton.userInteractionEnabled = index == 0
        }
    }

    func popViewController(sender: AnyObject) {
        self.popViewController(true)
    }

    func makeContainerForChildView(childView: UIView, withDismissButton dismissButton: UIButton) -> UIView {
        let containerView = UIView()
        containerView.setTranslatesAutoresizingMaskIntoConstraints(false)

        childView.setTranslatesAutoresizingMaskIntoConstraints(false)
        containerView.addSubview(childView)

        dismissButton.setTranslatesAutoresizingMaskIntoConstraints(false)
        containerView.addSubview(dismissButton)

        containerView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|[button]|", options: .allZeros, metrics: nil, views: ["button": dismissButton]))
        containerView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[button(==45)]", options: .allZeros, metrics: nil, views: ["button": dismissButton]))

        containerView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[child]-distance-|", options: .allZeros, metrics: ["distance": self.extendedEdgeDistance], views: ["child": childView]))
        containerView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|[child]|", options: .allZeros, metrics: nil, views: ["child": childView]))

        containerView.layer.cornerRadius = 4.0
        containerView.layer.borderColor = UIColor.clearColor().CGColor
        containerView.layer.borderWidth = 1.0
        containerView.layer.masksToBounds = true

        return containerView
    }

    func makeDismissButton() -> UIButton {
        let dismissButton = UIButton()
        dismissButton.setTranslatesAutoresizingMaskIntoConstraints(false)
        let bundle = NSBundle(forClass: CardStackController.self)
        let image = UIImage(named: "Cards.bundle/dismiss-arrow.png", inBundle: bundle, compatibleWithTraitCollection: nil)
        dismissButton.setImage(image, forState: .Normal)
        dismissButton.addTarget(self, action: "popViewController:", forControlEvents: .TouchUpInside)
        return dismissButton
    }

    // Taken from: http://holko.pl/2014/07/06/inertia-bouncing-rubber-banding-uikit-dynamics/
    func rubberBandDistance(offset: CGFloat , dimension: CGFloat )  -> CGFloat {
        let constant: CGFloat = 0.01
        let result = (constant * abs(offset) * dimension) / (dimension + constant * abs(offset))

        // The algorithm expects a positive offset, so we have to negate the result if the offset was negative.
        return offset < 0.0 ? -result : result
    }

    func handlePan(gestureRecognizer: UIPanGestureRecognizer) {
        if !self.topViewControllerCanBeDismissed {
            return
        }

        if let containerView = self.topCard?.containerView,
            let childView = self.topCard?.viewController.view {
            let translation = gestureRecognizer.translationInView(self.view)
            let velocity = gestureRecognizer.velocityInView(self.view)

            switch gestureRecognizer.state {

            case .Began:
                let containerViewHeightConstraint = NSLayoutConstraint(item: containerView, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1.0, constant: containerView.frame.height)
                containerView.addConstraint(containerViewHeightConstraint)
                self.cancelReturnAnimation()

            case .Changed:
                let minY: CGFloat = 0.0
                let maxY: CGFloat = translation.y

                let constrained = max(minY, min(translation.y, maxY))
                let rubberBandedY = self.rubberBandDistance(translation.y - constrained, dimension: containerView.frame.height)
                let newY = rubberBandedY + constrained

                let childFrame = self.view.convertRect(childView.frame, fromView: childView)
                let distanceFromBottom = childFrame.maxY - self.view.frame.maxY

                let minHeight = containerView.frame.height - self.extendedEdgeDistance
                let newHeight = childView.frame.size.height - (distanceFromBottom - 2.0)
                childView.frame.size.height = max(minHeight, newHeight)
                containerView.transform = CGAffineTransformMakeTranslation(0.0, newY)

            case .Failed, .Cancelled:
                self.returnTopCardToStartPosition()

            case .Ended:
                if translation.y >= 25.0 && velocity.y > 0.0 {
                    self.popViewController(true, velocity: velocity.y)
                } else {
                    self.returnTopCardToStartPosition()
                }

            case .Possible: return
            }
        }
    }

    func returnTopCardToStartPosition() {
        if let card = self.topCard {
            let returnAnimation = POPSpringAnimation(propertyNamed: kPOPLayerTranslationY)
            returnAnimation.toValue = self.offsetForCardAtIndex(0)
            returnAnimation.springSpeed = 12.0
            returnAnimation.springBounciness = 1.0
            card.containerView.layer.pop_addAnimation(returnAnimation, forKey: "returnAnimation")

            returnAnimation.completionBlock = { _ in
                // Return the child view to it's original, unadjusted, height
                card.viewController.view.frame.size.height = card.containerView.frame.height - self.extendedEdgeDistance
            }
        }
    }

    func cancelReturnAnimation() {
        self.topCard?.containerView.layer.pop_removeAnimationForKey("returnAnimation")
    }
}

// MARK: Appearance calculator
extension CardStackController {
    func offsetForCardAtIndex(i: Int) -> CGFloat {
        return self.cardAppearanceCalculator.offsetForCardAtIndex(i)
    }

    func scaleForCardAtIndex(i: Int) -> CGFloat {
        return self.cardAppearanceCalculator.scaleForCardAtIndex(i)
    }

    func opacityForCardAtIndex(i: Int) -> CGFloat {
        return self.cardAppearanceCalculator.opacityForCardAtIndex(i)
    }
}