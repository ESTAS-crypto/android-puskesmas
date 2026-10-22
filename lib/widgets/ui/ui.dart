import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import 'app_icons.dart';
export 'app_icons.dart';

// ════════════════════════════════════════════════════════════
//  AppCard — permukaan yang bisa ditekan (ripple + skala halus)
// ════════════════════════════════════════════════════════════
class AppCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final String? semanticLabel;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.borderColor,
    this.radius = AppRadius.lg,
    this.semanticLabel,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null || widget.onLongPress != null;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(widget.radius),
      side: BorderSide(color: widget.borderColor ?? AppTheme.outline),
    );

    final hasShadow = (widget.color == null || widget.color == AppTheme.surface) &&
        (widget.borderColor == null || widget.borderColor != Colors.transparent);

    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: hasShadow ? AppTheme.cardShadow : null,
      ),
      child: Material(
        color: widget.color ?? AppTheme.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          onLongPress: widget.onLongPress,
          onHighlightChanged: interactive ? (v) => setState(() => _down = v) : null,
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );

    if (interactive) {
      card = AnimatedScale(
        scale: _down ? 0.98 : 1,
        duration: _down ? AppMotion.instant : AppMotion.fast,
        curve: AppMotion.standard,
        child: card,
      );
    }

    if (widget.semanticLabel != null) {
      card = Semantics(
        container: true,
        button: widget.onTap != null,
        label: widget.semanticLabel,
        excludeSemantics: true,
        onTap: widget.onTap,
        child: card,
      );
    }
    return card;
  }
}

// ════════════════════════════════════════════════════════════
//  AppButton — primary / tonal / ghost / danger, dengan loading
// ════════════════════════════════════════════════════════════
enum AppButtonKind { primary, tonal, ghost, danger }

class AppButton extends StatefulWidget {
  final String label;
  final Object? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final AppButtonKind kind;
  final bool expand;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.kind = AppButtonKind.primary,
    this.expand = true,
    this.height,
    this.padding,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _down = false;

  (Color, Color, Color?) get _colors {
    switch (widget.kind) {
      case AppButtonKind.primary:
        return (AppTheme.primaryDeep, Colors.white, null);
      case AppButtonKind.tonal:
        return (AppTheme.tint(AppTheme.accent), AppTheme.accent, null);
      case AppButtonKind.ghost:
        return (Colors.transparent, AppTheme.textMuted, AppTheme.outline);
      case AppButtonKind.danger:
        return (AppTheme.tint(AppTheme.error), AppTheme.error, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = _colors;
    final enabled = widget.onPressed != null && !widget.loading;
    final disabledLook = widget.onPressed == null && !widget.loading;
    final btnHeight = widget.height ?? 50.0;
    final isCompact = btnHeight <= 42.0;
    final effectivePadding = widget.padding ??
        EdgeInsets.symmetric(
          horizontal: isCompact ? 10.0 : 18.0,
          vertical: isCompact ? 0.0 : 10.0,
        );
    final fontSize = isCompact ? 13.5 : 15.0;

    final content = AnimatedSwitcher(
      duration: AppMotion.fast,
      switchInCurve: AppMotion.decelerate,
      switchOutCurve: AppMotion.accelerate,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1).animate(anim),
          child: child,
        ),
      ),
      child: widget.loading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  AppIcon(widget.icon!, size: isCompact ? 16 : 20, color: fg),
                  SizedBox(width: isCompact ? 6 : 8),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
    );

    final button = AnimatedScale(
      scale: _down && enabled ? 0.97 : 1,
      duration: _down ? AppMotion.instant : AppMotion.fast,
      curve: AppMotion.standard,
      child: AnimatedOpacity(
        opacity: disabledLook ? 0.45 : 1,
        duration: AppMotion.fast,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isCompact ? 11 : AppRadius.md),
            side: border == null ? BorderSide.none : BorderSide(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    widget.onPressed!();
                  }
                : null,
            onHighlightChanged: (v) => setState(() => _down = v),
            child: Container(
              height: btnHeight,
              padding: effectivePadding,
              alignment: Alignment.center,
              child: content,
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.loading ? '${widget.label}, sedang diproses' : widget.label,
      excludeSemantics: true,
      onTap: enabled ? widget.onPressed : null,
      child: widget.expand
          ? SizedBox(width: double.infinity, child: button)
          : button,
    );
  }
}

// ════════════════════════════════════════════════════════════
//  AppIconButton — target sentuh 44px + tooltip (juga label TalkBack)
// ════════════════════════════════════════════════════════════
class AppIconButton extends StatelessWidget {
  final Object icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppTheme.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppTheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            width: 44,
            height: 44,
            child: AppIcon(icon, size: 20, color: color ?? AppTheme.textMuted),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  StatusPill — label kecil berwarna
// ════════════════════════════════════════════════════════════
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Object? icon;

