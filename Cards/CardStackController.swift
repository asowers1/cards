// CardStackController.Swift
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

public class CardStackController: UIViewController {

    public let cardStack: CardStack = CardStack()

    public func pushViewController(viewController: UIViewController) {
        self.pushViewController(viewController, animated: false, completion: nil)
    }

    public func pushViewController(viewController: UIViewController, animated: Bool, completion: (() -> Void)?) {
        self.addChildViewController(viewController)
        self.cardStack.pushCard(viewController.view, animated: animated, completion: completion)
        viewController.didMoveToParentViewController(self)
    }

    public func popViewController() {
        popViewController(animated: false, completion: nil)
    }

    public func popViewController(#animated: Bool, completion: (() -> Void)?) {
        if let viewController = childViewControllers.last as? UIViewController {
            viewController.willMoveToParentViewController(nil)
            self.cardStack.popCard(animated: animated, completion: completion)
            viewController.removeFromParentViewController()
        }
    }

    public func setViewControllers(viewControllers: [UIViewController], animated: Bool, completion: (() -> Void)?) {
        viewControllers.map { self.addChildViewController($0) }
        cardStack.setCards(viewControllers.map { $0.view }, animated: animated) {
            viewControllers.map { $0.didMoveToParentViewController(self) }
            completion?()
        }
    }

    public override func loadView() {
        self.view = cardStack
    }
}