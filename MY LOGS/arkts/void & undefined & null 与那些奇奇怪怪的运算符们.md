# Type `void` & `undefined` & `null`
## Type `void`
Type `void` has no instance and no value. It is typically used as the return type if a function or a method returns no value.
A compile-time error occurs if:
- Type void is used as type annotation 只能用作返回值，不能当做参数类型之类的。
- An expression of type `void` is used as a value

Type annotation：类型注解 
```ts
let x: void // compile-time error - void used as type annotation
function foo (): void {}
let y = foo() // compile-time error - void used as a value
type ErroneousType = void | number
	// compile-time error - void used as type annotation
```
Type `void` can be used as type argument that instantiates（实例化） a generic type if a specific value of type argument is irrelevant（无意义的）. In this case, it is a synonym (同义词) for type undefined.
```ts
class A<T>
let a = new A<void>() // ok, type parameter is irrelevant
let a = new A<undefined>() // ok, the same

function foo<T>(x: T) {}
foo<void>(undefined) // ok
foo<void>(void) // compile-time error: void is used as value
```

## Type `undefined`
The only value of type `undefined` is the keyword `undefined` ( denote **a reference with a value that is not defined**).
Using type `undefined` as type annotation is not recommended, except in `nullish` types.
>[!nullish type]
> `T | null or T | undefined or T | undefined | null`  can be used as the type to specify a nullish version of type `T`
>Non-nullish types cannot have a `null` or  `undefined`  value at runtime

## Type `null`
The only value of type `null` is the keyword `null` (denote **a reference without pointing at any entity**).
Using type `null` as type annotation is not recommended, except in nullish types.

>   根据 ArkTS 的规范，内置的 `Object` 类型通常表示“非 null、非 undefined”的对象，因此不能直接赋值 undefined，如果需要赋值 undefined 和 null，可以使用 NullishType


---

# 奇怪的运算符们
## 可选链运算符 `?.`
在 ArkTS 中，可选链运算符 `?.` 允许安全地访问嵌套对象的属性或方法，而不会因为 `null` 或 `undefined` 而导致运行时错误。
### 1. 可选属性访问
当对象可能为 `null` 或 `undefined` 时，可以使用 `?.` 来安全地访问其属性：
```ts
let user = { name: "Alice", address: null };
console.log(user.address?.city); // undefined，而不会抛出错误
```
### 2. 可选方法调用
在调用可能不存在的方法时，`?.` 可以防止访问 `undefined` 方法：
```ts
let obj = { greet: () =%3E "Hello" };
console.log(obj.greet?.()); // "Hello"
console.log(obj.nonExistentMethod?.()); // undefined，而不会抛出错误
```
### 3. 可选数组索引
可以*安全*地访问可能为 `undefined` 的数组索引：
```ts
let arr = [1, 2, 3];
console.log(arr?.[10]); // undefined，而不会抛出错误
```
### 4. 结合空值合并运算符（`??`）
可选链返回 `undefined` 时，可以结合 `??` 提供默认值：
```ts
let user = null;
console.log(user?.name ?? "默认名称"); // "默认名称"
```
可选链运算符 `?.` 使得代码更加健壮，避免了手动检查 `null` 或 `undefined` 的繁琐操作。

在 ArkTS 中，`!` 和 `!.` 是用于处理 `null` 和 `undefined` 的运算符，它们有不同的作用和应用场景。

---

##  非空断言运算符（`!`）
`!`（非空断言，Non-null Assertion Operator）用于告诉编译器，某个值 **不会是 `null` 或 `undefined`**，即便其类型可能包含 `null` 或 `undefined`。

### 1.1 使用场景
当你 **确信** 某个变量不可能为 `null` 或 `undefined`，但类型检查可能报错时，可以使用 `!` 让**编译器忽略这个可能性**。

### 1.2 代码示例
```ts
let message: string | null = "Hello";
console.log(message!.length); // 这里断言 message 一定不是 null
```
如果 `message` 确实为 `null`，那么运行时会抛出错误，因此应确保使用 `!` 时变量不会为 `null`。

---

## 非空可选链运算符（`!.`）
`!.` 结合了 **可选链（`?.`）** 和 **非空断言（`!`）**，用于在访问对象属性或调用方法时，去除 `null` 或 `undefined` 的类型检查。

