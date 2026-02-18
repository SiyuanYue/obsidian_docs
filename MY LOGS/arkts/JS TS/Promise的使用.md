API SPEC(friendly) :[Promise - JavaScript | MDN](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Global_Objects/Promise)

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

因为必须在回调函数中调用回调函数，我们就得到了这个深度嵌套的 `doOperation()` 函数，这就更难阅读和调试了。在一些地方这被称为“**回调地狱**”或“厄运金字塔”（因为缩进看起来像一个金字塔的侧面）。

面对这样的嵌套回调，处理错误也会变得非常困难：你必须在“金字塔”的每一级处理错误，而不是在最高一级一次完成错误处理。

由于以上这些原因，大多数现代异步 API 都不使用回调。事实上，JavaScript 中异步编程的基础是 [`Promise`](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Global_Objects/Promise)。

# Promise
`Promise` 是一个由异步函数返回的对象，可以指示操作当前所处的状态。在 `Promise` 返回给调用者的时候，操作往往还没有完成，但 `Promise` 对象提供了方法来处理操作最终的成功或失败。
```js
const fetchPromise = fetch(
  "https://mdn.github.io/learning-area/javascript/apis/fetching-data/can-store/products.json",
);

console.log(fetchPromise);

fetchPromise.then((response) => {
  console.log(`已收到响应：${response.status}`);
});

console.log("已发送请求……");
```
`fetch()` 返回一个包含响应结果的 promise（一个 [`Response`](https://developer.mozilla.org/zh-CN/docs/Web/API/Response) 对象）
我们在这里：
1. 调用 `fetch()` API，并将返回值赋给 `fetchPromise` 变量。
2. 紧接着，输出 `fetchPromise` 变量，输出结果应该像这样：`Promise { <state>: "pending" }`。这告诉我们有一个 `Promise` 对象，它有一个 `state`属性，值是 `"pending"`。`"pending"` 状态意味着操作仍在进行中。
3. 将一个处理函数传递给 Promise 的 **`then()`** 方法。当（如果）获取操作成功时，Promise 将调用我们的处理函数，传入一个包含服务器的响应的 [`Response`](https://developer.mozilla.org/zh-CN/docs/Web/API/Response) 对象。
4. 输出一条信息，说明我们已经发送了这个请求。
![[QQ_1741061228430.png]]
![[QQ_1741061439635.png]]
完整的输出结果应该是这样的：
```sh
Promise { <state>: "pending" }
已发送请求……
已收到响应：200
```

请注意，`已发送请求……` 的消息在我们收到响应之前就被输出了。与同步函数不同，`fetch ()` 在请求仍在进行时返回，这使我们的程序能够保持响应性。响应显示了 `200`（OK）的[状态码](https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Status)，意味着我们的请求成功了。
我们这一次将处理程序传递到返回的 Promise 对象的 `then()` 方法中。


## [链式使用 Promise](https://developer.mozilla.org/zh-CN/docs/Learn_web_development/Extensions/Async_JS/Promises#%E9%93%BE%E5%BC%8F%E4%BD%BF%E7%94%A8_promise)

在你通过 `fetch()` API 得到一个 `Response` 对象的时候，你需要调用另一个函数来获取响应数据。在这里，我们想获得 JSON 格式的响应数据，所以我们会调用 `Response` 对象的 [`json()`](https://developer.mozilla.org/zh-CN/docs/Web/API/Response/json "json()") 方法。事实上，`json()` 也是异步的，因此我们必须连续调用两个异步函数。

试试这个：
```js
const fetchPromise = fetch(
  "https://mdn.github.io/learning-area/javascript/apis/fetching-data/can-store/products.json",
);

fetchPromise.then((response) => {
  const jsonPromise = response.json();
  jsonPromise.then((json) => {
    console.log(json[0].name);
  });
});
```
在这个示例中，就像我们之前做的那样，我们给 `fetch()` 返回的 Promise 对象添加了一个 `then()` 处理程序。但这次我们的处理程序调用 `response.json()` 方法，然后将一个新的 `then()` 处理程序传递到 `response.json()` 返回的 Promise 中。

执行代码后应该会输出“baked beans”（“products.json”中第一个产品的名称）。
![](QQ_1742177821182.png)
我们好像说过，在回调中调用另一个回调会出现多层嵌套的情况？我们是不是还说过，这种“回调地狱”使我们的代码难以理解？这不是也一样吗，只不过变成了用 `then()` 调用而已？

当然如此。但 Promise 的优雅之处在于 _`then()` 本身也会返回一个 Promise，这个 Promise 将指示 `then()`中调用的异步函数的完成状态_。这意味着我们可以（当然也应该）把上面的代码改写成这样:
```js
const fetchPromise = fetch(
  "https://mdn.github.io/learning-area/javascript/apis/fetching-data/can-store/products.json",
);

fetchPromise
  .then((response) => response.json())
  .then((data) => {
    console.log(data[0].name);
  });
```
不必在第一个 `then()` 的处理程序中调用第二个 `then()`，我们可以直接_返回_ `json()` 返回的 Promise，并在该返回值上调用第二个 `then()`。这被称为 **Promise 链**，意味着当我们需要连续进行异步函数调用时，我们就可以避免不断嵌套带来的缩进增加。

##  [错误捕获](https://developer.mozilla.org/zh-CN/docs/Learn_web_development/Extensions/Async_JS/Promises#%E9%94%99%E8%AF%AF%E6%8D%95%E8%8E%B7)
为了支持错误处理，`Promise` 对象提供了一个 [`catch()`](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Global_Objects/Promise/catch) 方法。这很像 `then()`：你调用它并传入一个处理函数。然后，当异步操作_成功_时，传递给 `then()` 的处理函数被调用，而当异步操作_失败_时，传递给 `catch()`的处理函数被调用。
如果将 `catch()` 添加到 Promise 链的末尾，它就可以在任何异步函数失败时被调用。于是，我们就可以将一个操作实现为几个连续的异步函数调用，并在一个地方处理所有错误。

## [Promise 术语](https://developer.mozilla.org/zh-CN/docs/Learn_web_development/Extensions/Async_JS/Promises#promise_%E6%9C%AF%E8%AF%AD)

Promise 中有一些具体的术语值得我们弄清楚。
首先，Promise 有三种状态：

- **待定（pending）**：初始状态，既没有被兑现，也没有被拒绝。这是调用 `fetch()` 返回 Promise 时的状态，此时请求还在进行中。
- **已兑现（fulfilled）**：意味着操作成功完成。当 Promise 完成时，它的 `then()` 处理函数被调用。
- **已拒绝（rejected）**：意味着操作失败。当一个 Promise 失败时，它的 `catch()` 处理函数被调用。

有时我们用**已敲定**（settled）这个词来同时表示**已兑现**（fulfilled）和**已拒绝**（rejected）两种情况。

如果一个 Promise 已敲定，或者如果它被“锁定”以跟随另一个 Promise 的状态，那么它就是**已解决**（resolved）的。

文章 [Let's talk about how to talk about promises](https://thenewtoys.dev/blog/2021/02/08/lets-talk-about-how-to-talk-about-promises/) 对这些术语的细节做了很好的解释。
![](Promise的使用.png)


## [合并使用多个 Promise](https://developer.mozilla.org/zh-CN/docs/Learn_web_development/Extensions/Async_JS/Promises#%E5%90%88%E5%B9%B6%E4%BD%BF%E7%94%A8%E5%A4%9A%E4%B8%AA_promise)

当你的操作由几个异步函数组成，而且你需要在开始下一个函数之前完成之前每一个函数时，你需要的就是 Promise 链。但是在其他的一些情况下，你可能需要合并多个异步函数的调用，`Promise` API 为解决这一问题提供了帮助。

有时你需要所有的 Promise 都得到实现，但它们并不相互依赖。在这种情况下，将它们一起启动然后在它们全部被兑现后得到通知会更有效率。这里需要 [`Promise.all()`](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Global_Objects/Promise/all) 方法。它接收一个 Promise 数组，并返回一个单一的 Promise。

由`Promise.all()`返回的 Promise：

- 当且仅当数组中_所有_的 Promise 都被兑现时，才会通知 `then()` 处理函数并提供一个包含所有响应的数组，数组中响应的顺序与被传入 `all()` 的 Promise 的顺序相同。
- 会被拒绝——如果数组中有_任何一个_ Promise 被拒绝。此时，`catch()` 处理函数被调用，并提供被拒绝的 Promise 所抛出的错误。

```js
const fetchPromise1 = fetch(
  "https://mdn.github.io/learning-area/javascript/apis/fetching-data/can-store/products.json",
);
const fetchPromise2 = fetch(
  "https://mdn.github.io/learning-area/javascript/apis/fetching-data/can-store/not-found",
);
const fetchPromise3 = fetch(
  "https://mdn.github.io/learning-area/javascript/oojs/json/superheroes.json",
);

Promise.all([fetchPromise1, fetchPromise2, fetchPromise3])
  .then((responses) => { // responses是response的数组
    for (const response of responses) {
      console.log(`${response.url}：${response.status}`);
    }
  })
  .catch((error) => {
    console.error(`获取失败：${error}`);
  });

```
这里我们向三个不同的 URL 发出三个 `fetch()` 请求。如果它们都被兑现了，我们将输出每个请求的响应状态。如果其中任何一个被拒绝了，我们将输出失败的情况。
根据我们提供的 URL，应该所有的请求都会被兑现，尽管因为第二个请求中请求的文件不存在，服务器将返回 `404`（Not Found）而不是 `200`（OK）。所以输出应该是：
```
https://mdn.github.io/learning-area/javascript/apis/fetching-data/can-store/products.json：200
https://mdn.github.io/learning-area/javascript/apis/fetching-data/can-store/not-found：404
https://mdn.github.io/learning-area/javascript/oojs/json/superheroes.json：200
```

有时，你可能需要一组 Promise 中的某一个 Promise 的兑现，而不关心是哪一个。在这种情况下，你需要 [`Promise.any()`](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Global_Objects/Promise/any)。这就像 `Promise.all()`，不过在 Promise 数组中的任何一个被兑现时它就会被兑现，如果所有的 Promise 都被拒绝，它也会被拒绝。
```js
const fetchPromise1 = fetch(
  "https://mdn.github.io/learning-area/javascript/apis/fetching-data/can-store/products.json",
);
const fetchPromise2 = fetch(
  "https://mdn.github.io/learning-area/javascript/apis/fetching-data/can-store/not-found",
);
const fetchPromise3 = fetch(
  "https://mdn.github.io/learning-area/javascript/oojs/json/superheroes.json",
);

Promise.any([fetchPromise1, fetchPromise2, fetchPromise3])
  .then((response) => {
    console.log(`${response.url}：${response.status}`);
  })
  .catch((error) => {
    console.error(`获取失败：${error}`);
  });
```
## async & await
[`async`](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Statements/async_function) 关键字为你提供了一种更简单的方法来处理基于异步 Promise 的代码。在一个函数的开头添加 `async`，就可以使其成为一个异步函数。

在异步函数中，你可以在调用一个返回 Promise 的函数之前使用 `await` 关键字。这使得代码在该点上等待，直到 Promise 被完成，这时 Promise 的响应被当作返回值，或者被拒绝的响应被作为错误抛出。

```js
async function fetchProducts() {
  try {
    // 在这一行之后，我们的函数将等待 `fetch()` 调用完成
    // 调用 `fetch()` 将返回一个“响应”或抛出一个错误
    const response = await fetch(
      "https://mdn.github.io/learning-area/javascript/apis/fetching-data/can-store/products.json",
    );
    if (!response.ok) {
      throw new Error(`HTTP 请求错误：${response.status}`);
    }
    // 在这一行之后，我们的函数将等待 `response.json()` 的调用完成
    // `response.json()` 调用将返回 JSON 对象或抛出一个错误
    const json = await response.json();
    console.log(json[0].name);
  } catch (error) {
    console.error(`无法获取产品列表：${error}`);
  }
}

fetchProducts();
```

这里我们调用 `await fetch()`，我们的调用者得到的并不是 `Promise`，而是**一个完整的 `Response` 对象**，就好像 `fetch()` 是一个同步函数一样。
我们**甚至可以使用 `try...catch` 块来处理错误，就像我们在写同步代码时一样**。
同样地，请注意你只能在 `async` 函数中使用 `await`，除非你的代码是 [JavaScript 模块](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Guide/Modules)。这意味着你不能在普通脚本中这样做。 
`await` 强制异步操作以串联的方式完成。如果下一个操作的结果取决于上一个操作的结果，这是必要的，但如果不是这样，像 `Promise.all()` 这样的操作会有更好的性能。
`async` 和 `await` 关键字使得从一系列连续的异步函数调用中建立一个操作变得更加容易，避免了创建显式 Promise 链，并允许你像编写同步代码那样编写异步代码。


## 关于Promise漂浮
_`then()` 本身也会返回一个 Promise，这个 Promise 将指示 `then()`中调用的异步函数的完成状态_

```js
doSomething()
.then((result) => doSomethingElse(result))
.then((newResult) => doThirdThing(newResult))
.then((finalResult) => {
  console.log(`得到最终结果：${finalResult}`);
})
.catch(failureCallback);
```
`doSomethingElse` 和 `doThirdThing` 可以返回任何值——如果它们返回的是 Promise，那么会首先等待这个 Promise 的敲定，然后下一个回调函数会**接收**到它的兑现值，而不是 Promise 本身。在 `then` 回调中始终返回 Promise 是非常重要的，即使 Promise 总是兑现为 `undefined`。如果上一个处理器启动了一个 Promise 但并没有返回它，那么就没有办法再追踪它的敲定状态了，这个 Promise 就是“漂浮”的。

```js
doSomething()
.then((url) => {
  // fetch(url) 前缺少 `return` 关键字。
  fetch(url);
})
.then((result) => {
  // result 是 undefined，因为上一个处理器没有返回任何东西。
  // 无法得知 fetch() 的返回值，也无法知道它是否成功。
});
```
>[!备注] 
>  箭头函数表达式可以有[隐式返回值](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Functions/Arrow_functions#%E5%87%BD%E6%95%B0%E4%BD%93)；所以，`() => x` 是 `() => { return x; }` 的简写。
>  在表达式体中，只需指定一个表达式，它将成为隐式返回值。在块体中，必须使用显式的 `return` 语句。

通过返回 `fetch` 调用的结果（一个 Promise），我们既可以追踪它的完成状态，也可以在它完成时接收到它的值。
如果有竞态条件的话，使 Promise 漂浮的情况会更糟——如果上一个处理器的 Promise 没有返回，那么下一个 `then` 处理器会被提前调用，而它读取的任何值都可能是不完整的。

```js
const listOfIngredients = [];

doSomething()
  .then((url) => {
    // fetch(url) 前缺少 `return` 关键字。
    fetch(url)
      .then((res) => res.json())
      .then((data) => {
        listOfIngredients.push(data);
      });
  })
  .then(() => {
    console.log(listOfIngredients);
    // listOfIngredients 永远为 []，因为 fetch 请求还没有完成。
  });
```

因此，一个经验法则是，每当你的操作遇到一个 Promise，就返回它，并把它的处理推迟到下一个 `then` 处理器中。
```js
const listOfIngredients = [];

doSomething()
  .then((url) => {
    // fetch 调用前面现在包含了 `return` 关键字。
    return fetch(url)
      .then((res) => res.json())
      .then((data) => {
        listOfIngredients.push(data);
      });
  })
  .then(() => {
    console.log(listOfIngredients);
    // listOfIngredients 现在将包含来自 fetch 调用的数据。
  });
```

>[!note] #### then() 的行为
then() 方法总是返回一个新的 Promise，这个新 Promise 的状态和值由回调函数的返回值决定。以下是具体情况：
>- **回调返回非 Promise 值**：如果 onFulfilled 返回一个非 Promise 值（比如数字、字符串、对象或 undefined），新的 Promise 会以该值解析。
>- **回调不返回任何值**：在 JavaScript 中，如果函数没有显式 return 语句，相当于返回 undefined。因此，新的 Promise 会以 undefined 解析。
>- **回调返回 Promise**：如果回调返回另一个 Promise，新的 Promise 会等待该 Promise 解析或拒绝，并以其结果继续。
>- **回调抛出错误**：如果回调抛出错误，新的 Promise 会以该错误拒绝。
 |**回调返回值类型**|**新 Promise 的行为**|**示例返回值**|
 

| **回调返回值类型**            | **新 Promise 的行为**          | **示例返回值**     |
| ---------------------- | -------------------------- | ------------- |
| 非 Promise 值（数字、字符串等）   | 以该值解析                      | 20            |
| undefined（无返回值）        | 以 undefined 解析             | undefined     |
| Promise                | 等待该 Promise 解析，并以其值继续      | 取决于内部 Promise |
| 抛出错误                   | 以错误拒绝                      | Error 对象      |
| thenable（有 then 方法的对象） | 尝试解析 thenable，行为类似 Promise | 取决于 thenable  |
更加好的解决方法是，你可以将嵌套链扁平化为单链，这样更简单，也更容易处理错误。
```js
doSomething()
  .then((url) => fetch(url))
  .then((res) => res.json())
  .then((data) => {
    listOfIngredients.push(data);
  })
  .then(() => {
    console.log(listOfIngredients);
  });
```
使用 [`async`/`await`](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Statements/async_function) 可以帮助你编写更直观、更类似同步代码的代码。下面是使用 `async`/`await` 的相同示例：
```js
async function logIngredients() {
  const url = await doSomething();
  const res = await fetch(url);
  const data = await res.json();
  listOfIngredients.push(data);
  console.log(listOfIngredients);
}
```

>[!备注:] 
> async/await 的并发语义与普通 Promise 链相同。异步函数中的 `await` 不会停止整个程序，只会停止依赖其值的部分，因此在 `await` 挂起时，其他异步任务仍可运行。


例子：
Promise.then style:
```js
async function main() {
  try {
    const result = await doSomethingCritical();
    try {
      const optionalResult = await doSomethingOptional(result);
      await doSomethingExtraNice(optionalResult);
    } catch (e) {
      // 忽略可选步骤的失败并继续执行。
    }
    await moreCriticalStuff();
  } catch (e) {
    console.error(`严重失败：${e.message}`);
  }
}

```
`async`/`await` style:
```js
async function main() {
  try {
    const result = await doSomethingCritical();
    try {
      const optionalResult = await doSomethingOptional(result);
      await doSomethingExtraNice(optionalResult);
    } catch (e) {
      // 忽略可选步骤的失败并继续执行。
    }
    await moreCriticalStuff();
  } catch (e) {
    console.error(`严重失败：${e.message}`);
  }
}

```




---
REF:
[Promise - JavaScript | MDN](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Global_Objects/Promise)
[Let's talk about how to talk about promises](https://thenewtoys.dev/blog/2021/02/08/lets-talk-about-how-to-talk-about-promises/)
[How to use Promises](https://developer.mozilla.org/zh-CN/docs/Learn_web_development/Extensions/Async_JS/Promises)