import 'package:flutter/material.dart';

class FrameLeanColors extends ThemeExtension<FrameLeanColors> {
  const FrameLeanColors({
    required this.primary,
    required this.primarySoft,
    required this.progress,
    required this.statusRunning,
    required this.statusMissingSource,
    required this.statusCancelled,
    required this.statusPending,
    required this.statusFailed,
    required this.runningSoft,
    required this.failedSoft,
    required this.surfaceCanvas,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceDisabled,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.iconMuted,
    required this.shadow,
    required this.onPrimary,
    required this.onDanger,
    required this.onWarning,
  });

  final Color primary;
  final Color primarySoft;
  final Color progress;
  final Color statusRunning;
  final Color statusMissingSource;
  final Color statusCancelled;
  final Color statusPending;
  final Color statusFailed;
  final Color runningSoft;
  final Color failedSoft;
  final Color surfaceCanvas;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceDisabled;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color iconMuted;
  final Color shadow;
  final Color onPrimary;
  final Color onDanger;
  final Color onWarning;

  @override
  FrameLeanColors copyWith({
    Color? primary,
    Color? primarySoft,
    Color? progress,
    Color? statusRunning,
    Color? statusMissingSource,
    Color? statusCancelled,
    Color? statusPending,
    Color? statusFailed,
    Color? runningSoft,
    Color? failedSoft,
    Color? surfaceCanvas,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceDisabled,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? iconMuted,
    Color? shadow,
    Color? onPrimary,
    Color? onDanger,
    Color? onWarning,
  }) {
    return FrameLeanColors(
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      progress: progress ?? this.progress,
      statusRunning: statusRunning ?? this.statusRunning,
      statusMissingSource: statusMissingSource ?? this.statusMissingSource,
      statusCancelled: statusCancelled ?? this.statusCancelled,
      statusPending: statusPending ?? this.statusPending,
      statusFailed: statusFailed ?? this.statusFailed,
      runningSoft: runningSoft ?? this.runningSoft,
      failedSoft: failedSoft ?? this.failedSoft,
      surfaceCanvas: surfaceCanvas ?? this.surfaceCanvas,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceDisabled: surfaceDisabled ?? this.surfaceDisabled,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      iconMuted: iconMuted ?? this.iconMuted,
      shadow: shadow ?? this.shadow,
      onPrimary: onPrimary ?? this.onPrimary,
      onDanger: onDanger ?? this.onDanger,
      onWarning: onWarning ?? this.onWarning,
    );
  }

  @override
  FrameLeanColors lerp(ThemeExtension<FrameLeanColors>? other, double t) {
    if (other is! FrameLeanColors) {
      return this;
    }

    return FrameLeanColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      progress: Color.lerp(progress, other.progress, t)!,
      statusRunning: Color.lerp(statusRunning, other.statusRunning, t)!,
      statusMissingSource: Color.lerp(
        statusMissingSource,
        other.statusMissingSource,
        t,
      )!,
      statusCancelled: Color.lerp(statusCancelled, other.statusCancelled, t)!,
      statusPending: Color.lerp(statusPending, other.statusPending, t)!,
      statusFailed: Color.lerp(statusFailed, other.statusFailed, t)!,
      runningSoft: Color.lerp(runningSoft, other.runningSoft, t)!,
      failedSoft: Color.lerp(failedSoft, other.failedSoft, t)!,
      surfaceCanvas: Color.lerp(surfaceCanvas, other.surfaceCanvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceDisabled: Color.lerp(surfaceDisabled, other.surfaceDisabled, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
    );
  }
}

const frameLeanLightColors = FrameLeanColors(
  primary: Color(0xFF1D48E6),
  primarySoft: Color(0xFFE9EEFF),
  progress: Color(0xFFD3DBFC),
  statusRunning: Color(0xFFFF8000),
  statusMissingSource: Color(0xFF3F4C63),
  statusCancelled: Color(0xFFB7BCC4),
  statusPending: Color(0xFFE9CB0A),
  statusFailed: Color(0xFFAA0315),
  runningSoft: Color(0xFFFFEAD6),
  failedSoft: Color(0xFFFFE7EA),
  surfaceCanvas: Color(0xFFF5F7FB),
  surface: Color(0xFFFFFFFF),
  surfaceMuted: Color(0xFFF7F8FA),
  surfaceDisabled: Color(0xFFF2F4F7),
  border: Color(0xFFE2E6EE),
  borderStrong: Color(0xFFC9D0DC),
  textPrimary: Color(0xFF111827),
  textSecondary: Color(0xFF5F6878),
  textTertiary: Color(0xFF9AA3B2),
  iconMuted: Color(0xFF8791A0),
  shadow: Color(0x14000000),
  onPrimary: Color(0xFFFFFFFF),
  onDanger: Color(0xFFFFFFFF),
  onWarning: Color(0xFF111827),
);

const frameLeanDarkColors = FrameLeanColors(
  primary: Color(0xFF6F8DFF),
  primarySoft: Color(0xFF1A2A5F),
  progress: Color(0xFF263A86),
  statusRunning: Color(0xFFFF9B3D),
  statusMissingSource: Color(0xFF526987),
  statusCancelled: Color(0xFF5F6B7A),
  statusPending: Color(0xFFF0D84B),
  statusFailed: Color(0xFFFF5C6C),
  runningSoft: Color(0xFF33251A),
  failedSoft: Color(0xFF351B22),
  surfaceCanvas: Color(0xFF0B0F17),
  surface: Color(0xFF121826),
  surfaceMuted: Color(0xFF182132),
  surfaceDisabled: Color(0xFF202838),
  border: Color(0xFF273244),
  borderStrong: Color(0xFF3A4A63),
  textPrimary: Color(0xFFF4F7FB),
  textSecondary: Color(0xFFB6C0CE),
  textTertiary: Color(0xFF7E8A9A),
  iconMuted: Color(0xFF9AA6B8),
  shadow: Color(0x66000000),
  onPrimary: Color(0xFF101624),
  onDanger: Color(0xFFFFFFFF),
  onWarning: Color(0xFF111827),
);
