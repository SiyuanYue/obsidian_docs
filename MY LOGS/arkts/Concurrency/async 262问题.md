[![[async 262问题.png|722]]
Now there’s an issue: we need to clarify whether it’s allowed to call an `async function` in the global scope (which JS/TS allow) or to `launch` a function and `await` it. Because currently, in our ArkTS 1.2, any code in the global scope that triggers scheduling coroutine will cause a RTE.
```ts
//in test.sts
async function foo() {};
let p =foo();
```
Call `foo()` will creat an AJcoroutine and schedule to it, it is in the global scope, so will be called by `_$init$_` called by `_cctor_` when coroutine switch is DISABLED.
This is backtrace:
```js
[TID 039d20] F/coroutines: ERROR ERROR ERROR %3E>> Trying to switch coroutines on [main] worker 0 when coroutine switch is DISABLED!!! %3C<< ERROR ERROR ERROR
FATAL ERROR
Backtrace [tid=236832]:
#0 : 0xffffaec36d80 ark::PrintStack(std::ostream&)
     at /home/ysy/arkcompiler/runtime_core/static_core/libpandabase/os/stacktrace.h:50
#1 : 0xffffaec3a50c ark::Logger::Message::~Message()
     at /home/ysy/arkcompiler/runtime_core/static_core/libpandabase/utils/logger.cpp:137
#2 : 0xffffb358844c ark::StackfulCoroutineWorker::EnsureCoroutineSwitchEnabled()
     at /home/ysy/arkcompiler/runtime_core/static_core/runtime/coroutines/stackful_coroutine_worker.cpp:420
#3 : 0xffffb3588130 ark::StackfulCoroutineWorker::SwitchCoroutineContext(ark::StackfulCoroutineContext*, ark::StackfulCoroutineContext*)
     at /home/ysy/arkcompiler/runtime_core/static_core/runtime/coroutines/stackful_coroutine_worker.cpp:393
#4 : 0xffffb3588038 ark::StackfulCoroutineWorker::ScheduleNextCoroUnlockRunnables()
     at /home/ysy/arkcompiler/runtime_core/static_core/runtime/coroutines/stackful_coroutine_worker.cpp:363
#5 : 0xffffb3587180 ark::StackfulCoroutineWorker::SuspendCurrentCoroAndScheduleNext()
     at /home/ysy/arkcompiler/runtime_core/static_core/runtime/coroutines/stackful_coroutine_worker.cpp:317
#6 : 0xffffb3586f84 ark::StackfulCoroutineWorker::RequestScheduleImpl()
     at /home/ysy/arkcompiler/runtime_core/static_core/runtime/coroutines/stackful_coroutine_worker.cpp:295
#7 : 0xffffb3586ee8 ark::StackfulCoroutineWorker::RequestSchedule()
     at /home/ysy/arkcompiler/runtime_core/static_core/runtime/coroutines/stackful_coroutine_worker.cpp:115
#8 : 0xffffb357b3e0 ark::StackfulCoroutineManager::Schedule()
     at /home/ysy/arkcompiler/runtime_core/static_core/runtime/coroutines/stackful_coroutine_manager.cpp:372
#9 : 0xffffb384a1b8 EtsAsyncCall
     at /home/ysy/arkcompiler/runtime_core/static_core/plugins/ets/runtime/napi/ets_napi_helpers.cpp:466
#10: 0xffffb38a54cc ??
     at /home/ysy/arkcompiler/runtime_core/static_core/plugins/ets/runtime/napi/arch/arm64/ets_async_entry_point_aarch64.S:93
#11: 0xffffb359c528 ??
     at /home/ysy/arkcompiler/runtime_core/static_core/runtime/bridge/arch/aarch64/interpreter_to_compiled_code_bridge_aarch64.S:271
#12: 0xffffb3a98398 HANDLE_FAST_CALL_SHORT_V4_V4_ID16+0x2e8
[1]    236832 abort      ark --boot-panda-files=$core_build/plugins/ets/etsstdlib.abc  ../test262_1.ab
```
Another case:
```ts
async function foo():Promise<number> {
    console.log(CoroutineExtras.getCoroutineId()); //5
    for (let i = 0; i < 100; i++) {
        console.log(i);
    }
    await Promise.resolve();
    return 42.0;
}
let p =launch foo(); // Acoroutine 
await p;
```
The error backtrace is same.