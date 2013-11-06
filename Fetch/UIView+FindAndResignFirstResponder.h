//
//  UIView+FindAndResignFirstResponder.h
//  Apex
//
//  Created by Josh Barrow on 9/13/11.
//  Copyright (c) 2011 - 2012 ConnectPoint Resolution Systems, Inc. All rights reserved.
//

@import UIKit;

@interface UIView (FindAndResignFirstResponder)

/**
 *  Find what the current firstResponder is and resign it
 *
 *  @return If a firstResponder was found and resigned, return YES, else return NO
 */
-(BOOL)findAndResignFirstResponder;

@end
