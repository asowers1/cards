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

class CardPopAnimation: CardAnimation {
    let cardStack: CardStack
    let card: UIView
    let completion: CompletionBlock?

    var isRunning: Bool = false
    var delay = 0.0

    convenience init(cardStack: CardStack, card: UIView, completion: CompletionBlock?) {
        self.init(cardStack: cardStack, cards: [card], completion: completion)
    }

    required init(cardStack: CardStack, cards: [UIView], completion: CompletionBlock?) {
        self.cardStack = cardStack
        self.card = cards.first!
        self.completion = completion
    }

    func start() {
        assert(!isRunning, "Attempt to start a \(self) that is already running")
        self.isRunning = true

        UIView.animateWithDuration(0.3, delay: self.delay, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.0, options: .allZeros, animations: {

            self.card.frame.origin.y += 50.0
            self.card.alpha = 0.0

        }, completion: { completed in
            self.finish()
        })
    }

    func stop() {
        card.layer.removeAllAnimations()
    }

    func finish() {
        isRunning = false
        completion?()
    }
}