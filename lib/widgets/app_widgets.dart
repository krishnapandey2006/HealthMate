import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';

/// The HealthMate mark is drawn in code so it stays crisp at every size and
/// does not depend on a stale raster asset. The medical cross sits on the brand
/// green with a quiet ECG line through it.
class AppMark extends StatelessWidget {
  final double size;
  final bool withShadow;

  const AppMark({super.key, this.size = 44, this.withShadow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: withShadow ? AppShadows.brand : null,
      ),
      child: CustomPaint(painter: _AppMarkPainter()),
    );
  }
}

class _AppMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final crossPaint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.15;
    final arm = size.width * 0.25;
    canvas.drawLine(
      Offset(center.dx - arm, center.dy),
      Offset(center.dx + arm, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - arm),
      Offset(center.dx, center.dy + arm),
      crossPaint,
    );

    final pulse = Paint()
      ..color = AppColors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.062
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.18, center.dy)
      ..lineTo(size.width * 0.34, center.dy)
      ..lineTo(size.width * 0.42, center.dy - size.height * 0.12)
      ..lineTo(size.width * 0.52, center.dy + size.height * 0.12)
      ..lineTo(size.width * 0.60, center.dy)
      ..lineTo(size.width * 0.82, center.dy);
    canvas.drawPath(path, pulse);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final bool withShadow;

  const AppLogo({
    super.key,
    this.size = 44,
    this.showWordmark = false,
    this.withShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final logo = AppMark(size: size, withShadow: withShadow);

    if (!showWordmark) return logo;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 11),
        Text(
          'HealthMate',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: size > 40 ? 22 : 19,
                letterSpacing: -0.7,
                color: AppColors.navy,
              ),
        ),
      ],
    );
  }
}

/// A card with consistent padding and optional tap behaviour. Use this instead
/// of building one-off decorated containers so every surface shares the same
/// radius, border and interaction feedback.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool clip;
  final BorderRadius? borderRadius;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.clip = false,
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadii.lg);
    final decoration = BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: radius,
      border: border ?? Border.all(color: AppColors.border),
      boxShadow: AppShadows.card,
    );
    final content = Padding(padding: padding, child: child);
    if (onTap == null) {
      return DecoratedBox(
        decoration: decoration,
        child: clip
            ? ClipRRect(borderRadius: radius, child: content)
            : content,
      );
    }
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: clip
              ? ClipRRect(borderRadius: radius, child: content)
              : content,
        ),
      ),
    );
  }
}

class AppSectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const AppSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.25,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Small label used above section titles to group content without adding
/// another heavy visual element.
class AppEyebrow extends StatelessWidget {
  final String text;
  final Color color;

  const AppEyebrow(this.text, {super.key, this.color = AppColors.tealDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.15,
      ),
    );
  }
}

class AppIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final double size;
  final double iconSize;

  const AppIconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.teal,
    this.background = AppColors.tealSoft,
    this.size = 46,
    this.iconSize = 23,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class AppSheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  const AppSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          AppIconBadge(icon: icon!, size: 42, iconSize: 21),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class AppStatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const AppStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.color = AppColors.teal,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Groups related rows in one bordered panel separated by hairlines. Used so
/// repeated items read as a single list instead of a stack of identical cards.
class AppListPanel extends StatelessWidget {
  final List<Widget> children;

  const AppListPanel({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.only(left: 16, right: 16),
                child: Divider(),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A tappable icon / title / subtitle row with an optional trailing slot.
class AppNavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconColor;
  final double titleSize;
  final FontWeight titleWeight;

  const AppNavTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor = AppColors.tealDark,
    this.titleSize = 15,
    this.titleWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: titleWeight,
                      color: AppColors.navy,
                      height: 1.3,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ] else
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class AppStatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  const AppStatusChip({
    super.key,
    required this.label,
    this.color = AppColors.slate,
    this.background = AppColors.neutralSoft,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.tealSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.teal, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const AppErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppInfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color background;
  final Widget? trailing;

  const AppInfoBanner({
    super.key,
    required this.icon,
    required this.text,
    this.color = AppColors.tealDark,
    this.background = AppColors.tealSoft,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13, height: 1.45),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class AppSkeletonBox extends StatelessWidget {
  final double height;
  final double width;
  final double radius;

  const AppSkeletonBox({
    super.key,
    this.height = 14,
    this.width = double.infinity,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8F0ED),
      highlightColor: const Color(0xFFF7FBFA),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ArticleSkeleton extends StatelessWidget {
  const ArticleSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSkeletonBox(height: 82, width: 82, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  AppSkeletonBox(height: 16),
                  SizedBox(height: 8),
                  AppSkeletonBox(height: 12),
                  SizedBox(height: 6),
                  AppSkeletonBox(height: 12, width: 180),
                  SizedBox(height: 12),
                  AppSkeletonBox(height: 10, width: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showAppSnackBar(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: isError ? AppColors.danger : AppColors.navy,
    ),
  );
}

Future<bool> openExternalUrl(BuildContext context, String? rawUrl, {String? failureMessage}) async {
  final raw = rawUrl?.trim() ?? '';
  if (raw.isEmpty) {
    showAppSnackBar(context, failureMessage ?? 'No link is available for this item.', isError: true);
    return false;
  }
  var candidate = raw;
  if (candidate.startsWith('//')) candidate = 'https:$candidate';
  if (!candidate.startsWith('http')) candidate = 'https://$candidate';
  final uri = Uri.tryParse(candidate);
  if (uri == null || !uri.hasAbsolutePath && uri.host.isEmpty) {
    showAppSnackBar(context, failureMessage ?? 'This link is not valid.', isError: true);
    return false;
  }
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      if (context.mounted) {
        showAppSnackBar(context, failureMessage ?? 'Could not open this link.', isError: true);
      }
      return false;
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, failureMessage ?? 'Could not open this link.', isError: true);
    }
    return false;
  }
}

String formatShortDate(DateTime date, AppLocalizations l10n) {
  final now = DateTime.now();
  final difference = now.difference(date);
  if (difference.inMinutes < 1) return l10n.t('just_now');
  if (difference.inMinutes < 60) return '${difference.inMinutes}m';
  if (difference.inHours < 24) return '${difference.inHours}h';
  if (difference.inDays == 1) return l10n.t('yesterday');
  if (difference.inDays < 7) return '${difference.inDays}d';
  return '${date.day}/${date.month}/${date.year}';
}

String formatDateTime(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String formatDateRange(DateTime start, DateTime end) {
  if (start.year == end.year && start.month == end.month && start.day == end.day) {
    return formatDateTime(start);
  }
  return '${formatDateTime(start)} – ${formatDateTime(end)}';
}