  const StatusPill({
    super.key,
    required this.label,
    this.color = AppTheme.accent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.tint(color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon!, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  SectionTitle
// ════════════════════════════════════════════════════════════
class SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionTitle(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
//  EmptyState
// ════════════════════════════════════════════════════════════
class EmptyState extends StatelessWidget {
  final Object icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.tint(AppTheme.accent, 0.10),
              shape: BoxShape.circle,
            ),
            child: AppIcon(icon, color: AppTheme.accent, size: 30),
          ),
          const SizedBox(height: 16),
          Text(title, style: t.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: t.bodyMedium, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  CountUp — angka yang naik halus (dan menyesuaikan saat berubah)
// ════════════════════════════════════════════════════════════
class CountUp extends StatelessWidget {
  final int value;
  final TextStyle? style;

  const CountUp(this.value, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: AppMotion.of(context, AppMotion.slow),
      curve: AppMotion.decelerate,
      builder: (_, v, __) => RepaintBoundary(
        child: Text(v.round().toString(), style: style),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  StaggerScope + StaggerIn — satu koreografi masuk per layar
//  (satu controller, tiap elemen punya jeda kecil; hormati "kurangi animasi")
// ════════════════════════════════════════════════════════════
class StaggerScope extends StatefulWidget {
  final Duration duration;
  final Widget Function(BuildContext context, Animation<double> animation) builder;

  const StaggerScope({
    super.key,
    this.duration = const Duration(milliseconds: 900),
    required this.builder,
  });

  @override
  State<StaggerScope> createState() => _StaggerScopeState();
}

class _StaggerScopeState extends State<StaggerScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _c);
}

class StaggerIn extends StatelessWidget {
  final Animation<double> animation;
  final int index;
  final double rise;
  final Widget child;

  const StaggerIn({
    super.key,
    required this.animation,
    required this.index,
    this.rise = 16,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.08).clamp(0.0, 0.6);
    final end = (start + 0.5).clamp(0.0, 1.0);
    final t = animation.drive(
      CurveTween(curve: Interval(start, end, curve: AppMotion.decelerate)),
    );
    return FadeTransition(
      opacity: t,
      child: AnimatedBuilder(
        animation: t,
        child: child,
        builder: (_, c) => Transform.translate(
          offset: Offset(0, rise * (1 - t.value)),
          child: c,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  AppToast — Pesan singkat mengambang di bawah (Pesan.dc.html)
// ════════════════════════════════════════════════════════════
enum AppToastKind { info, success, warning, error }

class AppToast {
  AppToast._();

  static void show(
    BuildContext context,
    String message, {
    AppToastKind kind = AppToastKind.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();

    final (glyph, iconColor) = switch (kind) {
      AppToastKind.info => (AppGlyph.report, const Color(0xFF8FD0FF)),
      AppToastKind.success => (AppGlyph.check, const Color(0xFF7FE0A8)),
      AppToastKind.warning => (AppGlyph.warning, const Color(0xFFFFD28A)),
      AppToastKind.error => (AppGlyph.warning, const Color(0xFFFFB4AB)),
    };

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0B2A40),
        elevation: 6,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: AppIcon(glyph, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8FD0FF),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  AppConfirmSheet — Dialog konfirmasi bottom sheet (Konfirmasi.dc.html)
// ════════════════════════════════════════════════════════════
class AppConfirmSheet {
  AppConfirmSheet._();

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Batal',
    bool isDangerous = false,
    int pendingCount = 0,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(11, 42, 64, 0.14),
              blurRadius: 34,
              offset: Offset(0, 14),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          24 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppTheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 16,
                height: 1.45,
              ),
            ),
            if (pendingCount > 0) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(
                  label: '$pendingCount belum terkirim',
                  icon: AppGlyph.cloud,
                  color: AppTheme.warning,
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (isDangerous && pendingCount > 0) ...[
              AppButton(
                label: cancelLabel == 'Batal' ? 'Tetap di sini' : cancelLabel,
                kind: AppButtonKind.ghost,
                onPressed: () => Navigator.pop(ctx, false),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: confirmLabel,
                kind: AppButtonKind.danger,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ] else ...[
              AppButton(
                label: confirmLabel,
                kind: isDangerous ? AppButtonKind.danger : AppButtonKind.primary,
                onPressed: () => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: cancelLabel,
                kind: AppButtonKind.ghost,
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ],
          ],
        ),
      ),
    );
    return result ?? false;
  }
}

