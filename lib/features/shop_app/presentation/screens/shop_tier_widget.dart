import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

// ── Tier definitions ──────────────────────────────────────────────────────────

enum ShopTier { bronze, silver, gold, platinum }

class TierInfo {
  final ShopTier tier;
  final String Function(AppLocalizations) nameGetter;
  final double minPurchases;
  final double maxPurchases; // double.infinity for top tier
  final Color color;
  final Color bgColor;
  final IconData icon;
  final String Function(AppLocalizations) benefitGetter;

  const TierInfo({
    required this.tier,
    required this.nameGetter,
    required this.minPurchases,
    required this.maxPurchases,
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.benefitGetter,
  });
}

final List<TierInfo> kTiers = [
  TierInfo(
    tier: ShopTier.bronze,
    nameGetter: (l10n) => l10n.tierBronze,
    minPurchases: 0,
    maxPurchases: 10000,
    color: const Color(0xFFCD7F32),
    bgColor: const Color(0xFFFFF3E0),
    icon: Icons.military_tech_rounded,
    benefitGetter: (l10n) => l10n.benefitBronze,
  ),
  TierInfo(
    tier: ShopTier.silver,
    nameGetter: (l10n) => l10n.tierSilver,
    minPurchases: 10000,
    maxPurchases: 30000,
    color: const Color(0xFF9E9E9E),
    bgColor: const Color(0xFFF5F5F5),
    icon: Icons.military_tech_rounded,
    benefitGetter: (l10n) => l10n.benefitSilver,
  ),
  TierInfo(
    tier: ShopTier.gold,
    nameGetter: (l10n) => l10n.tierGold,
    minPurchases: 30000,
    maxPurchases: 75000,
    color: const Color(0xFFFFB300),
    bgColor: const Color(0xFFFFFDE7),
    icon: Icons.emoji_events_rounded,
    benefitGetter: (l10n) => l10n.benefitGold,
  ),
  TierInfo(
    tier: ShopTier.platinum,
    nameGetter: (l10n) => l10n.tierPlatinum,
    minPurchases: 75000,
    maxPurchases: double.infinity,
    color: const Color(0xFF7B1FA2),
    bgColor: const Color(0xFFF3E5F5),
    icon: Icons.diamond_rounded,
    benefitGetter: (l10n) => l10n.benefitPlatinum,
  ),
];

TierInfo _getTierForAmount(double totalPurchases) {
  for (final tier in kTiers.reversed) {
    if (totalPurchases >= tier.minPurchases) return tier;
  }
  return kTiers.first;
}

// ── Main widget ───────────────────────────────────────────────────────────────

class ShopTierWidget extends StatelessWidget {
  final double totalPurchases;

  const ShopTierWidget({super.key, required this.totalPurchases});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = _getTierForAmount(totalPurchases);
    final currentIndex = kTiers.indexOf(current);
    final isTopTier = currentIndex == kTiers.length - 1;
    final next = isTopTier ? null : kTiers[currentIndex + 1];
    final numFmt = NumberFormat('#,##0');

    // Progress within current tier
    double progress = 1.0;
    double remaining = 0;
    if (!isTopTier) {
      final tierRange = current.maxPurchases - current.minPurchases;
      final inTier = (totalPurchases - current.minPurchases).clamp(0, tierRange);
      progress = inTier / tierRange;
      remaining = current.maxPurchases - totalPurchases;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? current.color.withValues(alpha: 0.12)
        : current.bgColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header label ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            l10n.currentTier,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),

