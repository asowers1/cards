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
    let completion: CompletionBlock?

    var isRunning: Bool = false

    convenience init(cardStack: CardStack, card: UIView, completion: CompletionBlock?) {
        self.init(cardStack: cardStack, cards: [card], completion: completion)
    }

    required init(cardStack: CardStack, cards: [UIView], completion: CompletionBlock?) {
        self.cardStack = cardStack
        self.card = cards.first!
        self.completion = completion
        super.init()
    }

    func start() {
        assert(!isRunning, "Attempt to start a \(self) that is already running")
        self.isRunning = true

        UIView.animateKeyframesWithDuration(0.3, delay: 0.0, options: UIViewKeyframeAnimationOptions.CalculationModeLinear, animations: {

            UIView.addKeyframeWithRelativeStartTime(0.0, relativeDuration: 0.3) {
                self.card.frame.origin.y -= 20.0
            }

            UIView.addKeyframeWithRelativeStartTime(0.3, relativeDuration: 0.7) {
                self.card.frame.origin.y = self.cardStack.bounds.maxY
            }

        }) { completed in
            if let completion = self.completion {
                self.isRunning = false
                completion()
            }
        }
    }

    func stop() {
        card.layer.removeAllAnimations()
        isRunning = false
        completion?()
    }
}