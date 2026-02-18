异步编程技术使你的程序可以在执行一个可能长期运行的任务的同时继续对其他事件做出反应而不必等待任务完成。与此同时，你的程序也将在任务完成后显示结果。

浏览器提供的许多功能（尤其是最有趣的那一部分）可能需要很长的时间来完成，因此需要异步完成，例如：

- 使用 [`fetch()`](https://developer.mozilla.org/zh-CN/docs/Web/API/Window/fetch "fetch()") 发起 HTTP 请求
- 使用 [`getUserMedia()`](https://developer.mozilla.org/zh-CN/docs/Web/API/MediaDevices/getUserMedia "getUserMedia()") 访问用户的摄像头和麦克风
- 使用 [`showOpenFilePicker()`](https://developer.mozilla.org/zh-CN/docs/Web/API/Window/showOpenFilePicker "showOpenFilePicker()") 请求用户选择文件以供访问

因此，即使你可能不需要经常_实现_自己的异步函数，你也很可能需要_正确使用_它们。

耗时的同步函数的基本问题。在这里我们想要的是一种方法，以让我们的程序可以：

- 通过调用一个函数来启动一个长期运行的操作
- 让函数开始操作并立即返回，这样我们的程序就可以保持对其他事件做出反应的能力
- 当操作最终完成时，通知我们操作的结果。

这就是异步函数为我们提供的能力，本模块的其余部分将解释它们是如何在 JavaScript 中实现的。

## [回调](https://developer.mozilla.org/zh-CN/docs/Learn_web_development/Extensions/Async_JS/Introducing#%E5%9B%9E%E8%B0%83)

事件处理程序是一种特殊类型的回调函数。而回调函数则是一个被传递到另一个函数中的会在适当的时候被调用的函数。正如我们刚刚所看到的：回调函数曾经是 JavaScript 中实现异步函数的主要方式。

然而，当回调函数本身需要调用其他同样接受回调函数的函数时，基于回调的代码会变得难以理解。当你需要执行一些分解成一系列异步函数的操作时，这将变得十分常见。例如下面这种情况：
```js
function doStep1(init) {
  return init + 1;
}
function doStep2(init) {
  return init + 2;
}
function doStep3(init) {
  return init + 3;
}
function doOperation() {
  let result = 0;
  result = doStep1(result);
  result = doStep2(result);
  result = doStep3(result);
  console.log(`结果：${result}`);
}
doOperation();
```

现在我们有一个被分成三步的操作，每一步都依赖于上一步。在这个例子中，第一步给输入的数据加 1，第二步加 2，第三步加 3。从输入 0 开始，最终结果是 6（0+1+2+3）。作为同步代码，这很容易理解。但是如果我们用回调来实现这些步骤呢？

```js
function doStep1(init, callback) {
  const result = init + 1;
  callback(result);
}
function doStep2(init, callback) {
  const result = init + 2;
  callback(result);
}
function doStep3(init, callback) {
  const result = init + 3;
  callback(result);
}
function doOperation() {
  doStep1(0, (result1) => {
    doStep2(result1, (result2) => {
      doStep3(result2, (result3) => {
        console.log(`结果：${result3}`);
      });
    });
  });
}
doOperation();
```

因为必须在回调函数中调用回调函数，我们就得到了这个深度嵌套的 `doOperation()` 函数，这就更难阅读和调试了。在一些地方这被称为“回调地狱”或“厄运金字塔”（因为缩进看起来像一个金字塔的侧面）。

面对这样的嵌套回调，**处理错误**也会变得非常困难：你必须在“金字塔”的每一级处理错误，而不是在最高一级一次完成错误处理。
