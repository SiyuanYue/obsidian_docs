原型是 JavaScript 实现 **继承** 和 **属性共享** 的机制。每个 JavaScript 对象都有一个 `__proto__` 属性，它指向其 **原型对象**，原型对象本身也可以有自己的原型，从而形成 **原型链（Prototype Chain）**。

### **原型的作用**

- 允许对象继承方法和属性，避免重复定义，节省内存。
- 形成原型链，提供查找属性和方法的机制。

### **示例**
```js
function Person(name) {
    this.name = name;
}

Person.prototype.sayHello = function() {
    console.log(`Hello, I'm ${this.name}`);
};

let p1 = new Person("Alice");
p1.sayHello(); // Hello, I'm Alice

console.log(p1.__proto__ === Person.prototype); // true
console.log(Person.prototype.__proto__ === Object.prototype); // true
```

在上面的代码中：

- `Person.prototype` 是 `p1` 对象的原型。
- `p1.sayHello()` 先查找 `p1` 自身是否有 `sayHello` 方法，找不到就沿 `__proto__` 指向的 `Person.prototype` 查找。
###  `__proto__` 与 `prototype` 的区别

- `__proto__` 是**对象**的一个**属性**，它指向其构造函数的 `prototype` 对象。
- `prototype` 是**函数（构造函数）** 特有的属性，它*指向一个对象*，该对象会成为由该构造函数创建的实例的原型。


### 原型链的查找过程
当访问对象属性时：
1. 先在对象自身查找；
2. 若找不到，则查找 `__proto__` 指向的原型对象；
3. 继续沿着原型链查找，直到 `null`（即 `Object.prototype.__proto__`）。

```js
function Animal() {}
Animal.prototype.eat = function() {
    console.log("Eating...");
};

let dog = new Animal();
dog.eat(); // Eating...

console.log(dog.__proto__ === Animal.prototype); // true
console.log(Animal.prototype.__proto__ === Object.prototype); // true
console.log(Object.prototype.__proto__ === null); // true
```

### **总结**：

- `__proto__` 是对象指向其原型的属性；
- `prototype` 是构造函数的属性，实例的 `__proto__` 指向其构造函数的 `prototype`；
- 原型链用于属性和方法的查找；
- `class` 语法只是对原型继承的封装。