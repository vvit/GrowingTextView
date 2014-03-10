//
//  HPTextView.m
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

#import "HPGrowingTextView.h"
#import "HPTextViewInternal.h"

@interface HPGrowingTextView(private)
- (void)commonInitialiser;
- (void)resizeTextView:(NSInteger)newSizeH;
- (void)growDidStop;
@end

@implementation HPGrowingTextView
{
    HPTextViewInternal *_internalTextView;
}

@synthesize internalTextView = _internalTextView;

@dynamic placeholder;
@dynamic placeholderColor;

// having initwithcoder allows us to use HPGrowingTextView in a Nib. -- aob, 9/2011
- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self commonInitialiser];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        [self commonInitialiser];
    }
    return self;
}

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 70000
- (id)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)textContainer
{
    if ((self = [super initWithFrame:frame])) {
        [self commonInitialiser:textContainer];
    }
    return self;
}

- (void)commonInitialiser
{
    [self commonInitialiser:nil];
}

- (void)commonInitialiser:(NSTextContainer *)textContainer
#else
- (void)commonInitialiser
#endif
{
    // Initialization code
    CGRect r = self.frame;
    r.origin.y = 0;
    r.origin.x = 0;
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 70000
    _internalTextView = [[HPTextViewInternal alloc] initWithFrame:r textContainer:textContainer];
#else
    _internalTextView = [[HPTextViewInternal alloc] initWithFrame:r];
#endif
    _internalTextView.delegate = self;
    _internalTextView.scrollEnabled = NO;
    _internalTextView.font = [UIFont fontWithName:@"Helvetica" size:13];
    _internalTextView.contentInset = UIEdgeInsetsZero;
    _internalTextView.showsHorizontalScrollIndicator = NO;
    _internalTextView.text = @"-";
    _internalTextView.contentMode = UIViewContentModeRedraw;
    [self addSubview:_internalTextView];
    
    _minHeight = _internalTextView.frame.size.height;
    _minNumberOfLines = 1;
    
    _animateHeightChange = YES;
    _animationDuration = 0.1f;
    
    _internalTextView.text = @"";
    
    [self setMaxNumberOfLines:3];
    
    [self setPlaceholderColor:[UIColor lightGrayColor]];
    _internalTextView.displayPlaceHolder = YES;
    
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
    {
        // Used to correct the scroll position after loading the view on iOS < 7
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *previousText = self.text;
            self.text = @"\n";
            self.text = previousText;
        });
    }
}

- (CGSize)sizeThatFits:(CGSize)size
{
    if (self.text.length == 0)
    {
        size.height = _minHeight;
    }
    
    return size;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect r = self.bounds;
    r.origin.y = _contentInset.top;
    r.origin.x = _contentInset.left;
    r.size.width -= _contentInset.left + _contentInset.right;
    r.size.height -= _contentInset.top + _contentInset.bottom;
    
    // Fixing vertical fighting during height animations.
    if (!CGRectEqualToRect(_internalTextView.frame, r))
    {
        _internalTextView.frame = r;
    }
}

- (void)setContentInset:(UIEdgeInsets)contentInset
{
    _contentInset = contentInset;
    
    CGRect r = self.frame;
    r.origin.y = contentInset.top;
    r.origin.x = contentInset.left;
    r.size.width -= contentInset.left + contentInset.right;
    r.size.height -= contentInset.top + contentInset.bottom;
    
    _internalTextView.frame = r;
    
    [self setMaxNumberOfLines:_maxNumberOfLines];
    [self setMinNumberOfLines:_minNumberOfLines];
}

- (void)setMaxNumberOfLines:(NSUInteger)maxNumberOfLines
{
    if (maxNumberOfLines == 0 && _maxHeight > 0) return; // the user specified a maxHeight themselves.
    
    // Use internalTextView for height calculations, thanks to Gwynne <http://blog.darkrainfall.org/>
    NSString *saveText = _internalTextView.text, *newText = @"-";
    
    _internalTextView.delegate = nil;
    _internalTextView.hidden = YES;
    
    for (NSUInteger i = 1; i < maxNumberOfLines; ++i)
    {
        newText = [newText stringByAppendingString:@"\n|W|"];
    }
    
    _internalTextView.text = newText;
    
    _maxHeight = [self measureHeight];
    
    _internalTextView.text = saveText;
    _internalTextView.hidden = NO;
    _internalTextView.delegate = self;
    
    [self sizeToFit];
    
    _maxNumberOfLines = maxNumberOfLines;
}

