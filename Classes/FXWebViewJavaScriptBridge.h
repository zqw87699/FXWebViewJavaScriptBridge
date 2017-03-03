//
//  FXWebViewJavaScriptBridge.h
//  TTTT
//
//  Created by 张大宗 on 2017/2/28.
//  Copyright © 2017年 张大宗. All rights reserved.
//

#import <FXCommon/FXCommon.h>
#import "IFXWebViewJSBridgeDelegate.h"

#define FXCustomProtocolScheme @"fxwvjbscheme"
#define FXQueueHasMessage      @"__FX_WVJB_QUEUE_MESSAGE__"
#define FXBridgeLoaded         @"__FX_BRIDGE_LOADED__"

#define FX_WEBVIEW_DELEGATE_INTERFACE NSObject<UIWebViewDelegate,IFXWebViewJSBridgeDelegate>
#define FX_WEB_VIEW_TYPE UIWebView
#define FX_WEB_VIEW_DELEGATE_TYPE    NSObject<UIWebViewDelegate>

@interface FXWebViewJavaScriptBridge : FX_WEBVIEW_DELEGATE_INTERFACE

+ (instancetype)bridgeForWebView:(FX_WEB_VIEW_TYPE*)webView;

- (void)setJSBDelegate:(FX_WEB_VIEW_DELEGATE_TYPE*)delegate;

@end
