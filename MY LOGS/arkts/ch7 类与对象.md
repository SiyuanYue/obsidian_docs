# ArkTS 规范 - 第 7 章类与对象

## 7.1 类声明
ArkTS 使用 `class` 关键字定义类。类可以包含字段、方法、构造函数和访问器。
```ts
class Person {
    name: string;
    age: number;
    constructor(name: string, age: number) {
        this.name = name;
        this.age = age;
    }
}
```

## 7.2 继承（Inheritance）
使用 `extends` 关键字实现类继承。
```ts
class Student extends Person {
    studentID: number;
    constructor(name: string, age: number, studentID: number) {
        super(name, age);
        this.studentID = studentID;
    }
}
```

## 7.3 抽象类（Abstract Classes）
抽象类不能直接实例化，必须由子类继承。
```ts
abstract class Animal {
    abstract makeSound(): void;
}

class Dog extends Animal {
    makeSound() {
        console.log("Woof!");
    }
}
```

## 7.4 访问修饰符（Access Modifiers）
- `public`：默认修饰符，类内部和外部都可访问。
- `private`：仅限类内部访问。
- `protected`：仅限类内部及子类访问。
- `internal`：package 内访问
```ts
class Example {
    public a = 10;
    private b = 20;
    protected c = 30;
}
```

## 7.5 对象字面量（Object Literals）
可以使用对象字面量创建类的实例。
```ts
let person: Person = { name: "Alice", age: 25 };
```

## 7.6 静态成员（Static Members）
静态成员属于类本身，而不是实例。
```ts
class MathUtil {
    static PI = 3.14;
    static square(x: number) {
        return x * x;
    }
}
console.log(MathUtil.PI);
console.log(MathUtil.square(5));
```

## 7.7 访问器（Getters 和 Setters）
使用 `get` 和 `set` 关键字定义访问器。
```ts
class Rectangle {
    private _width: number = 0;
    get width() {
        return this._width;
    }
    set width(value: number) {
        if (value > 0) this._width = value;
    }
}
```

## 7.8 接口与类（Interfaces and Classes）
类可以实现接口以确保特定的结构。
```ts
interface Animal {
    name: string;
    makeSound(): void;
}
class Cat implements Animal {
    name: string;
    constructor(name: string) {
        this.name = name;
    }
    makeSound() {
        console.log("Meow!");
    }
}
```


