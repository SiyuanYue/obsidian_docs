
| 属性            | 解释                                                  |
| ------------- | --------------------------------------------------- |
| `ArrayBuffer` | 原始的二进制数据缓冲区（纯内存），不能直接操作，只能通过视图（View）访问              |
| `Uint8Array`  | 是一个视图（View），提供对 `ArrayBuffer` 的读写能力，每个元素是 1 字节（8 位） |
| `byteLength`  | `Uint8Array` 能看到的长度（字节数）                            |
| `byteOffset`  | 这个视图在其 `ArrayBuffer` 中的起始偏移（以字节为单位）                 |
| `buffer`      | 视图背后的底层 `ArrayBuffer` 本体                            |
