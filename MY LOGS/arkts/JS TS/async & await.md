**`async function`** 声明创建一个[绑定](https://developer.mozilla.org/zh-CN/docs/Glossary/Binding)到给定名称的新异步函数。函数体内**允许**使用 `await` 关键字，这使得我们可以更简洁地编写基于 promise 的异步代码，并且避免了显式地配置 promise 链的需要。
在 JavaScript 中，`async` 和 `await` 是用于处理异步操作的关键字，使得异步代码的编写更为直观和易于理解。
```js
function resolveAfter2Seconds() {
  return new Promise((resolve) => {
    setTimeout(() => {
      resolve("resolved");
    }, 2000);
  });
}

async function asyncCall() {
  console.log("calling");
  const result = await resolveAfter2Seconds();
  console.log(result);
  // Expected output: "resolved"
}

asyncCall();
```
**`async` 函数：**
`async function` 声明创建一个 [`AsyncFunction`](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Global_Objects/AsyncFunction) 对象。每次调用异步函数时，都会返回一个新的 [`Promise`](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Global_Objects/Promise) 对象，该对象将会被解决为异步函数的返回值，或者被拒绝为异步函数中未捕获的异常。
异步函数可以包含零个或者多个 [`await`](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Operators/await) 表达式。await 表达式通过暂停执行使返回 promise 的函数表现得像同步函数一样，直到返回的 promise 被兑现或拒绝。返回的 promise 的解决值会被当作该 await 表达式的返回值。使用 `async` / `await` 关键字就可以使用普通的 `try` / `catch` 代码块捕获异步代码中的错误。
在函数前添加 `async` 关键字，表示该函数是异步的。异步函数总是返回一个 `Promise` 对象，即使函数内部没有显式地返回 `Promise`，也会被自动包装成一个已解决的 `Promise`。
```javascript
async function example() {
  return "Hello, World!";
}

example().then(result => console.log(result)); // 输出: Hello, World!
```
在上述示例中，`example` 函数返回一个已解决的 `Promise`，其值为 `"Hello, World!"`。
**`await` 表达式：**
`await` 关键字只能在 `async` 函数内部使用。它用于等待一个 `Promise` 对象的解决，并返回其结果。
```javascript
async function example() {
  const result = await someAsyncFunction();
  console.log(result);
}
```
在此示例中，`await` 会暂停 `example` 函数的执行，直到 `someAsyncFunction` 返回的 `Promise` 被解决，然后将其结果赋值给 `result`。
**错误处理：**
在 `async` 函数中，可以使用 `try...catch` 语句来捕获和处理异步操作中的错误。
```javascript
async function example() {
  try {
    const result = await someAsyncFunction();
    console.log(result);
  } catch (error) {
    console.error('Error:', error);
  }
}
```
如果 `someAsyncFunction` 返回的 `Promise` 被拒绝，`catch` 块将捕获到该错误。

**示例：**
以下是一个使用 `async` 和 `await` 的实际示例，演示如何从 API 获取数据：
```javascript
async function fetchData(url) {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const data = await response.json();
    console.log(data);
  } catch (error) {
    console.error('Error:', error);
  }
}

fetchData('https://api.example.com/data');
```
在此示例中，`fetchData` 函数从指定的 URL 获取数据，并在控制台中输出结果。如果在获取数据或解析 JSON 时发生错误，`catch` 块将捕获并处理该错误。
使用 `async` 和 `await`，可以使异步代码的编写更接近同步代码的风格，提升代码的可读性和可维护性。
更多关于 `async` 和 `await` 的信息，请参考 MDN Web Docs。 
