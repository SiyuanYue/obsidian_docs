 ```cpp
 bool StackfulCoroutineManager::LaunchWithMode(CompletionEvent *completionEvent, Method *entrypoint,
                                               PandaVector<Value> &&arguments, CoroutineLaunchMode mode,
                                               bool launchImmediately)
 {
     // profiling: scheduler and launch time
     ScopedCoroutineStats sSch(&GetCurrentWorker()->GetPerfStats(), CoroutineTimeStats::SCH_ALL);
     ScopedCoroutineStats sLaunch(&GetCurrentWorker()->GetPerfStats(), CoroutineTimeStats::LAUNCH);
 
     LOG(DEBUG, COROUTINES) << "StackfulCoroutineManager::LaunchWithMode started";
 
     auto *co = Coroutine::GetCurrent();
     auto *w = co->GetContext<StackfulCoroutineContext>()->GetWorker();
     mode = (mode == CoroutineLaunchMode::DEFAULT && w->InExclusiveMode()) ? CoroutineLaunchMode::SAME_WORKER : mode;
     bool result = false;
     if (launchImmediately) {
         result = LaunchImmediatelyImpl(completionEvent, entrypoint, std::move(arguments), mode);
     } else {
         result = LaunchImpl(completionEvent, entrypoint, std::move(arguments), mode);
     }
     if (!result) {
         ThrowOutOfMemoryError("LaunchWithMode failed");
     }
 
     LOG(DEBUG, COROUTINES) << "StackfulCoroutineManager::LaunchWithMode finished";
     return result;
 }
 ```
 
 `StackfulCoroutineManager::LaunchWithMode` 函数的实现，它负责启动协程并根据不同的模式进行处理。首先，使用 [ScopedCoroutineStats](vscode-file://vscode-app/Applications/Visual%20Studio%20Code.app/Contents/Resources/app/out/vs/code/electron-sandbox/workbench/workbench.html) 对象记录调度和启动时间的性能统计信息。接着，记录日志，表明 `LaunchWithMode` 函数开始执行。

然后，获取当前协程对象，并通过上下文获取其所属的工作线程 `worker`。根据当前模式和工作线程的独占模式状态，决定是否修改启动模式。接下来，根据 [launchImmediately](vscode-file://vscode-app/Applications/Visual%20Studio%20Code.app/Contents/Resources/app/out/vs/code/electron-sandbox/workbench/workbench.html) 标志决定调用 [LaunchImmediatelyImpl](vscode-file://vscode-app/Applications/Visual%20Studio%20Code.app/Contents/Resources/app/out/vs/code/electron-sandbox/workbench/workbench.html) 或 [LaunchImpl](vscode-file://vscode-app/Applications/Visual%20Studio%20Code.app/Contents/Resources/app/out/vs/code/electron-sandbox/workbench/workbench.html) 函数来启动协程。

如果启动协程失败，则抛出内存不足错误。最后，记录日志，表明 `LaunchWithMode` 函数执行完毕，并返回启动结果。


```cpp
Class Coroutine{
...
CoroutineContext *context_ = nullptr;
CoroutineWorker *worker_ = nullptr;
CoroutineManager *manager_ = nullptr;
// NOTE(konstanting, #IAD5MH): check if we still need this functionality
bool startSuspended_ = false;
Type type_ = Type::MUTATOR;  // MUTATOR  普通协程 SCHEDULE 用来调度的协程 Main Coroutine 每个线程有一个
...
}
```


这种对模板限制是什么特性，可以传 false or true
```cpp
template <bool SUSPEND_AS_BLOCKED>
void StackfulCoroutineWorker::SuspendCurrentCoroGeneric()
{
    auto *currentCoro = Coroutine::GetCurrent();
    currentCoro->RequestSuspend(SUSPEND_AS_BLOCKED);
    if constexpr (!SUSPEND_AS_BLOCKED) {
        os::memory::LockHolder lock(runnablesLock_);
        PushToRunnableQueue(currentCoro);
    }
}

```