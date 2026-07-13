# 调度器死锁修复：非阻塞 tryAcquire + 串行区外释放租约

## 日期

2026-07-12

## 状态

有效

## 背景

`FfmpegTaskQueueRunner._serializeCommand` 提供串行命令锁，保证任务状态变更（启动、完成、失败、取消、暂停、恢复、继续下一个）按 FIFO 顺序执行，避免并发修改导致的状态不一致。

`MediaWorkScheduler.acquire()` 在资源不足时会创建一个 `Completer` 并等待，只有资源释放后才会完成。这个等待可能无限长。

**死锁链**：

1. `startTask` 在 `_serializeCommand` 串行区内调用 `scheduler.acquire()`，资源不足时 `Completer` 永远等不到完成——因为完成它的代码也在等待进入同一串行区。
2. `observeExecution` 中的 `finishObservedTask` 也需要进入 `_serializeCommand`，但当前串行区被 `startTask` 占用，形成循环等待。
3. 结果：整个队列执行器死锁，`startTask` 永远不返回，后续所有任务都无法启动。

## 决策

采用三步修复打破死锁链：

### 1. 新增非阻塞 `tryAcquire()`

`MediaWorkScheduler` 新增 `tryAcquire()` 方法：资源不足时立即返回 `null`，不创建 `Completer`。`startTask` 在串行区内使用 `tryAcquire()` 替代 `acquire()`，资源不足时立即返回 `queued` 状态。

### 2. 租约释放在串行区外执行

`observeExecution` 改为两阶段：先在串行命令外调用 `_releaseSchedulerLease()`，再进入 `_serializeCommand` 进行收尾清理。这样租约释放不再依赖串行命令锁。

### 3. 租约释放幂等化

`_releaseSchedulerLease` 立即清空 `execution.schedulerLease` 后再 best-effort 释放，确保多次调用或异常路径下不会重复释放。

## 影响范围

- `MediaWorkScheduler`: 新增 `tryAcquire()`，`acquire()` 文档增强
- `FfmpegTaskQueueRunner.observeExecution`: 重构为两阶段
- `FfmpegTaskQueueRunner.startTask`: 改用 `tryAcquire()`
- `FfmpegTaskQueueRunner._releaseSchedulerLease`: 幂等化
- `FfmpegTaskQueueRunner._pauseExecution`: 暂停时释放租约
- `FfmpegTaskQueueRunner.resumeExecution`: 恢复时重新申请租约

## 关联事实

- `CONTEXT.md`
- `docs/develop/architecture.md`
- `docs/lessons.md`（死锁诊断经验）