- (void)setMaxHeight:(NSUInteger)maxHeight
{
    _maxHeight = maxHeight;
    _maxNumberOfLines = 0;
}

- (void)setMinNumberOfLines:(NSUInteger)minNumberOfLines
{
    if (minNumberOfLines == 0 && _minHeight > 0) return;     // The user specified a minHeight themselves.
    
    // Use internalTextView for height calculations, thanks to Gwynne <http://blog.darkrainfall.org/>.
    NSString *saveText = _internalTextView.text, *newText = @"-";
    
    _internalTextView.delegate = nil;
    _internalTextView.hidden = YES;
    
    for (int i = 1; i < minNumberOfLines; ++i)
    {
        newText = [newText stringByAppendingString:@"\n|W|"];
    }
    
    _internalTextView.text = newText;
    
    _minHeight = [self measureHeight];
    
    _internalTextView.text = saveText;
    _internalTextView.hidden = NO;
    _internalTextView.delegate = self;
    
    [self sizeToFit];
    
    _minNumberOfLines = minNumberOfLines;
}

- (void)setMinHeight:(NSUInteger)minHeight
{
    _minHeight = minHeight;
    _minNumberOfLines = 0;
}

- (NSString *)placeholder
{
    return _internalTextView.placeholder;
}

- (void)setPlaceholder:(NSString *)placeholder
{
    [_internalTextView setPlaceholder:placeholder];
    [_internalTextView setNeedsDisplay];
}

- (UIColor *)placeholderColor
{
    return _internalTextView.placeholderColor;
}

- (void)setPlaceholderColor:(UIColor *)placeholderColor
{
    [_internalTextView setPlaceholderColor:placeholderColor];
}

- (void)textViewDidChange:(UITextView *)textView
{
    [self refreshHeight];
}

- (void)refreshHeight
{
    NSInteger newSizeH = [self measureHeight] + _contentInset.top + _contentInset.bottom;
    
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
    {
        // Size the content to min and max height.
        CGFloat topInternalContentInset = self.internalTextView.contentInset.top;
        CGFloat bottomInternalContentInset = self.internalTextView.contentInset.bottom;
        
        newSizeH += topInternalContentInset + bottomInternalContentInset;
    }
    
    if (newSizeH < _minHeight + _contentInset.top + _contentInset.bottom || !_internalTextView.hasText) {
        newSizeH = _minHeight + _contentInset.top + _contentInset.bottom;
    }
    
    if (_maxHeight && newSizeH > _maxHeight)
    {
        newSizeH = _maxHeight;
    }
    
    if (_internalTextView.frame.size.height != newSizeH)
    {
        // [Fixed] Pasting too much text into the view failed to fire the height change,
        // thanks to Gwynne <http://blog.darkrainfall.org/>.
        if (newSizeH <= _maxHeight)
        {
            if(_animateHeightChange)
            {
                if ([UIView resolveClassMethod:@selector(animateWithDuration:animations:)])
                {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
                    [UIView animateWithDuration:_animationDuration
                                          delay:0
                                        options:(UIViewAnimationOptionAllowUserInteraction|
                                                 UIViewAnimationOptionBeginFromCurrentState)
                                     animations:^(void) {
                                         [self resizeTextView:newSizeH];
                                     }
                                     completion:^(BOOL finished) {
                                         [self growDidStop];
                                     }];
#endif
                }
                else
                {
                    [UIView beginAnimations:@"" context:nil];
                    [UIView setAnimationDuration:_animationDuration];
                    [UIView setAnimationDelegate:self];
                    [UIView setAnimationDidStopSelector:@selector(growDidStop)];
                    [UIView setAnimationBeginsFromCurrentState:YES];
                    [self resizeTextView:newSizeH];
                    [UIView commitAnimations];
                }
            }
            else
            {
                [self resizeTextView:newSizeH];
                
                // [Fixed] The growingTextView:didChangeHeight: delegate method was not called at all when not animating height changes.
                // Thanks to Gwynne <http://blog.darkrainfall.org/>.
                
                if ([_delegate respondsToSelector:@selector(growingTextView:didChangeHeight:)])
                {
                    [_delegate growingTextView:self didChangeHeight:newSizeH];
                }
            }
        }
    }
    
    // Display (or not) the placeholder string.
    BOOL wasDisplayingPlaceholder = _internalTextView.displayPlaceHolder;
    _internalTextView.displayPlaceHolder = _internalTextView.text.length == 0;
    
    if (wasDisplayingPlaceholder != _internalTextView.displayPlaceHolder)
    {
        [_internalTextView setNeedsDisplay];
    }
    
    // Scroll to caret (needed on iOS7).
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
    {
        [self performSelector:@selector(resetScrollPositionForIOS7) withObject:nil afterDelay:0.1f];
    }
    
    // Tell the delegate that the text view changed.
    if ([_delegate respondsToSelector:@selector(growingTextViewDidChange:)])
    {
        [_delegate growingTextViewDidChange:self];
    }
}

