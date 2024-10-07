![[Pasted image 20230713234812.png]]
首先是我们用 ArkTS 赋能的声明式 UI 写的卡片的 ui 风格，如图，我们写了两种样式的卡片，上面有电影的海报，简介和名字信息，每种样式有 2-3 个大小（2\*2，2\*4）。
![[Pasted image 20230713235146.png]]
接下来我们叙述一下卡片的数据获取和更新机制。
先来看右图，我们可以看到同种样式卡片更新了不同的数据。我们希望卡片可以设置时间间隔自动更新数据（从数据库中），并且卡片中的电影选择是随机的。

然后我们看左边的图，通过 `@LocalStorageProp` 创建一个 Key 值对应的页面级 UI 存储数据，在卡片的声明周期管理接口使用 formProvider 提供的方法通过卡片 id 和 Key-value 键值对来更新这个数据，更新的卡片会刷新渲染。

接下来更详细的阐述一下：
![[Pasted image 20230714000403.png]]
在每个卡片的 page 页面中是不能 import 代码数据或者进行操作的，我们通过 `let ListStorage = new LocalStorage();` 创建 LocalStorage 这个页面级 UI 状态存储类的示例，并传递给这个卡片页面的 `@entry(ListStorage)`。
接着就可以用 `@LocalStorageProp('first_title') first_title:string='铃芽之旅'` 这个装饰器标识我们需要卡片提供方更新的数据，并有一个 Key 值作为参数。

![[Pasted image 20230714000705.png]]
FormProvider 模块提供了卡片提供方相关接口的能力，开发者在开发卡片时，可通过该模块提供接口实现更新卡片获取卡片信息等。
在卡片的声明周期管理接口 EntryFormAbility 的 onUpdateForm 接口中，我们会直接或间接调用 `formProvider.updateForm` 这个方法来更新前面 `@LocalStorageProp` 装饰的数据，这个方法第一个参数就是这个卡片的唯一标识 id，第二个参数就是 `formdata` 是 Key-Value 的键值对，通过给之前创建的对应 key 赋上更新的数值（从数据库取得）来实现对应卡片数据的更新，更新后将卡片重新渲染就完成了卡片的更新。

然后是卡片的生命周期与跳转
![[Pasted image 20230714000823.png]]
在卡片的添加接口 `onAddForm` 中可以通过 formProvider 设置卡片定时刷新，这是卡片的更新，前面说过了。
然后卡片跳转通过 `postCardAction` 来实现，使用 router，跳到 entryability。
