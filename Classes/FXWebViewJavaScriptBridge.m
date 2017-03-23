//
//  FXWebViewJavaScriptBridge.m
//  TTTT
//
//  Created by 张大宗 on 2017/2/28.
//  Copyright © 2017年 张大宗. All rights reserved.
//

#import "FXWebViewJavaScriptBridge.h"
#import "FXLogMacros.h"

static NSString *jsBridgeCodeCache = nil;

@interface FXWebViewJavaScriptBridge ()

@property (nonatomic, weak) FX_WEB_VIEW_TYPE *webView;

@property (nonatomic, weak) FX_WEB_VIEW_DELEGATE_TYPE*webViewDelegate;

@property (nonatomic, assign) long uniqueId;

@property (nonatomic, strong) NSMutableArray* messageQueue;

@property (nonatomic, strong) NSMutableDictionary* responseCallbacks;

@property (nonatomic, strong) NSMutableDictionary* messageHandlers;

@end

@implementation FXWebViewJavaScriptBridge

+ (instancetype)bridgeForWebView:(FX_WEB_VIEW_TYPE *)webView{
    FXWebViewJavaScriptBridge* bridge = [[self alloc] init];
    if (bridge) {
        [bridge initWithWebView:webView];
    }
    return bridge;
}

- (void)dealloc {
    _webView.delegate = nil;
    _webView = nil;
    _webViewDelegate = nil;
}

- (void)initWithWebView:(FX_WEB_VIEW_TYPE *)webView{
    _webView = webView;
    _webView.delegate = self;
    self.messageQueue = [[NSMutableArray alloc] init];
    self.responseCallbacks = [[NSMutableDictionary alloc] init];
    self.messageHandlers = [[NSMutableDictionary alloc] init];
}

- (void)setJSBDelegate:(FX_WEB_VIEW_DELEGATE_TYPE *)delegate{
    _webViewDelegate = delegate;
}

- (void)registerHandler:(NSString *)handlerName handler:(FXWVJSBHandler)handler{
    _messageHandlers[handlerName] = [handler copy];
}

- (void)callHandler:(NSString *)handlerName data:(id)data responseCallback:(FXWVJSBResponseCallback)responseCallback{
    [self sendData:data responseCallback:responseCallback handlerName:handlerName];
}

- (void)disableJavscriptAlertBoxSafetyTimeout {
    [self sendData:nil responseCallback:nil handlerName:@"disableJavascriptAlertBoxSafetyTimeout"];
}

- (void)sendData:(id)data responseCallback:(FXWVJSBResponseCallback)responseCallback handlerName:(NSString*)handlerName{
    NSMutableDictionary* message = [NSMutableDictionary dictionary];
    
    if (data) {
        message[@"data"] = data;
    }
    
    if (responseCallback) {
        NSString* callbackId = [NSString stringWithFormat:@"objc_cb_%ld", ++_uniqueId];
        self.responseCallbacks[callbackId] = [responseCallback copy];
        message[@"callbackId"] = callbackId;
    }
    
    if (handlerName) {
        message[@"handlerName"] = handlerName;
    }
    
    [self queueMessage:message];
}

- (void)queueMessage:(FXWVJSBMessage*)message {
    if (self.messageQueue) {
        [self.messageQueue addObject:message];
    } else {
        [self dispatchMessage:message];
    }
}

- (void)dispatchMessage:(FXWVJSBMessage*)message {
    NSString *messageJSON = [self serializeMessage:message pretty:NO];
    [self log:@"SEND" json:messageJSON];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\f" withString:@"\\f"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2028" withString:@"\\u2028"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2029" withString:@"\\u2029"];
    
    NSString* javascriptCommand = [NSString stringWithFormat:@"WebViewJavascriptBridge.handleMessageFromNative('%@');", messageJSON];
    if ([[NSThread currentThread] isMainThread]) {
        [self.webView stringByEvaluatingJavaScriptFromString:javascriptCommand];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.webView stringByEvaluatingJavaScriptFromString:javascriptCommand];
        });
    }
}

- (NSString *)serializeMessage:(id)message pretty:(BOOL)pretty{
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:message options:(NSJSONWritingOptions)(pretty ? NSJSONWritingPrettyPrinted : 0) error:nil] encoding:NSUTF8StringEncoding];
}

