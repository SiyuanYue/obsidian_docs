## 结构化的类型系统（structural type system）

TypeScript 的一个核心原则是类型检查基于对象的属性和行为（type checking focuses on the _shape_ that values have）。这有时被叫做“鸭子类型”或“结构类型”（structural typing）。
In TypeScript, two types are compatible if their internal structure is compatible.
在结构化的类型系统当中，如果两个对象具有相同的结构，则认为它们是相同类型的。
This allows us to implement an interface just by having the shape the interface requires, *without an explicit `implements` clause*.
```ts
interface Point {
  x: number;
  y: number;
}
 
function logPoint(p: Point) {
  console.log(`${p.x}, ${p.y}`);
}
 
// 打印 "12, 26"
const point = { x: 12, y: 26 };
logPoint(point);
```
[Try](https://www.typescriptlang.org/play/#code/JYOwLgpgTgZghgYwgAgAoHtRmQbwFDLIAeAXMiAK4C2ARtANwHICeZltDeAvnnjBSARhg6EMgA26AOYYsACgAOZWeACUuJglEBndOIgA6SVLkADACQ4FBolwA0yS9eZdTqxjzwB6L8kDKRoAOysgARACMAEwO4QBswXhaINrYCpjgyAC8uMRkEQ6syDHIXIzGKmCKqWDuQA)

`point` 变量从未声明为 `Point` 类型。 但是，在类型检查中，TypeScript 将 `point` 的结构与 `Point`的结构进行比较。它们的结构相同，所以代码通过了。

结构匹配只需要匹配对象字段的子集。
```ts
const point3 = { x: 12, y: 26, z: 89 };
logPoint(point3); // 打印 "12, 26"
 
const rect = { x: 33, y: 3, width: 30, height: 80 };
logPoint(rect); // 打印 "33, 3"
 
const color = { hex: "#187ABF" };
logPoint(color);
```
> [!bug] 
> ```sh
Argument of type '{ hex: string; }' is not assignable to parameter of type 'Point'.
  Type '{ hex: string; }' is missing the following properties from type 'Point': x, y```

类和对象确定结构的方式没有区别：
```ts
interface Point {
  x: number;
  y: number;
}
 
function logPoint(p: Point) {
  console.log(`${p.x}, ${p.y}`);
}
// ---分割线---
class VirtualPoint {
  x: number;
  y: number;
 
  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }
}
 
const newVPoint = new VirtualPoint(13, 56);
logPoint(newVPoint); // 打印 "13, 56"
```
  [try](https://www.typescriptlang.org/play/#code/PTAEAEFMCdoe2gZwFygEwGYAsBWAUAJYB2ALjAGYCGAxpKAApzEmgDeeooAHqkQK4BbAEYwA3B1ABPXoJHRxAXzx5yfItRIE4RUABs4Ac0bMAFAAdUx0gEo2E6tsRxdkAHT6DJgAYASVmdcuBQAaUD8AyQUva0U8EFAAWiTAMCVAJyVAfr8khLxqXUpERFAANQJoEj5KXSsWdk4eUH5hMQlpBtlm+0cSaD4NBBN6xrlQ1qGYW1rOUBIACwJEQNAAXm5xKem5hcllqTXQJSUcrobIAHci6p2iM+LS8srqkwBGDFCcADYYvA9H6-PqmKgeKAZSNAA7KoAARC83u8IUA)
如果对象或类具有所有必需的属性，则 TypeScript 将表示是它们匹配的，而不关注其实现细节。