// Code from apple developer forum - @Steve Krulewitz, @Mark Marszal, @Eric Silverberg.
- (CGFloat)measureHeight
{
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
    {
        return ceilf([self.internalTextView sizeThatFits:self.internalTextView.frame.size].height);
    }
    else
    {
        return self.internalTextView.contentSize.height - 8.0;
    }
}

- (void)resetScrollPositionForIOS7
{
    CGRect r = [_internalTextView caretRectForPosition:_internalTextView.selectedTextRange.end];
    CGFloat caretY =  MAX(r.origin.y - _internalTextView.frame.size.height + r.size.height + 8, 0);
    
    if (_internalTextView.contentOffset.y < caretY && r.origin.y != INFINITY)
    {
        _internalTextView.contentOffset = CGPointMake(0, caretY);
    }
}

- (void)correctScrolling
{
    // If our new height is greater than the maxHeight
    // set scroll enabled.
    if (self.frame.size.height >= _maxHeight)
    {
        if (!_internalTextView.scrollEnabled)
        {
            _internalTextView.scrollEnabled = YES;
            [_internalTextView flashScrollIndicators];
            
            // When copy and pasting a multi-line text if height exceeds maxheight
            // the text view does not scroll even though scrollEnabled is set ON.
            // Laying out the subviews appears to fixes it.
            [_internalTextView performSelector:@selector(setNeedsLayout) withObject:nil afterDelay:.3];
        }
    }
    else
    {
        _internalTextView.scrollEnabled = NO;
    }
}

-(void)resizeTextView:(NSInteger)newSizeH
{
    if ([_delegate respondsToSelector:@selector(growingTextView:willChangeHeight:)])
    {
        [_delegate growingTextView:self willChangeHeight:newSizeH];
    }
    
    CGRect internalTextViewFrame = self.frame;
    internalTextViewFrame.size.height = newSizeH; // + padding
    self.frame = internalTextViewFrame;
    
    internalTextViewFrame.origin.y = _contentInset.top;
    internalTextViewFrame.origin.x = _contentInset.left;
    internalTextViewFrame.size.width -= _contentInset.left + _contentInset.right;
    internalTextViewFrame.size.height -= _contentInset.top + _contentInset.bottom;
    
    if (!CGRectEqualToRect(_internalTextView.frame, internalTextViewFrame))
    {
        _internalTextView.frame = internalTextViewFrame;
    }
    
    [self correctScrolling];
}