- (NSArray*)deserializeMessageJSON:(NSString *)messageJSON {
    return [NSJSONSerialization JSONObjectWithData:[messageJSON dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
}

- (void)log:(NSString *)action json:(id)json {
#if DEBUG
    if (![json isKindOfClass:[NSString class]]) {
        json = [self serializeMessage:json pretty:YES];
    }
    FXLogDebug(@"FXWVJSB %@: %@",action,json);
#else
    if ([json isKindOfClass:[NSString class]]) {
        FXLogDebug(@"FXWVJSB %@: %@",action,json);
    }
#endif
}

#pragma mark UIWebViewDelegate
- (void)webViewDidStartLoad:(UIWebView *)webView{
    if (webView != _webView) { return; }
    
    __strong NSObject<UIWebViewDelegate>* strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
        [strongDelegate webViewDidFinishLoad:webView];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{
    if (webView != _webView) { return; }
    
    __strong NSObject<UIWebViewDelegate>* strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
        [strongDelegate webView:webView didFailLoadWithError:error];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if (webView != _webView) { return; }
    
    __strong NSObject<UIWebViewDelegate>* strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
        [strongDelegate webViewDidFinishLoad:webView];
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if (webView != _webView) { return YES; }
    NSURL *url = [request URL];
    __strong NSObject<UIWebViewDelegate>* strongDelegate = _webViewDelegate;
    if ([[url scheme] isEqualToString:FXCustomProtocolScheme]) {
        if ([[url host] isEqualToString:FXBridgeLoaded]) {
            [self injectJavascriptFile];
        } else if ([[url host] isEqualToString:FXQueueHasMessage]) {
            NSString *messageQueueString = [self.webView stringByEvaluatingJavaScriptFromString:@"WebViewJavascriptBridge.fetchQueue();"];
            [self flushMessageQueue:messageQueueString];
        } else {
            FXLogDebug(@"WebViewJavascriptBridge:Received unknown WebViewJavascriptBridge command %@://%@", FXCustomProtocolScheme, [url path]);
        }
        return NO;
    } else if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {
        return [strongDelegate webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
    } else {
        return YES;
    }
}

- (void)injectJavascriptFile {
    if (jsBridgeCodeCache == nil) {
        jsBridgeCodeCache = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"fxjsbridge" ofType:@"js"]] encoding:NSUTF8StringEncoding];
    }
    [self.webView stringByEvaluatingJavaScriptFromString:jsBridgeCodeCache];
    if (self.messageQueue) {
        NSArray* queue = self.messageQueue;
        self.messageQueue = nil;
        for (id queuedMessage in queue) {
            [self dispatchMessage:queuedMessage];
        }
    }
}

- (void)flushMessageQueue:(NSString *)messageQueueString{
    if (messageQueueString == nil || messageQueueString.length == 0) {
        FXLogDebug(@"WebViewJavascriptBridge:ObjC got nil while fetching the message queue JSON from webview. This can happen if the WebViewJavascriptBridge JS is not currently present in the webview, e.g if the webview just loaded a new page.");
        return;
    }
    
    id messages = [self deserializeMessageJSON:messageQueueString];
    for (FXWVJSBMessage* message in messages) {
        if (![message isKindOfClass:[FXWVJSBMessage class]]) {
            FXLogDebug(@"WebViewJavascriptBridge:Invalid %@ received: %@", [message class], message);
            continue;
        }
        [self log:@"RCVD" json:message];
        
        NSString* responseId = message[@"responseId"];
        if (responseId) {
            FXWVJSBResponseCallback responseCallback = _responseCallbacks[responseId];
            responseCallback(message[@"responseData"]);
            [self.responseCallbacks removeObjectForKey:responseId];
        } else {
            FXWVJSBResponseCallback responseCallback = NULL;
            NSString* callbackId = message[@"callbackId"];
            if (callbackId) {
                responseCallback = ^(id responseData) {
                    if (responseData == nil) {
                        responseData = [NSNull null];
                    }
                    
                    FXWVJSBMessage* msg = @{ @"responseId":callbackId, @"responseData":responseData };
                    [self queueMessage:msg];
                };
            } else {
                responseCallback = ^(id ignoreResponseData) {
                    // Do nothing
                };
            }
            
            FXWVJSBHandler handler = self.messageHandlers[message[@"handlerName"]];
            
            if (!handler) {
                FXLogDebug(@"WVJSBNoHandlerException, No handler for message from JS: %@", message);
                continue;
            }
            
            handler(message[@"data"], responseCallback);
        }
    }
}

@end
