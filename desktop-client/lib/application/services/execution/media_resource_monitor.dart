import 'dart:async';
import 'dart:io';

/// 系统资源压力级别。
enum MediaResourcePressure {
  /// 资源充足，正常工作。
  normal,

  /// 资源压力：停止启动新的后台工作，不启动第二个正式任务。
  underPressure,

  /// 严重资源压力：暂停低优先级任务，仅保留前台工作。
  severePressure,
}

/// 内存采样快照。
class MemorySample {
  const MemorySample({
    required this.totalBytes,
    required this.availableBytes,
    required this.timestamp,
  });

  final int totalBytes;
  final int availableBytes;
  final DateTime timestamp;

  /// 可用内存占总内存的比例 (0.0-1.0)。
  double get availableRatio =>
      totalBytes > 0 ? availableBytes / totalBytes : 1.0;
}

/// 轻量级系统资源监控器。
///
/// 每 1 秒采样一次系统可用内存，计算资源压力级别。
/// 使用迟滞机制防止在压力边界反复抖动：
/// - 进入压力状态：单次采样低于阈值即触发
/// - 退出压力状态：需要连续 [stableWindow] 秒采样高于恢复阈值
///
/// 平台支持：
/// - macOS: sysctl + vm_stat
/// - Windows: wmic
/// - Linux: /proc/meminfo
class MediaResourceMonitor {
  MediaResourceMonitor({
    this.sampleInterval = const Duration(seconds: 1),
    this.stableWindow = const Duration(seconds: 12),
    this.underPressureAvailableRatio = 0.20,
    this.severePressureAvailableRatio = 0.10,
    this.underPressureAvailableBytes = 4 * 1024 * 1024 * 1024, // 4 GB
    this.severePressureAvailableBytes = 2 * 1024 * 1024 * 1024, // 2 GB
    this.recoveryAvailableRatio = 0.25,
    this.recoveryAvailableBytes = 5 * 1024 * 1024 * 1024, // 5 GB
    this.severeRecoveryAvailableRatio = 0.15,
    this.severeRecoveryAvailableBytes = 3 * 1024 * 1024 * 1024, // 3 GB
    int? totalMemoryBytesOverride,
  }) : _totalMemoryBytesOverride = totalMemoryBytesOverride;

  /// 采样间隔，默认 1 秒。
  final Duration sampleInterval;

  /// 压力恢复所需的稳定观察窗口，默认 12 秒。
  final Duration stableWindow;

  // ---- 压力进入阈值（低阈值触发） ----

  /// 进入 underPressure 的可用内存比例阈值。
  final double underPressureAvailableRatio;

  /// 进入 severePressure 的可用内存比例阈值。
  final double severePressureAvailableRatio;

  /// 进入 underPressure 的可用内存绝对值阈值。
  final int underPressureAvailableBytes;

  /// 进入 severePressure 的可用内存绝对值阈值。
  final int severePressureAvailableBytes;

  // ---- 恢复退出阈值（较高阈值，迟滞） ----

  /// 退出 underPressure 需要的可用内存比例阈值。
  final double recoveryAvailableRatio;

  /// 退出 underPressure 需要的可用内存绝对值阈值。
  final int recoveryAvailableBytes;

  /// 退出 severePressure 需要的可用内存比例阈值。
  final double severeRecoveryAvailableRatio;

  /// 退出 severePressure 需要的可用内存绝对值阈值。
  final int severeRecoveryAvailableBytes;

  final int? _totalMemoryBytesOverride;

  MediaResourcePressure _currentPressure = MediaResourcePressure.normal;
  Timer? _timer;
  int _consecutiveRecoverySamples = 0;
  int? _cachedTotalMemoryBytes;
  List<MemorySample>? _recentSamples;

  final StreamController<MediaResourcePressure> _pressureController =
      StreamController<MediaResourcePressure>.broadcast();

  /// 当前资源压力级别。
  MediaResourcePressure get currentPressure => _currentPressure;

  /// 压力变化的广播流。
  Stream<MediaResourcePressure> get pressureChanges =>
      _pressureController.stream;

  /// 最近一次内存采样快照，可能为 null（尚未采样或采样失败）。
  MemorySample? get lastSample {
    final samples = _recentSamples;
    if (samples == null || samples.isEmpty) {
      return null;
    }
    return samples.last;
  }

  /// 是否正在运行。
  bool get isRunning => _timer != null;