### 2.1 使用场景
适用于 **对象可能为 `null` 或 `undefined`**，但你确信 **访问该对象的属性或方法时不会出错** 的情况。

### 2.2 代码示例
```ts
let user: { name?: string | null } = { name: "Alice" };
console.log(user!.name!.toUpperCase()); // 断言 user 和 name 都不是 null
```
这里：
- `user!` 断言 `user` 不为 `null` 或 `undefined`。
- `user!.name!` 断言 `name` 也不为 `null`。

但如果 `user` 真的为 `null` 或 `undefined`，仍然会在运行时抛出错误。

---

###  3. `!` 和 `!.` 的区别

| 运算符  | 作用                                  | 用法                 | 适用场景                                  |
| ---- | ----------------------------------- | ------------------ | ------------------------------------- |
| `!`  | 非空断言，告诉编译器变量不为 `null` 或 `undefined` | `variable!`        | 变量类型可能为 `null` 或 `undefined`，但你确信它不为空 |
| `!.` | 非空可选链，去除 `null` 和 `undefined` 类型检查  | `object!.property` | 访问对象属性或方法时，确信对象不为空                    |

---

### 4. 使用建议
- **`!` 仅用于你能 **保证** 变量不会是 `null` 或 `undefined` 的情况**，否则会导致运行时错误。
- **`?.`（可选链）比 `!.` 更安全**，如果不确定对象是否为空，建议使用 `?.` 而不是 `!.`。
- **避免滥用 `!`**，尽量使用类型检查、默认值（`??`）或可选链来处理 `null` 和 `undefined`。

例如，更安全的方式是：
```ts
let user: { name?: string | null } = {};
console.log(user?.name?.toUpperCase() ?? "默认值"); // 避免直接使用 `!.`
```

这样，即使 `user` 或 `name` 为空，也不会导致运行时错误。

## 空值合并运算符（`??`）&& `||`

`??`（**空值合并运算符，Nullish Coalescing Operator**）用于在变量为 `null` 或 `undefined` 时提供**默认值**。它类似于 `||`（逻辑或运算符），但 `??` **仅在左侧的值为 `null` 或 `undefined` 时才会返回右侧的默认值**。

---

### 1. 基本用法
```ts
let value = null ?? "默认值";
console.log(value); // 输出 "默认值"
```
- 如果 `null ?? "默认值"`，结果是 `"默认值"`。
- 如果 `undefined ?? "默认值"`，结果是 `"默认值"`。
- 如果 `"Hello" ?? "默认值"`，结果是 `"Hello"`（不会使用默认值）。

---

### 2. `??` 与 `||` 的区别
#### 示例：`??` vs `||`
```ts
console.log(0 ?? "默认值");  // 输出 0
console.log(0 || "默认值");  // 输出 "默认值"（因为 0 是假值）
```
**结论：**  
- `??` 只处理 `null` 和 `undefined`，不会误判 `0`、`false` 或 `""` 为无效值。  
- `||` 可能会错误地把 `0`、`false`、`""` 当成 `null` 处理。

---

### 3. 结合 `?.`（可选链运算符）
`??` 可以与可选链 `?.` 结合使用，以确保在对象属性可能缺失时提供默认值：
```ts
let user = { name: null };
console.log(user.name ?? "默认名称"); // 输出 "默认名称"
console.log(user.age?.toString() ?? "未知年龄"); // age 可能不存在，返回 "未知年龄"
```

---

### 4. 赋值运算符 `??=`
ArkTS 还支持 `??=`（**空值合并赋值运算符**），仅当变量当前值为 `null` 或 `undefined` 时才会赋值：
```ts
let x;
x ??= 10;
console.log(x); // 输出 10（因为 x 是 undefined）

let y = 5;
y ??= 20;
console.log(y); // 输出 5（因为 y 不是 null 或 undefined）
```

---

### 5. 使用建议
✅ **使用 `??` 处理 `null` 和 `undefined` 的默认值**，避免 `||` 误判 `0`、`false`、`""` 为假值。  
✅ **结合 `?.` 使用**，在访问可能为 `undefined` 的对象属性时提供安全的默认值。  
✅ **适用于函数参数、配置项、用户输入等可能缺失的场景**。  

---

### 6. 总结
`??` 是更安全、精确的方式来处理 `null` 和 `undefined`，在 ArkTS 开发中应优先使用它，而不是 `||`。

