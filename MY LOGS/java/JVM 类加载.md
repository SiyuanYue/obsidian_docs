### **一、类加载过程**
#### 1. **加载（Loading）**

^77291e

- **任务**：查找并读取类的二进制字节流（`.class`文件）。
- **数据来源**：
  - 本地文件系统（常规JAR/WAR包）
  - 网络下载（Applet）
  - 动态生成（动态代理、JSP编译）
- **结果**：在内存中生成一个`java.lang.Class`对象，作为方法区该类的数据访问入口。

**示例**：
```java
// 当代码中首次使用MyClass时触发加载
MyClass obj = new MyClass();
```

---

#### 2. **链接（Linking）**
分为三个子阶段：

##### （1）验证（Verification）
- **目的**：确保字节码符合JVM规范，防止恶意代码攻击。
- **检查项**：
  - 文件格式（魔数CAFEBABE）
  - 元数据（继承、final规则）
  - 字节码指令（栈操作是否溢出）
  - 符号引用验证（解析阶段补充）

##### （2）准备（Preparation）
- **任务**：为**类变量（static变量）**分配内存并设置初始值。
- **注意**：
  - 初始值为数据类型的零值（如int=0，对象引用=null）。
  - 若变量是`final static`常量，直接赋代码中定义的值。

**示例**：
```java
public static int value = 123; // 准备阶段value=0
public final static int CONST = 456; // 准备阶段CONST=456
```

##### （3）解析（Resolution）
- **任务**：将常量池内的**符号引用**替换为**直接引用**。
  - 符号引用：以文本形式描述的引用（如`com/example/MyClass`）
  - 直接引用：指向目标方法的指针或偏移量。

---

#### 3. **初始化（Initialization）**
- **任务**：执行类构造器`<clinit>()`方法，为类变量赋真实值。
- **触发条件**（首次主动使用类时）：
  - `new`实例化对象
  - 访问/设置类的静态字段（非final）
  - 调用类的静态方法
  - 反射调用（如`Class.forName()`）
  - 初始化子类时触发父类初始化

**示例**：
```java
public class MyClass {
    static {
        System.out.println("静态块执行"); // 在初始化阶段执行
    }
}
```

---

### **二、类加载器（ClassLoader）**
JVM通过**分层模型**实现类加载，主要分为三类：

#### 1. **启动类加载器（Bootstrap ClassLoader）**
- **实现**：C++编写，JVM内核一部分。
- **职责**：加载`<JAVA_HOME>/lib`目录的核心库（如rt.jar）。
- **特点**：无法被Java代码直接引用。

#### 2. **扩展类加载器（Extension ClassLoader）**
- **实现**：`sun.misc.Launcher$ExtClassLoader`（Java）。
- **职责**：加载`<JAVA_HOME>/lib/ext`目录的扩展包。

#### 3. **应用程序类加载器（Application ClassLoader）**
- **实现**：`sun.misc.Launcher$AppClassLoader`。
- **职责**：加载用户类路径（ClassPath）的类。
- **默认加载器**：`ClassLoader.getSystemClassLoader()`的返回值。

---

### **三、双亲委派模型（Parent Delegation）**
#### 1. **工作流程**
1. 收到类加载请求时，先委托父加载器处理。
2. 父加载器无法完成时（在自己的搜索范围找不到类），子加载器才尝试加载。

**代码逻辑**：
```java
protected Class<?> loadClass(String name, boolean resolve) {
    synchronized (getClassLoadingLock(name)) {
        // 1. 检查是否已加载
        Class<?> c = findLoadedClass(name);
        if (c == null) {
            // 2. 委托父加载器
            if (parent != null) {
                c = parent.loadClass(name, false);
            } else {
                c = findBootstrapClassOrNull(name);
            }
            // 3. 父类未找到，自行加载
            if (c == null) {
                c = findClass(name);
            }
        }
        return c;
    }
}
```

#### 2. **优势**
- **安全**：避免用户自定义同名核心类（如`java.lang.String`）。
- **稳定**：保证类在各级加载器中的唯一性。

#### 3. **打破双亲委派**
- **场景**：热部署、模块化加载（如Tomcat、OSGi）。
- **方法**：重写`loadClass()`方法，自定义加载逻辑。

---

### **四、自定义类加载器**
#### 1. **实现步骤**
1. 继承`java.lang.ClassLoader`类。
2. 重写`findClass()`方法（建议不破坏双亲委派）。
3. 在`findClass()`中调用`defineClass()`生成Class对象。

**示例**：
```java
public class MyClassLoader extends ClassLoader {
    @Override
    protected Class<?> findClass(String name) throws ClassNotFoundException {
        byte[] data = loadClassData(name); // 从自定义路径读取字节码
        return defineClass(name, data, 0, data.length);
    }
    private byte[] loadClassData(String className) {
        // 自定义加载逻辑（如网络下载、加密文件解密）
    }
}
```

#### 2. **应用场景**
- 热部署：不重启服务更新代码。
- 模块隔离：不同模块使用独立类加载器。
- 加密保护：加载加密的.class文件。

---

### **五、常见问题与异常**
#### 1. **ClassNotFoundException**
- **原因**：类加载器在指定路径找不到类。
- **场景**：手动调用`Class.forName()`未找到类。

#### 2. **NoClassDefFoundError**
- **原因**：编译时存在类，但运行时找不到。
- **常见情况**：依赖JAR未加入ClassPath。

#### 3. **UnsatisfiedLinkError**
- **原因**：JNI加载本地库失败。

---

### **六、调试类加载**
- **JVM参数**：  
  ```bash
  -verbose:class       # 打印加载的类信息
  -XX:+TraceClassLoading  # 跟踪类加载过程（更详细）
  ```

---

**总结**：JVM通过分层加载和双亲委派机制保障核心库安全，同时允许自定义类加载器实现灵活扩展。理解类加载过程对解决ClassNotFound异常、实现热部署等高级功能至关重要。