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
    let dismissButton: UIButton
}

extension UIViewController {
    public var cardStackController: CardStackController? {
        return self.parentViewController as? CardStackController
    }
}

public class CardStackController: UIViewController {
    public var topViewController: UIViewController? {
        return self.topCard?.viewController
    }

    var cards: [Card] = []
    var topCard: Card? {
        return self.cards.last
    }

    // The edge of the container view is slightly extended so that it's bottom rounded corners aren't visible.
    // This has no effect on the child view controller's view because it subtracts this amount from it's height.
    let extendedEdgeDistance: CGFloat = 10.0

    public func pushViewController(viewController: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        let dismissButton = self.makeDismissButton()
        let containerView = self.makeContainerForChildView(viewController.view, withDismissButton: dismissButton)
        let card = Card(viewController: viewController, containerView: containerView, dismissButton: dismissButton)

        self.addChildViewController(viewController)
        self.presentCard(card, overCards: self.cards, animated: animated) {
            viewController.didMoveToParentViewController(self)
            completion?()
        }
    }

    public func popViewController(animated: Bool, completion: (() -> Void)? = nil) {
        if let topCard = self.topCard {
            let topViewController = topCard.viewController
            topViewController.willMoveToParentViewController(nil)

            var remainingCards = Array(self.cards[0..<self.cards.endIndex - 1])

            self.dismissCard(topCard, remainingCards: remainingCards, animated: animated) {
                topViewController.removeFromParentViewController()
                completion?()
            }
        }
    }

    func presentCard(card: Card, overCards cards: [Card], animated: Bool, completion: (() -> Void)) {
        self.cards.append(card)

        let containerView = card.containerView

        self.view.addSubview(containerView)
        self.view.addConstraint(NSLayoutConstraint(item: containerView, attribute: .Top, relatedBy: .Equal, toItem: self.topLayoutGuide, attribute: .Bottom, multiplier: 1.0, constant: 65.0))

        self.view.addConstraint(NSLayoutConstraint(item: containerView, attribute: .Bottom, relatedBy: .Equal, toItem: self.bottomLayoutGuide, attribute: .Bottom, multiplier: 1.0, constant: self.extendedEdgeDistance))
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|[container]|", options: .allZeros, metrics: nil, views: ["container": containerView]))
        self.view.layoutIfNeeded()

        if animated {

            let position = containerView.layer.position
            containerView.layer.position.y += containerView.bounds.height - self.extendedEdgeDistance

            // Ensure the content behind the view doesn't peek through when the
            // spring bounces.
            card.viewController.view.frame.size.height += self.extendedEdgeDistance

            let transformAnimation = POPSpringAnimation(propertyNamed: kPOPLayerPositionY)
            transformAnimation.toValue = position.y
            transformAnimation.springSpeed = 12.0
            transformAnimation.springBounciness = 2.0
            containerView.layer.pop_addAnimation(transformAnimation, forKey: "presentAnimation")
            transformAnimation.completionBlock = { _ in
                card.viewController.view.frame.size.height -= self.extendedEdgeDistance
                completion()
            }

        } else {
            completion()
        }

        self.moveCardsBack(cards, animated: animated)
    }

