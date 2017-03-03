//
//  IFXWebViewJSBridgeDelegate.h
//  TTTT
//
//  Created by 张大宗 on 2017/2/28.
//  Copyright © 2017年 张大宗. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^FXWVJSBResponseCallback)(id responseData);
typedef void (^FXWVJSBHandler)(id data, FXWVJSBResponseCallback responseCallback);
typedef NSDictionary FXWVJSBMessage;

@protocol IFXWebViewJSBridgeDelegate <NSObject>

/**
 *  注册消息
 *
 *  @param handlerName 消息名称
 *  @param handler     处理器
 */
- (void)registerHandler:(NSString*)handlerName handler:(FXWVJSBHandler)handler;

/**
 *  调用JS消息
 *
 *  @param handlerName      消息名称
 *  @param data             参数
 *  @param responseCallback 回调block
 */
- (void)callHandler:(NSString*)handlerName data:(id)data responseCallback:(FXWVJSBResponseCallback)responseCallback;

/**
 *  禁止安全警告框超时
 */
- (void)disableJavscriptAlertBoxSafetyTimeout;

@end
