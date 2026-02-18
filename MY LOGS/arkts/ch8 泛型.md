# ArkTS 规范 - 第 8 章泛型 generic

## 8.1 泛型概述
泛型（Generics）允许在类、接口和函数中使用参数化类型，以提高代码的复用性和灵活性。

## 8.2 泛型类型参数
泛型使用 `<T>` 语法定义类型参数。
```ts
function identity<T>(value: T): T {
    return value;
}
```

## 8.3 泛型类
泛型可以应用于类，使其适用于多种数据类型。
```ts
class Box<T> {
    value: T;
    constructor(value: T) {
        this.value = value;
    }
}
let numberBox = new Box<number>(10);
```

## 8.4 泛型接口
接口也可以使用泛型。
```ts
interface Pair<K, V> {
    key: K;
    value: V;
}
let pair: Pair<string, number> = { key: "age", value: 30 };
```

## 8.5 泛型约束（Constraints）
可以使用 `extends` 关键字限制类型参数的范围。
```ts
function logLength<T extends { length: number }>(arg: T): void {
    console.log(arg.length);
}
```

## 8.6 泛型默认类型
泛型参数可以指定默认类型。
```ts
class Storage<T = string> {
    data: T;
    constructor(data: T) {
        this.data = data;
    }
}
let defaultStorage = new Storage(); // 默认使用 string 类型
```

## 8.7 泛型工具类型
ArkTS 提供了一些常用的泛型工具类型：
- `Partial<T>`：将类型的所有属性设为可选。
- `Readonly<T>`：将类型的所有属性设为只读。
- `Record<K, V>`：创建键为 K，值为 V 的映射类型。
```ts
type ReadonlyPoint = Readonly<{ x: number; y: number }>;
```