    func moveCardsBack(cards: [Card], animated: Bool) {
        let baseOffset: CGFloat = -60.0
        let offsetFraction: CGFloat = 1.75

        let baseScale: CGFloat = 0.9
        let scaleFraction: CGFloat = 0.9

        let baseOpacity: CGFloat =  0.5
        let opacityFraction: CGFloat = 0.6

        let springSpeed: CGFloat = 12.0
        let springBounciness: CGFloat = 2.0

        for (i, card) in enumerate(reverse(cards)) {
            let containerView = card.containerView
            let index = CGFloat(i)

            let offset = baseOffset * CGFloat(pow(offsetFraction, index))
            let scale = baseScale * CGFloat(pow(scaleFraction, index))
            let opacity = baseOpacity * CGFloat(pow(opacityFraction, index))

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
                containerView.layer.pop_addAnimation(scaleBackAnimation, forKey: "scaleBackAnimation")

                let opacityDownAnimation = POPSpringAnimation(propertyNamed: kPOPViewAlpha)
                opacityDownAnimation.toValue = opacity
                opacityDownAnimation.springSpeed = springSpeed
                opacityDownAnimation.springBounciness = springBounciness
                containerView.pop_addAnimation(opacityDownAnimation, forKey: "opacityDownAnimation")
            } else {
                let scaleTransform = CGAffineTransformMakeScale(scale, scale)
                let translationTransform = CGAffineTransformMakeTranslation(0.0, offset)
                let combinedTransform = CGAffineTransformConcat(scaleTransform, translationTransform)

                containerView.transform = combinedTransform
                containerView.alpha = opacity
            }
        }
    }

    func dismissCard(card: Card, remainingCards: [Card], animated: Bool, completion: (() -> Void)) {
        let containerView = card.containerView
        self.cards.removeLast()

        if animated {
            let dismissAnimation = POPSpringAnimation(propertyNamed: kPOPLayerTranslationY)
            dismissAnimation.toValue = containerView.frame.height - self.extendedEdgeDistance
            dismissAnimation.springSpeed = 12.0
            dismissAnimation.springBounciness = 0.0
            containerView.layer.pop_addAnimation(dismissAnimation, forKey: "dismissAnimation")
            dismissAnimation.completionBlock = { _ in
                containerView.removeFromSuperview()
                completion()
            }

        } else {
            containerView.removeFromSuperview()
            completion()
        }

        self.moveCardsForward(self.cards, animated: animated)
    }

    func moveCardsForward(cards: [Card], animated: Bool) {
        for (i, card) in enumerate(reverse(cards)) {
            let containerView = card.containerView
            let index = CGFloat(i)

            let baseOffset: CGFloat = -60.0
            let offsetFraction: CGFloat = 1.75

            let baseScale: CGFloat = 0.9
            let scaleFraction: CGFloat = 0.9

            let baseOpacity: CGFloat =  0.5
            let opacityFraction: CGFloat = 0.6

            let offset: CGFloat
            let scale: CGFloat
            let opacity: CGFloat

            if i == 0 {
                offset = 0.0
                scale = 1.0
                opacity = 1.0
            } else {
                offset = baseOffset * CGFloat(pow(offsetFraction, index - 1))
                scale = baseScale * CGFloat(pow(scaleFraction, index - 1))
                opacity = baseOpacity * CGFloat(pow(opacityFraction, index - 1))
            }

            if animated {
                let springSpeed: CGFloat = 12.0
                let springBounciness: CGFloat = 0.0

                let moveUpAnimation = POPSpringAnimation(propertyNamed: kPOPLayerTranslationY)
                moveUpAnimation.toValue = offset
                moveUpAnimation.springSpeed = springSpeed
                moveUpAnimation.springBounciness = springBounciness
                containerView.layer.pop_addAnimation(moveUpAnimation, forKey: "moveUpAnimation")

                let scaleBackAnimation = POPSpringAnimation(propertyNamed: kPOPLayerScaleXY)
                scaleBackAnimation.toValue = NSValue(CGPoint: CGPoint(x: scale, y: scale))
                scaleBackAnimation.springSpeed = springSpeed
                scaleBackAnimation.springBounciness = springBounciness
                containerView.layer.pop_addAnimation(scaleBackAnimation, forKey: "scaleBackAnimation")

                let opacityDownAnimation = POPSpringAnimation(propertyNamed: kPOPViewAlpha)
                opacityDownAnimation.toValue = opacity
                opacityDownAnimation.springSpeed = springSpeed
                opacityDownAnimation.springBounciness = springBounciness
                containerView.pop_addAnimation(opacityDownAnimation, forKey: "opacityDownAnimation")

            } else {
                let scaleTransform = CGAffineTransformMakeScale(scale, scale)
                let translationTransform = CGAffineTransformMakeTranslation(0.0, offset)
                let combinedTransform = CGAffineTransformConcat(scaleTransform, translationTransform)
                containerView.transform = combinedTransform
                containerView.alpha = opacity
            }
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

        containerView.addSubview(dismissButton)

        containerView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|[button]|", options: .allZeros, metrics: nil, views: ["button": dismissButton]))
        containerView.addConstraint(NSLayoutConstraint(item: dismissButton, attribute: .Top, relatedBy: .Equal, toItem: containerView, attribute: .Top, multiplier: 1.0, constant: 0.0))

        containerView.addConstraint(NSLayoutConstraint(item: childView, attribute: .Top, relatedBy: .Equal, toItem: containerView, attribute: .Top, multiplier: 1.0, constant: 0.0))

        containerView.addConstraint(NSLayoutConstraint(item: childView, attribute: .Bottom, relatedBy: .Equal, toItem: containerView, attribute: .Bottom, multiplier: 1.0, constant: -self.extendedEdgeDistance))
        containerView.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|[child]|", options: .allZeros, metrics: nil, views: ["child": childView]))

        containerView.layer.borderColor = UIColor.clearColor().CGColor
        containerView.layer.masksToBounds = true
        containerView.layer.borderWidth = 1.0
        containerView.layer.cornerRadius = 4.0
        
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
}