        // ── Tier card ─────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: current.color.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: current.color.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Tier badge row ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    // Medal icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: current.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: current.color.withValues(alpha: 0.5),
                            width: 2),
                      ),
                      child: Icon(current.icon,
                          color: current.color, size: 30),
                    ),
                    const SizedBox(width: 16),
                    // Tier name & label
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                current.nameGetter(l10n),
                                style: TextStyle(
                                  color: current.color,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: current.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  l10n.tierYouAreHere,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: current.color,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.star_rounded,
                                  size: 14, color: current.color),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${l10n.tierCurrentBenefits}: ${current.benefitGetter(l10n)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? current.color.withValues(alpha: 0.9)
                                        : current.color
                                            .withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Progress section ──────────────────────────────────────
              if (!isTopTier) ...[
                Divider(
                    height: 1,
                    color: current.color.withValues(alpha: 0.2)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress label row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${l10n.tierProgressIn} ${current.nameGetter(l10n)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: current.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor:
                              current.color.withValues(alpha: 0.18),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              current.color),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Amount markers
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            numFmt.format(current.minPurchases),
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                          Text(
                            numFmt.format(totalPurchases),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: current.color,
                            ),
                          ),
                          Text(
                            numFmt.format(current.maxPurchases),
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Remaining amount callout
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: current.color.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.trending_up_rounded,
                                color: current.color, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: numFmt.format(remaining),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: current.color,
                                        fontSize: 13,
                                      ),
                                    ),
                                    TextSpan(
                                        text:
                                            '  ${l10n.tierRemainingPrefix} '),
                                    TextSpan(
                                      text: next!.nameGetter(l10n),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: next.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Top tier achieved
                Divider(
                    height: 1,
                    color: current.color.withValues(alpha: 0.2)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.celebration_rounded,
                          color: current.color, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l10n.tierAchieved,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: current.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Next tier preview ─────────────────────────────────────
              if (next != null) ...[
                _NextTierPreview(next: next, l10n: l10n, isDark: isDark),
              ],
            ],
          ),
        ),

        // ── All tiers timeline ────────────────────────────────────────────
        const SizedBox(height: 20),
        _TierTimeline(
          currentTier: current,
          totalPurchases: totalPurchases,
          l10n: l10n,
          isDark: isDark,
        ),
      ],
    );
  }
}

// ── Next tier preview banner ───────────────────────────────────────────────────

class _NextTierPreview extends StatelessWidget {
  final TierInfo next;
  final AppLocalizations l10n;
  final bool isDark;

  const _NextTierPreview(
      {required this.next, required this.l10n, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: next.color.withValues(alpha: isDark ? 0.1 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: next.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(next.icon, color: next.color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.tierNextBenefits}: ${next.nameGetter(l10n)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  next.benefitGetter(l10n),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: next.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── All tiers timeline ─────────────────────────────────────────────────────────

class _TierTimeline extends StatelessWidget {
  final TierInfo currentTier;
  final double totalPurchases;
  final AppLocalizations l10n;
  final bool isDark;

  const _TierTimeline({
    required this.currentTier,
    required this.totalPurchases,
    required this.l10n,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final numFmt = NumberFormat('#,##0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.tierProgress,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...kTiers.map((tier) {
          final isReached = totalPurchases >= tier.minPurchases;
          final isCurrent = tier == currentTier;
          final isTopTier = tier.maxPurchases == double.infinity;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                // Timeline dot + line
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isReached
                              ? tier.color
                              : tier.color.withValues(alpha: 0.18),
                          border: isCurrent
                              ? Border.all(
                                  color: tier.color, width: 3)
                              : null,
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color:
                                        tier.color.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  )
                                ]
                              : null,
                        ),
                        child: Icon(
                          isReached ? Icons.check_rounded : tier.icon,
                          size: 14,
                          color: isReached
                              ? Colors.white
                              : tier.color.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Tier details
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? tier.color.withValues(alpha: isDark ? 0.15 : 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isCurrent
                          ? Border.all(
                              color: tier.color.withValues(alpha: 0.3))
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tier.nameGetter(l10n),
                              style: TextStyle(
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isReached
                                    ? tier.color
                                    : (isDark
                                        ? Colors.white38
                                        : Colors.black.withValues(alpha: 0.3)),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              tier.benefitGetter(l10n),
                              style: TextStyle(
                                fontSize: 11,
                                color: isReached
                                    ? (isDark
                                        ? Colors.white60
                                        : Colors.black54)
                                    : (isDark
                                        ? Colors.white24
                                        : Colors.black26),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          isTopTier
                              ? '${numFmt.format(tier.minPurchases)}+'
                              : numFmt.format(tier.minPurchases),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isReached
                                ? tier.color
                                : (isDark
                                    ? Colors.white30
                                    : Colors.black.withValues(alpha: 0.3)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
