// CardPopAnimation.swift
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
// THE SOFTWARE.Kit

import UIKit

class CardPopAnimation: NSObject, CardAnimation {
    let cardStack: CardStack
    let card: UIView
    let dynamicAnimator: UIDynamicAnimator
    let completion: CompletionBlock?

    var isRunning: Bool {
        return dynamicAnimator.behaviors.count > 0
    }

    required init(cardStack: CardStack, card: UIView, completion: CompletionBlock?) {
        self.cardStack = cardStack
        self.card = card
        self.dynamicAnimator = UIDynamicAnimator(referenceView: cardStack)
        self.completion = completion
        super.init()

        self.dynamicAnimator.delegate = self
    }

    func start() {
        assert(!isRunning, "Attempt to start a \(self) that is already running")

        let dynamicBehvaior = UIDynamicItemBehavior(items: [card])
        dynamicBehvaior.allowsRotation = false
        dynamicAnimator.addBehavior(dynamicBehvaior)

        var frame = card.frame
        frame.origin.y = cardStack.bounds.maxY
        let snapBehavior = UISnapBehavior(item: card, snapToPoint: CGPoint(x: card.center.x, y: frame.midY))
        dynamicAnimator.addBehavior(snapBehavior)
    }

    func stop() {
        dynamicAnimator.removeAllBehaviors()
    }
}

extension CardPopAnimation: UIDynamicAnimatorDelegate {
    func dynamicAnimatorDidPause(animator: UIDynamicAnimator) {
        stop()
        completion?()
    }
}