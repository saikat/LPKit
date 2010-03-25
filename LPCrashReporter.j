/*
 * LPCrashReporter.j
 * LPKit
 *
 * Created by Ludwig Pettersson on February 19, 2010.
 * 
 * The MIT License
 * 
 * Copyright (c) 2010 Ludwig Pettersson
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 * 
 */
 
@import <Foundation/CPObject.j>
@import <AppKit/CPCheckBox.j>
@import <AppKit/CPAlert.j>
@import <LPKit/LPURLPostRequest.j>
@import <LPKit/LPMultiLineTextField.j>

var sharedErrorLoggerInstance = nil;


@implementation LPCrashReporter : CPObject
{
    CPException _exception @accessors(property=exception);
    id _delegate @accessors(property=delegate);
    CPWindow _overlayWindow; 
    CPWindow reportWindow;
}

+ (id)sharedErrorLogger
{
    if (!sharedErrorLoggerInstance)
        sharedErrorLoggerInstance = [[LPCrashReporter alloc] init];
    
    return sharedErrorLoggerInstance;
}

- (void)didCatchException:(CPException)anException
{
    if ([self shouldInterceptException])
    {
        if (_exception)
            return;
        
        _exception = anException;
        
        overlayWindow = [[LPCrashReporterOverlayWindow alloc] initWithContentRect:CGRectMakeZero() styleMask:CPBorderlessBridgeWindowMask];
        [overlayWindow setLevel:CPNormalWindowLevel];
        [overlayWindow makeKeyAndOrderFront:nil];
        
        reportWindow = [[LPCrashReporterReportWindow alloc] initWithContentRect:CGRectMake(0,0,460,0) styleMask:CPTitledWindowMask | CPResizableWindowMask delegate:_delegate];
        [CPApp runModalForWindow:reportWindow];
    }
    else
    {
        shouldCatchExceptions = NO;
        [anException raise];
    }
}

- (BOOL)shouldInterceptException
{
    if (_delegate && [_delegate respondsToSelector:@selector(crashReporterShouldInterceptExceptions)])
        return [_delegate crashReporterShouldInterceptExceptions];

    return YES;
}

- (void)close
{
    _exception = nil;
    [CPApp stopModal];
    [overlayWindow orderOut:self];
    [reportWindow orderOut:self];
}
@end


@implementation LPCrashReporterOverlayWindow : CPWindow
{
    
}

- (void)initWithContentRect:(CGRect)aContentRect styleMask:(id)aStyleMask
{
    if (self = [super initWithContentRect:aContentRect styleMask:aStyleMask])
    {
        [[self contentView] setBackgroundColor:[CPColor colorWithWhite:0 alpha:0.4]];
    }
    return self;
}

@end


@implementation LPCrashReporterReportWindow : CPWindow
{
    CPTextField errorMessage;
    
    CPTextField informationLabel;
    LPMultiLineTextField informationTextField;
    
    CPTextField descriptionLabel;
    LPMultiLineTextField descriptionTextField;
    
    CPButton sendButton;
    
    id delegate;
    CPCheckBox detailsOption;
    
    CPTextField sendingLabel;
}

