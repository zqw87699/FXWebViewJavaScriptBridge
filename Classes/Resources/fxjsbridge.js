(function () {

    //如果WebViewJavascriptBridge存在则返回
    if (window.WebViewJavascriptBridge) {
        return;
    }

    if (!window.onerror) {
        window.onerror = function (msg, url, line) {
            console.log("FXWebViewJavascriptBridge: ERROR:" + msg + "@" + url + ":" + line);
        }
    }


    window.WebViewJavascriptBridge = {
        registerHandler: registerHandler,
        callHandler: callHandler,
        disableJavscriptAlertBoxSafetyTimeout: disableJavscriptAlertBoxSafetyTimeout,
        fetchQueue: fetchQueue,
        handleMessageFromNative: handleMessageFromNative
    };

    //消息iframe
    var messagingIframe;
    //发送消息队列
    var sendMessageQueue = [];
    //消息处理器集合
    var messageHandlers = {};

    //自定义协议Scheme
    var CUSTOM_PROTOCOL_SCHEME = 'fxwvjbscheme';
    //消息队列Host
    var QUEUE_HAS_MESSAGE = '__FX_WVJB_QUEUE_MESSAGE__';
    //响应回调器
    var responseCallbacks = {};
    //唯一id
    var uniqueId = 1;
    //分派消息超时的安全
    var dispatchMessagesWithTimeoutSafety = true;

    //注册处理器
    function registerHandler(handlerName, handler) {
        //保存消息处理器
        messageHandlers[handlerName] = handler;
    }
    //调用Native 代码
    function callHandler(handlerName, data, responseCallback) {
        if (arguments.length == 2 && typeof data == 'function') {
            responseCallback = data;
            data = null;
        }
        doSend({ handlerName: handlerName, data: data }, responseCallback);
    }

    //关闭分派消息超时的安全
    function disableJavscriptAlertBoxSafetyTimeout() {
        dispatchMessagesWithTimeoutSafety = false;
    }
    //组装消息发送到Native
    function doSend(message, responseCallback) {
        if (responseCallback) {
            var callbackId = 'cb_' + (uniqueId++) + '_' + new Date().getTime();
            responseCallbacks[callbackId] = responseCallback;
            message['callbackId'] = callbackId;
        }
        //将消息装入队列
        sendMessageQueue.push(message);
        //调用Native，让其取消息
        messagingIframe.src = CUSTOM_PROTOCOL_SCHEME + '://' + QUEUE_HAS_MESSAGE;
    }
    //native 获取队列消息函数
    function fetchQueue() {
        var messageQueueString = JSON.stringify(sendMessageQueue);
        sendMessageQueue = [];
        return messageQueueString;
    }

    //调度处理来自Native的消息
    function dispatchMessageFromNative(messageJSON) {
        if (dispatchMessagesWithTimeoutSafety) {
            setTimeout(doDispatchMessageFromNative);
        } else {
            doDispatchMessageFromNative();
        }
        //执行来自native的消息
        function doDispatchMessageFromNative() {
            var message = JSON.parse(messageJSON);
            var messageHandler;
            var responseCallback;

            if (message.responseId) {
                responseCallback = responseCallbacks[message.responseId];
                if (!responseCallback) {
                    return;
                }
                responseCallback(message.responseData);
                delete responseCallbacks[message.responseId];
            } else {
                if (message.callbackId) {
                    var callbackResponseId = message.callbackId;
                    responseCallback = function (responseData) {
                        doSend({ handlerName: message.handlerName, responseId: callbackResponseId, responseData: responseData });
                    };
                }

                var handler = messageHandlers[message.handlerName];
                if (!handler) {
                    console.log("FXWebViewJavascriptBridge: WARNING: no handler for message from Native:", message);
                } else {
                    handler(message.data, responseCallback);
                }
            }
        }
    }
    //处理来自native的消息
    function handleMessageFromNative(messageJSON) {
        dispatchMessageFromNative(messageJSON);
    }

    //插件一个iframe元素用来发送消息给native
    messagingIframe = document.createElement('iframe');
    messagingIframe.style.display = 'none';
    messagingIframe.src = CUSTOM_PROTOCOL_SCHEME + '://' + QUEUE_HAS_MESSAGE;
    document.documentElement.appendChild(messagingIframe);

    registerHandler("disableJavascriptAlertBoxSafetyTimeout", disableJavscriptAlertBoxSafetyTimeout);

    setTimeout(callWVJBCallbacks, 0);
    function callWVJBCallbacks() {
        var callbacks = window.WVJBCallbacks;
        delete window.WVJBCallbacks;
        for (var i = 0; i < callbacks.length; i++) {
            callbacks[i](WebViewJavascriptBridge);
        }
    }
})();
