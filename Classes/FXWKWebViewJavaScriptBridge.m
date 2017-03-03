//
//  FXWKWebViewJavaScriptBridge.m
//  TTTT
//
//  Created by 张大宗 on 2017/3/3.
//  Copyright © 2017年 张大宗. All rights reserved.
//

#import "FXWKWebViewJavaScriptBridge.h"
#import "FXLogMacros.h"

static NSString *jsBridgeCodeCache = nil;

@interface FXWKWebViewJavaScriptBridge ()

@property (nonatomic, weak) FX_WEB_VIEW_TYPE *webView;

@property (nonatomic, weak) FX_WEB_VIEW_DELEGATE_TYPE*webViewDelegate;

@property (nonatomic, assign) long uniqueId;

@property (nonatomic, strong) NSMutableArray* messageQueue;

@property (nonatomic, strong) NSMutableDictionary* responseCallbacks;

@property (nonatomic, strong) NSMutableDictionary* messageHandlers;

@end

@implementation FXWKWebViewJavaScriptBridge

+ (instancetype)bridgeForWebView:(FX_WEB_VIEW_TYPE *)webView{
    FXWKWebViewJavaScriptBridge* bridge = [[self alloc] init];
    if (bridge) {
        [bridge initWithWebView:webView];
    }
    return bridge;
}

- (void)dealloc {
    _webView.navigationDelegate=nil;
    _webView = nil;
    _webViewDelegate = nil;
}

- (void)initWithWebView:(FX_WEB_VIEW_TYPE *)webView{
    _webView = webView;
    _webView.navigationDelegate=self;
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
        [self.webView evaluateJavaScript:javascriptCommand completionHandler:NULL];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.webView evaluateJavaScript:javascriptCommand completionHandler:NULL];
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
        WJLogDebug(@"FXWVJSB %@: %@",action,json);
    }
#endif
}

#pragma mark WKNavigationDelegate
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation{
    if (webView != _webView) { return; }
    
    __strong FX_WEB_VIEW_DELEGATE_TYPE* strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didStartProvisionalNavigation:)]) {
        [strongDelegate webView:webView didStartProvisionalNavigation:navigation];
    }
}
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation{
    if (webView != _webView) { return; }
    
    __strong FX_WEB_VIEW_DELEGATE_TYPE* strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didCommitNavigation:)]) {
        [strongDelegate webView:webView didCommitNavigation:navigation];
    }
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation{
    if (webView != _webView) { return; }
    
    __strong FX_WEB_VIEW_DELEGATE_TYPE* strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didFinishNavigation:)]) {
        [strongDelegate webView:webView didFinishNavigation:navigation];
    }
}
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error{
    if (webView != _webView) { return; }
    
    __strong FX_WEB_VIEW_DELEGATE_TYPE* strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didFailNavigation:withError:)]) {
        [strongDelegate webView:webView didFailNavigation:navigation withError:error];
    }
}
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView{
    if (webView != _webView) { return; }
    
    __strong FX_WEB_VIEW_DELEGATE_TYPE* strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webViewWebContentProcessDidTerminate:)]) {
        [strongDelegate webViewWebContentProcessDidTerminate:webView];
    }
}
- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler{
    if (webView != _webView) { return; }
    
    __strong FX_WEB_VIEW_DELEGATE_TYPE* strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didReceiveAuthenticationChallenge:completionHandler:)]) {
        [strongDelegate webView:webView didReceiveAuthenticationChallenge:challenge completionHandler:completionHandler];
    }else{
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling,NULL);
    }
}
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{
    if (webView != _webView) { decisionHandler(WKNavigationActionPolicyAllow); }
    NSURL *url = [navigationAction.request URL];
    __strong FX_WEB_VIEW_DELEGATE_TYPE *strongDelegate = _webViewDelegate;
    if ([[url scheme] isEqualToString:FXCustomProtocolScheme]) {
        if ([[url host] isEqualToString:FXBridgeLoaded]) {
            [self injectJavascriptFile];
        } else if ([[url host] isEqualToString:FXQueueHasMessage]) {
            [self.webView evaluateJavaScript:@"WebViewJavascriptBridge.fetchQueue();" completionHandler:^(NSString* _Nullable messageQueueString, NSError * _Nullable error) {
                [self flushMessageQueue:messageQueueString];
            }];
        } else {
            FXLogDebug(@"WebViewJavascriptBridge:Received unknown WebViewJavascriptBridge command %@://%@", FXCustomProtocolScheme, [url path]);
        }
        decisionHandler(WKNavigationActionPolicyCancel);
    } else if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:)]) {
        [strongDelegate webView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:decisionHandler];
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}
- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation{
    if (webView != _webView) { return; }
    
    __strong FX_WEB_VIEW_DELEGATE_TYPE* strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didReceiveServerRedirectForProvisionalNavigation:)]) {
        [strongDelegate webView:webView didReceiveServerRedirectForProvisionalNavigation:navigation];
    }
}
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error{
    if (webView != _webView) { return; }
    
    __strong FX_WEB_VIEW_DELEGATE_TYPE* strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:didFailProvisionalNavigation:withError:)]) {
        [strongDelegate webView:webView didFailProvisionalNavigation:navigation withError:error];
    }
}
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(nonnull WKNavigationResponse *)navigationResponse decisionHandler:(nonnull void (^)(WKNavigationResponsePolicy))decisionHandler{
    if (webView != _webView) { return; }
    
    __strong FX_WEB_VIEW_DELEGATE_TYPE* strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(webView:decidePolicyForNavigationResponse:decisionHandler:)]) {
        [strongDelegate webView:webView decidePolicyForNavigationResponse:navigationResponse decisionHandler:decisionHandler];
    }else{
        decisionHandler(WKNavigationResponsePolicyAllow);
    }
}

- (void)injectJavascriptFile {
    if (jsBridgeCodeCache == nil) {
        jsBridgeCodeCache = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"fxjsbridge" ofType:@"js"]] encoding:NSUTF8StringEncoding];
    }
    [self.webView evaluateJavaScript:jsBridgeCodeCache completionHandler:NULL];
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
