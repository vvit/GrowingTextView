//
//  HPTextViewInternal.m
//
//  Created by Hans Pinckaers on 29-06-10.
//
//  MIT License
//
//  Copyright (c) 2011 Hans Pinckaers
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

//  Edited by Rex Fenley.

#import "HPTextViewInternal.h"

@implementation HPTextViewInternal

- (void)setText:(NSString *)text
{
    // If one of GrowingTextView's superviews is a scrollView, and self.scrollEnabled == NO,
    // setting the text programatically will cause UIKit to search upwards until
    // it finds a scrollView with scrollEnabled == yes then scroll it erratically.
    // Setting scrollEnabled temporarily to YES prevents this.
    
    BOOL originalValue = self.scrollEnabled;
    
    [self setScrollEnabled:YES];
    [super setText:text];
    [self setScrollEnabled:originalValue];
}

- (void)setScrollable:(BOOL)isScrollable
{
    [super setScrollEnabled:isScrollable];
}

-(void)setContentOffset:(CGPoint)contentOffset
{
    // Fix "overscrolling" bug
    if (contentOffset.y > self.contentSize.height - self.frame.size.height && !self.decelerating && !self.tracking && !self.dragging)
    {
        contentOffset = CGPointMake(contentOffset.x, self.contentSize.height - self.frame.size.height);
    }
    
    [super setContentOffset:contentOffset];
}

-(void)setContentInset:(UIEdgeInsets)inset
{
    inset.top += self.extraInset.top;
    inset.bottom += self.extraInset.bottom;
    inset.left += self.extraInset.left;
    inset.right += self.extraInset.right;
    
    [super setContentInset:inset];
}

-(void)setContentSize:(CGSize)contentSize
{
    [super setContentSize:contentSize];
    
    if (self.selectedTextRange)
    {
        CGRect cursorRect = [self caretRectForPosition:self.selectedTextRange.start];
        [self scrollRectToVisible:cursorRect animated:YES];
    }
    else
    {
        [self scrollRangeToVisible:self.selectedRange];
    }
}

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    if (self.displayPlaceHolder && self.placeholder && self.placeholderColor)
    {
        UIEdgeInsets inset = self.contentInset;
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
        {
            inset = self.textContainerInset;
        }
        
        [UIView transitionWithView:self duration:.1 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            
            // iOS 7 only.
            if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
            {
                NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
                paragraphStyle.alignment = self.textAlignment;
                [self.placeholder drawInRect:CGRectMake(5.0 + inset.left, inset.top, self.frame.size.width - inset.left, self.frame.size.height) withAttributes:@{NSFontAttributeName:self.font, NSForegroundColorAttributeName:self.placeholderColor, NSParagraphStyleAttributeName:paragraphStyle}];
            }
            else
            {
                [self.placeholderColor set];
                [self.placeholder drawInRect:CGRectMake(8.0 + inset.left, 8.0, self.frame.size.width - inset.left - 8.0, self.frame.size.height) withFont:self.font];
            }
        } completion:nil];
    }
}

- (void)setPlaceholder:(NSString *)placeholder
{
    _placeholder = placeholder;
    
    [self setNeedsDisplay];
}

@end