  /// 启动周期性资源采样。
  void start() {
    if (_timer != null) {
      return;
    }
    _consecutiveRecoverySamples = 0;
    _currentPressure = MediaResourcePressure.normal;

    // 立即执行一次采样以获取初始状态。
    _sample();

    _timer = Timer.periodic(sampleInterval, (_) => _sample());
  }

  /// 停止采样并释放资源。
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _recentSamples = null;
    await _pressureController.close();
  }

  // ------------------------------------------------------------------
  // Private
  // ------------------------------------------------------------------

  void _sample() {
    final totalBytes = _totalMemoryBytesOverride ?? _cachedTotalMemoryBytes;
    if (totalBytes == null || totalBytes <= 0) {
      // 尚未获取总内存，先尝试获取一次。
      _cachedTotalMemoryBytes = _bestEffortTotalMemory();
      if (_cachedTotalMemoryBytes == null || _cachedTotalMemoryBytes! <= 0) {
        return; // 无法获取内存信息，保持当前状态。
      }
    }

    final availableBytes = _bestEffortAvailableMemory();
    if (availableBytes == null) {
      return; // 无法获取可用内存，保持当前状态。
    }

    final total = _cachedTotalMemoryBytes!;
    final sample = MemorySample(
      totalBytes: total,
      availableBytes: availableBytes,
      timestamp: DateTime.now(),
    );

    _recentSamples ??= [];
    _recentSamples!.add(sample);

    // 只保留最近 stableWindow 内的采样记录。
    final cutoff =
        sample.timestamp.millisecondsSinceEpoch - stableWindow.inMilliseconds;
    _recentSamples!.removeWhere(
      (s) => s.timestamp.millisecondsSinceEpoch < cutoff,
    );

    final ratio = sample.availableRatio;
    final newPressure = _computePressure(
      availableBytes: availableBytes,
      ratio: ratio,
      totalBytes: total,
    );

    if (newPressure != _currentPressure) {
      _currentPressure = newPressure;
      _pressureController.add(newPressure);
    }
  }

  MediaResourcePressure _computePressure({
    required int availableBytes,
    required double ratio,
    required int totalBytes,
  }) {
    final isSevere = ratio <= severePressureAvailableRatio ||
        availableBytes <= severePressureAvailableBytes;

    final isUnderPressure = ratio <= underPressureAvailableRatio ||
        availableBytes <= underPressureAvailableBytes;

    if (_currentPressure == MediaResourcePressure.normal) {
      // 当前正常 → 检查是否进入压力。
      if (isSevere) {
        _consecutiveRecoverySamples = 0;
        return MediaResourcePressure.severePressure;
      }
      if (isUnderPressure) {
        _consecutiveRecoverySamples = 0;
        return MediaResourcePressure.underPressure;
      }
      return MediaResourcePressure.normal;
    }

    if (_currentPressure == MediaResourcePressure.underPressure) {
      // 当前压力 → 检查是否升级或恢复。
      if (isSevere) {
        _consecutiveRecoverySamples = 0;
        return MediaResourcePressure.severePressure;
      }

      // 检查是否满足恢复条件。
      final recovered = ratio > recoveryAvailableRatio &&
          availableBytes > recoveryAvailableBytes;
      if (recovered) {
        _consecutiveRecoverySamples++;
        if (_consecutiveRecoverySamples >= _requiredStableSamples) {
          _consecutiveRecoverySamples = 0;
          return MediaResourcePressure.normal;
        }
      } else {
        _consecutiveRecoverySamples = 0;
      }
      return MediaResourcePressure.underPressure;
    }

    // currentPressure == severePressure
    if (!isSevere) {
      // 检查是否降级到 underPressure。
      final recoveredToUnderPressure = ratio > severeRecoveryAvailableRatio &&
          availableBytes > severeRecoveryAvailableBytes;
      if (recoveredToUnderPressure) {
        _consecutiveRecoverySamples++;
        if (_consecutiveRecoverySamples >= _requiredStableSamples) {
          _consecutiveRecoverySamples = 0;
          // 降级到 underPressure（而非直接到 normal）。
          return MediaResourcePressure.underPressure;
        }
      } else {
        _consecutiveRecoverySamples = 0;
      }
    } else {
      _consecutiveRecoverySamples = 0;
    }
    return MediaResourcePressure.severePressure;
  }

  /// 稳定窗口所需的连续采样次数。
  int get _requiredStableSamples =>
      (stableWindow.inMilliseconds / sampleInterval.inMilliseconds).ceil();

  // ------------------------------------------------------------------
  // Platform memory helpers
  // ------------------------------------------------------------------

  int? _bestEffortTotalMemory() {
    if (Platform.isWindows) {
      return _readWindowsTotalMemory();
    }
    if (Platform.isMacOS) {
      return _readMacOSTotalMemory();
    }
    if (Platform.isLinux) {
      return _readLinuxTotalMemory();
    }
    return null;
  }

  int? _bestEffortAvailableMemory() {
    if (Platform.isWindows) {
      return _readWindowsAvailableMemory();
    }
    if (Platform.isMacOS) {
      return _readMacOSAvailableMemory();
    }
    if (Platform.isLinux) {
      return _readLinuxAvailableMemory();
    }
    return null;
  }

  // --- macOS ---

  static int? _readMacOSTotalMemory() {
    try {
      final result = Process.runSync('sysctl', const ['-n', 'hw.memsize']);
      if (result.exitCode == 0) {
        return int.tryParse(result.stdout.toString().trim());
      }
    } on Object {
      // Fall through.
    }
    return null;
  }

  static int? _readMacOSAvailableMemory() {
    try {
      // 使用 vm_stat 获取空闲 + 非活跃页面，乘以页面大小。
      final pageSizeResult = Process.runSync(
        'sysctl',
        const ['-n', 'hw.pagesize'],
      );
      final pageSize = int.tryParse(
        pageSizeResult.stdout.toString().trim(),
      );
      if (pageSize == null || pageSize <= 0) {
        return null;
      }

      final vmStatResult = Process.runSync('vm_stat', const []);
      if (vmStatResult.exitCode != 0) {
        return null;
      }
      final output = vmStatResult.stdout.toString();

      int? extractPages(String key) {
        final match = RegExp('$key:\\s+(\\d+)').firstMatch(output);
        if (match != null) {
          return int.tryParse(match.group(1)!);
        }
        return null;
      }

      final freePages = extractPages('Pages free') ?? 0;
      final inactivePages = extractPages('Pages inactive') ?? 0;
      final speculativePages = extractPages('Pages speculative') ?? 0;

      return (freePages + inactivePages + speculativePages) * pageSize;
    } on Object {
      // Fall through.
    }
    return null;
  }

  // --- Windows ---

  static int? _readWindowsTotalMemory() {
    try {
      final result = Process.runSync(
        'wmic',
        const ['computersystem', 'get', 'TotalPhysicalMemory'],
      );
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final match = RegExp(r'(\d+)').firstMatch(output);
        if (match != null) {
          return int.tryParse(match.group(1)!);
        }
      }
    } on Object {
      // Fall through.
    }
    return null;
  }

  static int? _readWindowsAvailableMemory() {
    try {
      // FreePhysicalMemory 返回 KB。
      final result = Process.runSync(
        'wmic',
        const ['OS', 'get', 'FreePhysicalMemory'],
      );
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final match = RegExp(r'(\d+)').firstMatch(output);
        if (match != null) {
          final kb = int.tryParse(match.group(1)!);
          if (kb != null) {
            return kb * 1024; // 转换为字节。
          }
        }
      }
    } on Object {
      // Fall through.
    }
    return null;
  }

  // --- Linux ---

  static int? _readLinuxTotalMemory() {
    try {
      final file = File('/proc/meminfo');
      if (!file.existsSync()) {
        return null;
      }
      final contents = file.readAsStringSync();
      final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(contents);
      if (match != null) {
        final kb = int.tryParse(match.group(1)!);
        if (kb != null) {
          return kb * 1024;
        }
      }
    } on Object {
      // Fall through.
    }
    return null;
  }

  static int? _readLinuxAvailableMemory() {
    try {
      final file = File('/proc/meminfo');
      if (!file.existsSync()) {
        return null;
      }
      final contents = file.readAsStringSync();
      // 优先使用 MemAvailable（内核 3.14+），回退到 MemFree + Buffers + Cached。
      final availableMatch =
          RegExp(r'MemAvailable:\s+(\d+)\s+kB').firstMatch(contents);
      if (availableMatch != null) {
        final kb = int.tryParse(availableMatch.group(1)!);
        if (kb != null) {
          return kb * 1024;
        }
      }

      // 回退：MemFree + Buffers + Cached。
      int? extractKb(String key) {
        final match = RegExp('$key:\\s+(\\d+)\\s+kB').firstMatch(contents);
        if (match != null) {
          return int.tryParse(match.group(1)!);
        }
        return null;
      }

      final memFree = extractKb('MemFree') ?? 0;
      final buffers = extractKb('Buffers') ?? 0;
      final cached = extractKb('Cached') ?? 0;
      return (memFree + buffers + cached) * 1024;
    } on Object {
      // Fall through.
    }
    return null;
  }
}