- (void)initWithContentRect:(CGRect)aContentRect styleMask:(id)aStyleMask delegate:(id)aDelegate
{
    if (self = [super initWithContentRect:aContentRect styleMask:aStyleMask])
    {
        delegate = aDelegate;
        var contentView = [self contentView],
            applicationName = [[CPBundle mainBundle] objectForInfoDictionaryKey:@"CPBundleName"];
        
        [self setMinSize:aContentRect.size];
        [self setTitle:[CPString stringWithFormat:@"Problem Report for %@", applicationName]];
        
        var appName = [[CPBundle mainBundle] objectForInfoDictionaryKey:@"CPBundleName"],
            message = [CPString stringWithFormat:@"%@ has had an unexpected error. %@  will try to keep going after you report this problem, but it may stop functioning properly.  We suggest you save your work and reload the application.", appName, appName];
        
        errorMessage = [CPTextField labelWithTitle:message];
        
        var size = [message sizeWithFont:[errorMessage currentValueForThemeAttribute:@"font"] inWidth:CGRectGetWidth(aContentRect) - 15];
        [errorMessage setLineBreakMode:CPLineBreakByWordWrapping];
        [errorMessage setFrame:CGRectMake(12, 12, size.width, size.height + 10)];
        [contentView addSubview:errorMessage];

        informationLabel = [CPTextField labelWithTitle:@"Problem and system information:"];
        [informationLabel setFrameOrigin:CGPointMake(12,64)];
        [contentView addSubview:informationLabel];
        
        var informationTextValue = [CPString stringWithFormat:@"User-Agent: %@\n\nException: %@",
                                                              navigator.userAgent, [[LPCrashReporter sharedErrorLogger] exception]];
        informationTextField = [LPMultiLineTextField textFieldWithStringValue:informationTextValue placeholder:@"" width:0];
        [informationTextField setEditable:NO];
        [informationTextField setFrame:CGRectMake(12, 83, CGRectGetWidth(aContentRect) - 24, 100)];
        [informationTextField setAutoresizingMask:CPViewWidthSizable];
        [contentView addSubview:informationTextField];
        
        descriptionLabel = [CPTextField labelWithTitle:@"Please describe what you were doing when the problem happened:"];
        [descriptionLabel setFrameOrigin:CGPointMake(12,189)];
        [contentView addSubview:descriptionLabel];
        
        descriptionTextField = [LPMultiLineTextField textFieldWithStringValue:@"" placeholder:@"" width:0];
        [descriptionTextField setFrame:CGRectMake(CGRectGetMinX([informationTextField frame]), CGRectGetMaxY([descriptionLabel frame]) + 1, CGRectGetWidth([informationTextField frame]), 100)];
        [contentView addSubview:descriptionTextField];

        var buttonY = 318;
        if (delegate && [delegate respondsToSelector:@selector(crashReporterShouldHaveDetailsOption)] && [delegate crashReporterShouldHaveDetailsOption])
        {
            if ([delegate respondsToSelector:@selector(crashReporterDetailsLabel)])
                detailsOption = [CPCheckBox checkBoxWithTitle:[delegate crashReporterDetailsLabel]];
            else
                detailsOption = [CPCheckBox checkBoxWithTitle:"Share additional details privately so that we can fix this problem faster."];
            [detailsOption setObjectValue:CPOnState];
            var textSize = [[detailsOption title] sizeWithFont:[detailsOption currentValueForThemeAttribute:@"font"] inWidth:CGRectGetWidth(aContentRect) - 15];
            [detailsOption setFrameSize:textSize];
            [detailsOption setValue:CPLineBreakByWordWrapping forThemeAttribute:@"line-break-mode"];
            [detailsOption setFrameOrigin:CGPointMake(12, 318)];
            buttonY = 318 + [detailsOption frame].size.height + 10;
            [contentView addSubview:detailsOption];
        }
	  
        sendButton = [CPButton buttonWithTitle:[CPString stringWithFormat:@"Send to %@", applicationName]];
        [sendButton setFrameOrigin:CGPointMake(CGRectGetWidth(aContentRect) - CGRectGetWidth([sendButton frame]) - 15, buttonY)];
        [sendButton setTarget:self];
        [sendButton setAction:@selector(didClickSendButton:)];
        [contentView addSubview:sendButton];
        [self setDefaultButton:sendButton];
        
        [self setFrameSize:CGSizeMake(CGRectGetWidth([self frame]), CGRectGetMaxY([sendButton frame]) + 40)];
        [descriptionTextField setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
        [detailsOption setAutoresizingMask:CPViewMinYMargin];
        [sendButton setAutoresizingMask:CPViewMinXMargin | CPViewMinYMargin];
        
        sendingLabel = [CPTextField labelWithTitle:@"Sending Report..."];
        [sendingLabel setFont:[CPFont boldSystemFontOfSize:11]];
        [sendingLabel sizeToFit];
        [sendingLabel setFrameOrigin:CGPointMake(12, CGRectGetMaxY([self frame]) - 35)];
        [sendingLabel setHidden:YES];
        [contentView addSubview:sendingLabel];
    
    }
    return self;
}

- (void)orderFront:(id)sender
{
    [super orderFront:sender];
    [self makeFirstResponder:descriptionTextField];
}

- (void)didClickSendButton:(id)sender
{
    [informationTextField setEnabled:NO];
    [descriptionTextField setEnabled:NO];
    [sendButton setEnabled:NO];
    [informationLabel setAlphaValue:0.5];
    [descriptionLabel setAlphaValue:0.5];
    
    [sendingLabel setHidden:NO];
    
    var loggingURL = [CPURL URLWithString:[[CPBundle mainBundle] objectForInfoDictionaryKey:@"LPCrashReporterLoggingURL"] || @"/"],
        request = [LPURLPostRequest requestWithURL:loggingURL],
        exception = [[LPCrashReporter sharedErrorLogger] exception],
        content = {'name': [exception name] ? [exception name] : ([exception isKindOfClass:[CPString class]] ? exception : nil), 'reason': [exception reason] ? [exception reason] : nil,
                   'userAgent': navigator.userAgent, 'description': [descriptionTextField stringValue]};
 
    if (delegate && detailsOption && [detailsOption objectValue] == CPOnState && [delegate respondsToSelector:@selector(detailsForCrashReporter)]) 
        content['details'] = [delegate detailsForCrashReporter];

    [request setHTTPBody:[CPString JSONFromObject:content]];
    [CPURLConnection connectionWithRequest:request delegate:self];
}

/*
    CPURLConnection delegate methods:
*/

- (void)connection:(CPURLConnection)aConnection didReceiveData:(id)aData
{
    [[LPCrashReporter sharedErrorLogger] close];
}
@end

/*
    Let the monkey patching begin
*/

var original_objj_msgSend = objj_msgSend,
    shouldCatchExceptions = YES;

objj_msgSend = function()
{
    if (!shouldCatchExceptions)
        return original_objj_msgSend.apply(this, arguments);
    
    try
    {
        return original_objj_msgSend.apply(this, arguments);
    }
    catch (anException)
    {
        [[LPCrashReporter sharedErrorLogger] didCatchException:anException];
        return nil;
    }
}
