//
//  AXPhotosTransitionController.swift
//  AXPhotoViewer
//
//  Created by Alex Hill on 6/4/17.
//  Copyright © 2017 Alex Hill. All rights reserved.
//

import UIKit

#if os(iOS)
import FLAnimatedImage
#elseif os(tvOS)
import FLAnimatedImage_tvOS
#endif

class AXPhotosTransitionController: NSObject, UIViewControllerTransitioningDelegate, AXPhotosTransitionAnimatorDelegate {
    
    fileprivate static let supportedModalPresentationStyles: [UIModalPresentationStyle] =  [.fullScreen,
                                                                                            .currentContext,
                                                                                            .custom,
                                                                                            .overFullScreen,
                                                                                            .overCurrentContext]
    
    weak var delegate: AXPhotosTransitionControllerDelegate?
    
    /// Custom animator for presentation.
    fileprivate var presentationAnimator: AXPhotosPresentationAnimator?
    
    /// Custom animator for dismissal.
    fileprivate var dismissalAnimator: AXPhotosDismissalAnimator?
    
    /// If this flag is `true`, the transition controller will ignore any user gestures and instead trigger an immediate dismissal.
    var forceNonInteractiveDismissal = false

    /// The transition configuration passed in at initialization. The controller uses this object to apply customization to the transition.
    let transitionInfo: AXTransitionInfo
    
    fileprivate var supportsContextualPresentation: Bool {
        get {
            return (self.transitionInfo.startingView != nil)
        }
    }
    
    fileprivate var supportsContextualDismissal: Bool {
        get {
            return (self.transitionInfo.endingView != nil)
        }
    }
    
    fileprivate var supportsInteractiveDismissal: Bool {
        get {
            #if os(iOS)
            return self.transitionInfo.interactiveDismissalEnabled
            #else
            return false
            #endif
        }
    }
    
    init(transitionInfo: AXTransitionInfo) {
        self.transitionInfo = transitionInfo
        super.init()
    }
    
    // MARK: - UIViewControllerTransitioningDelegate
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard let dismissed = dismissed as? AXPhotosViewController else {
            assertionFailure("Dismissed VC should always be an AXPhotosViewController!")
            return nil
        }
        
        guard let photo = dismissed.dataSource.photo(at: dismissed.currentPhotoIndex) else {
            return nil
        }
        
        // resolve transitionInfo's endingView
        self.transitionInfo.resolveEndingViewClosure?(photo, dismissed.currentPhotoIndex)
        
        if !type(of: self).supportedModalPresentationStyles.contains(dismissed.modalPresentationStyle) {
            return nil
        }
        
        if !self.supportsContextualDismissal && !self.supportsInteractiveDismissal {
            return nil
        }
        
        self.dismissalAnimator = self.dismissalAnimator ?? AXPhotosDismissalAnimator(transitionInfo: self.transitionInfo)
        self.dismissalAnimator?.delegate = self
        
        return self.dismissalAnimator
    }
    
    public func animationController(forPresented presented: UIViewController,
                                    presenting: UIViewController,
                                    source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        
        guard let presented = presented as? AXPhotosViewController else {
            assertionFailure("Presented VC should always be an AXPhotosViewController!")
            return nil
        }
        
        if !type(of: self).supportedModalPresentationStyles.contains(presented.modalPresentationStyle) {
            return nil
        }
        
        if !self.supportsContextualPresentation {
            return nil
        }
        
        self.presentationAnimator = AXPhotosPresentationAnimator(transitionInfo: self.transitionInfo)
        self.presentationAnimator?.delegate = self
        
        return self.presentationAnimator
    }
    
    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        if !self.supportsInteractiveDismissal || self.forceNonInteractiveDismissal {
            return nil
        }
        
        self.dismissalAnimator = self.dismissalAnimator ?? AXPhotosDismissalAnimator(transitionInfo: self.transitionInfo)
        self.dismissalAnimator?.delegate = self
        
        return self.dismissalAnimator
    }
    
    #if os(iOS)
    // MARK: - Interaction handling
    public func didPanWithGestureRecognizer(_ sender: UIPanGestureRecognizer, in viewController: UIViewController) {
        self.dismissalAnimator?.didPanWithGestureRecognizer(sender, in: viewController)
    }
    #endif
    
    // MARK: - AXPhotosTransitionAnimatorDelegate
    func transitionAnimator(_ animator: AXPhotosTransitionAnimator, didCompletePresentationWith transitionView: UIImageView) {
        self.delegate?.transitionController(self, didCompletePresentationWith: transitionView)
        self.presentationAnimator = nil
    }
    
    func transitionAnimator(_ animator: AXPhotosTransitionAnimator, didCompleteDismissalWith transitionView: UIImageView) {
        self.delegate?.transitionController(self, didCompleteDismissalWith: transitionView)
        self.dismissalAnimator = nil
    }
    
    func transitionAnimatorDidCancelDismissal(_ animator: AXPhotosTransitionAnimator) {
        self.delegate?.transitionControllerDidCancelDismissal(self)
        self.dismissalAnimator = nil
    }
    
}

protocol AXPhotosTransitionControllerDelegate: class {
    func transitionController(_ transitionController: AXPhotosTransitionController, didCompletePresentationWith transitionView: UIImageView)
    func transitionController(_ transitionController: AXPhotosTransitionController, didCompleteDismissalWith transitionView: UIImageView)
    func transitionControllerDidCancelDismissal(_ transitionController: AXPhotosTransitionController)
}