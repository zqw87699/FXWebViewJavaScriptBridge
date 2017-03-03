//
//  FXWKWebViewJavaScriptBridge.h
//  TTTT
//
//  Created by 张大宗 on 2017/3/3.
//  Copyright © 2017年 张大宗. All rights reserved.
//

#import <FXCommon/FXCommon.h>
#import "IFXWebViewJSBridgeDelegate.h"
#import <WebKit/WebKit.h>

#define FXCustomProtocolScheme @"fxwvjbscheme"
#define FXQueueHasMessage      @"__FX_WVJB_QUEUE_MESSAGE__"
#define FXBridgeLoaded         @"__FX_BRIDGE_LOADED__"

#define FX_WEBVIEW_DELEGATE_INTERFACE NSObject<WKNavigationDelegate,IFXWebViewJSBridgeDelegate>
#define FX_WEB_VIEW_TYPE WKWebView
#define FX_WEB_VIEW_DELEGATE_TYPE    NSObject<WKNavigationDelegate>

@interface FXWKWebViewJavaScriptBridge : FX_WEBVIEW_DELEGATE_INTERFACE

+ (instancetype)bridgeForWebView:(FX_WEB_VIEW_TYPE*)webView;

- (void)setJSBDelegate:(FX_WEB_VIEW_DELEGATE_TYPE*)delegate;

@end