- (void)growDidStop
{
    // Scroll to caret (needed on iOS7).
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
    {
        [self resetScrollPositionForIOS7];
    }
    
    if ([_delegate respondsToSelector:@selector(growingTextView:didChangeHeight:)])
    {
        [_delegate growingTextView:self didChangeHeight:self.frame.size.height];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [_internalTextView becomeFirstResponder];
}

- (BOOL)becomeFirstResponder
{
    [super becomeFirstResponder];
    
    return [self.internalTextView becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
    [super resignFirstResponder];
    
    return [_internalTextView resignFirstResponder];
}

- (BOOL)isFirstResponder
{
    return [self.internalTextView isFirstResponder];
}


#pragma mark UITextView properties

- (void)setText:(NSString *)newText
{
    _internalTextView.text = newText;
    
    // Include this line to analyze the height of the UITextView.
    // Fix from Ankit Thakur.
    [self performSelector:@selector(textViewDidChange:) withObject:_internalTextView];
}

- (NSString*) text
{
    return _internalTextView.text;
}

- (void)setFont:(UIFont *)afont
{
    _internalTextView.font= afont;
    
    [self setMaxNumberOfLines:_maxNumberOfLines];
    [self setMinNumberOfLines:_minNumberOfLines];
}

- (UIFont *)font
{
    return _internalTextView.font;
}

- (void)setTextColor:(UIColor *)color
{
    _internalTextView.textColor = color;
}

- (UIColor*)textColor
{
    return _internalTextView.textColor;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    _internalTextView.backgroundColor = backgroundColor;
}

- (UIColor*)backgroundColor
{
    return _internalTextView.backgroundColor;
}

- (void)setTextAlignment:(NSTextAlignment)aligment
{
    _internalTextView.textAlignment = aligment;
}

- (NSTextAlignment)textAlignment
{
    return _internalTextView.textAlignment;
}

- (void)setSelectedRange:(NSRange)range
{
    _internalTextView.selectedRange = range;
}

- (NSRange)selectedRange
{
    return _internalTextView.selectedRange;
}

- (void)setIsScrollable:(BOOL)isScrollable
{
    _internalTextView.scrollEnabled = isScrollable;
}

- (BOOL)isScrollable
{
    return _internalTextView.scrollEnabled;
}

- (void)setEditable:(BOOL)editable
{
    _internalTextView.editable = editable;
}

- (BOOL)isEditable
{
    return _internalTextView.editable;
}

- (void)setReturnKeyType:(UIReturnKeyType)keyType
{
    _internalTextView.returnKeyType = keyType;
}

- (UIReturnKeyType)returnKeyType
{
    return _internalTextView.returnKeyType;
}

- (void)setKeyboardType:(UIKeyboardType)keyType
{
    _internalTextView.keyboardType = keyType;
}

- (UIKeyboardType)keyboardType
{
    return _internalTextView.keyboardType;
}

- (void)setEnablesReturnKeyAutomatically:(BOOL)enablesReturnKeyAutomatically
{
    _internalTextView.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically;
}

- (BOOL)enablesReturnKeyAutomatically
{
    return _internalTextView.enablesReturnKeyAutomatically;
}

- (void)setDataDetectorTypes:(UIDataDetectorTypes)datadetector
{
    _internalTextView.dataDetectorTypes = datadetector;
}

- (UIDataDetectorTypes)dataDetectorTypes
{
    return _internalTextView.dataDetectorTypes;
}

- (BOOL)hasText
{
    return [_internalTextView hasText];
}

- (void)scrollRangeToVisible:(NSRange)range
{
    [_internalTextView scrollRangeToVisible:range];
}

#pragma mark - UITextViewDelegate

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    if ([_delegate respondsToSelector:@selector(growingTextViewShouldBeginEditing:)])
    {
        return [_delegate growingTextViewShouldBeginEditing:self];
    }
    else
    {
        return YES;
    }
}

- (BOOL)textViewShouldEndEditing:(UITextView *)textView
{
    if ([_delegate respondsToSelector:@selector(growingTextViewShouldEndEditing:)])
    {
        return [_delegate growingTextViewShouldEndEditing:self];
    }
    else
    {
        return YES;
    }
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    if ([_delegate respondsToSelector:@selector(growingTextViewDidBeginEditing:)])
    {
        [_delegate growingTextViewDidBeginEditing:self];
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    if ([_delegate respondsToSelector:@selector(growingTextViewDidEndEditing:)])
    {
        [_delegate growingTextViewDidEndEditing:self];
    }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)atext
{
    // Weird 1 pixel bug when clicking backspace when textView is empty.
    if (![textView hasText] && [atext isEqualToString:@""]) return NO;
    
    // Added by bretdabaker: sometimes we want to handle this ourselves.
    if ([_delegate respondsToSelector:@selector(growingTextView:shouldChangeTextInRange:replacementText:)])
    {
        return [_delegate growingTextView:self shouldChangeTextInRange:range replacementText:atext];
    }
    
    if ([atext isEqualToString:@"\n"])
    {
        if ([_delegate respondsToSelector:@selector(growingTextViewShouldReturn:)])
        {
            if (![_delegate performSelector:@selector(growingTextViewShouldReturn:) withObject:self])
            {
                return YES;
            }
            else
            {
                [textView resignFirstResponder];
                return NO;
            }
        }
    }
    
    return YES;
}

- (void)textViewDidChangeSelection:(UITextView *)textView
{
    if ([_delegate respondsToSelector:@selector(growingTextViewDidChangeSelection:)])
    {
        [_delegate growingTextViewDidChangeSelection:self];
    }
}

@end
