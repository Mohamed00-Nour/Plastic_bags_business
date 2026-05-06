import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/fcm_service.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.announcements),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,

      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.campaign_outlined,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(l10n.noAnnouncements,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5))),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final isActive = data['active'] == true;
              final titleEn = data['titleEn'] as String? ?? data['title'] as String? ?? '';
              final titleAr = data['titleAr'] as String? ?? titleEn;
              final messageEn = data['messageEn'] as String? ?? data['message'] as String? ?? '';
              final messageAr = data['messageAr'] as String? ?? messageEn;
              final createdAt =
                  (data['createdAt'] as Timestamp?)?.toDate();
              final dateFmt = intl.DateFormat('dd MMM yyyy, HH:mm');

              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.language, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    const Text('EN', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(titleEn,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.language, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    const Text('AR', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(titleAr,
                                          textDirection: TextDirection.rtl,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _StatusBadge(isActive: isActive, l10n: l10n),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // EN message
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('EN ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                          Expanded(child: Text(messageEn, style: Theme.of(context).textTheme.bodyMedium)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // AR message
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('AR ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                          Expanded(
                            child: Text(messageAr,
                                textDirection: TextDirection.rtl,
                                style: Theme.of(context).textTheme.bodyMedium)),
                        ],
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${l10n.announcementCreatedAt}: ${dateFmt.format(createdAt)}',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5)),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Toggle active/inactive
                          OutlinedButton.icon(
                            onPressed: () => _toggleActive(doc.id, isActive, data),
                            icon: Icon(
                              isActive
                                  ? Icons.pause_circle_outline
                                  : Icons.play_circle_outline,
                              size: 18,
                            ),
                            label: Text(isActive
                                ? l10n.announcementDeactivate
                                : l10n.announcementActivate),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isActive
                                  ? AppTheme.warningColor
                                  : AppTheme.successColor,
                              side: BorderSide(
                                  color: isActive
                                      ? AppTheme.warningColor
                                      : AppTheme.successColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _confirmDelete(context, doc.id, l10n),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: Text(l10n.announcementDelete),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.dangerColor,
                              side: BorderSide(color: AppTheme.dangerColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'quickPushFab',
            onPressed: () => _showQuickPushDialog(context, l10n),
            icon: const Icon(Icons.send_to_mobile_rounded),
            label: Text(l10n.quickPush),
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'newAnnouncementFab',
            onPressed: () => _showCreateDialog(context, l10n),
            icon: const Icon(Icons.campaign_rounded),
            label: Text(l10n.newAnnouncement),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(
      String docId, bool current, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(docId)
        .update({'active': !current});

    // Send FCM push when re-activating an announcement
    if (current == false) {
      final titleEn = data['titleEn'] as String? ?? data['title'] as String? ?? '';
      final titleAr = data['titleAr'] as String? ?? titleEn;
      final messageEn = data['messageEn'] as String? ?? data['message'] as String? ?? '';
      final messageAr = data['messageAr'] as String? ?? messageEn;
      await FcmService.sendToTopic(
        topic: 'announcements',
        title: titleEn,
        body: messageEn,
        titleAr: titleAr,
        bodyAr: messageAr,
      ).catchError((_) {}); // don't block UI on FCM errors
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, String docId, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.announcementDeleteConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.announcementDelete,
                  style: TextStyle(color: AppTheme.dangerColor))),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(docId)
          .delete();
    }
  }

  void _showCreateDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => _CreateAnnouncementDialog(l10n: l10n),
    );
  }

  void _showQuickPushDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => _QuickPushDialog(l10n: l10n),
    );
  }
}

// ── Status badge ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  final AppLocalizations l10n;

  const _StatusBadge({required this.isActive, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.successColor.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? AppTheme.successColor : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 10,
            color: isActive ? AppTheme.successColor : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? l10n.announcementLive : l10n.announcementInactive,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? AppTheme.successColor : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create dialog ──────────────────────────────────────────────────────────────

class _CreateAnnouncementDialog extends StatefulWidget {
  final AppLocalizations l10n;
  const _CreateAnnouncementDialog({required this.l10n});

  @override
  State<_CreateAnnouncementDialog> createState() =>
      _CreateAnnouncementDialogState();
}

class _CreateAnnouncementDialogState
    extends State<_CreateAnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleEnCtrl = TextEditingController();
  final _titleArCtrl = TextEditingController();
  final _messageEnCtrl = TextEditingController();
  final _messageArCtrl = TextEditingController();
  bool _loading = false;
  bool _sendPush = false;

  AppLocalizations get l10n => widget.l10n;

  @override
  void dispose() {
    _titleEnCtrl.dispose();
    _titleArCtrl.dispose();
    _messageEnCtrl.dispose();
    _messageArCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final titleEn = _titleEnCtrl.text.trim();
      final titleAr = _titleArCtrl.text.trim();
      final messageEn = _messageEnCtrl.text.trim();
      final messageAr = _messageArCtrl.text.trim();

      await FirebaseFirestore.instance.collection('announcements').add({
        'titleEn': titleEn,
        'titleAr': titleAr,
        'messageEn': messageEn,
        'messageAr': messageAr,
        // keep legacy fields for old clients
        'title': titleEn,
        'message': messageEn,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (_sendPush) {
        await FcmService.sendToTopic(
          topic: 'announcements',
          title: titleEn,
          body: messageEn,
          titleAr: titleAr,
          bodyAr: messageAr,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.announcementSent),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.campaign_rounded, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(l10n.newAnnouncement),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LangSectionHeader(flag: '🇬🇧', label: l10n.langEnglish),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleEnCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.announcementTitle,
                    hintText: l10n.announcementHintTitle,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.title),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.announcementTitle : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageEnCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.announcementMessage,
                    hintText: l10n.announcementHintMessage,
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.announcementMessage : null,
                ),
                const SizedBox(height: 20),
                _LangSectionHeader(flag: '🇸🇦', label: l10n.langArabic),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleArCtrl,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: l10n.announcementTitle,
                    hintText: l10n.announcementHintTitleAr,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.title),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.announcementTitle : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageArCtrl,
                  maxLines: 3,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: l10n.announcementMessage,
                    hintText: l10n.announcementHintMessageAr,
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.announcementMessage : null,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _sendPush,
                  onChanged: (v) => setState(() => _sendPush = v),
                  title: Text(l10n.sendPushNotification),
                  subtitle: Text(
                    _sendPush
                        ? l10n.sendPushNotificationHintOn
                        : l10n.sendPushNotificationHintOff,
                    style: TextStyle(
                      fontSize: 12,
                      color: _sendPush
                          ? AppTheme.successColor
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                    ),
                  ),
                  secondary: Icon(
                    _sendPush
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_outlined,
                    color: _sendPush ? AppTheme.successColor : Colors.grey,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send_rounded),
          label: Text(l10n.announcementSend),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ── Quick Push dialog ──────────────────────────────────────────────────────────

class _QuickPushDialog extends StatefulWidget {
  final AppLocalizations l10n;
  const _QuickPushDialog({required this.l10n});

  @override
  State<_QuickPushDialog> createState() => _QuickPushDialogState();
}

class _QuickPushDialogState extends State<_QuickPushDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleEnCtrl = TextEditingController();
  final _titleArCtrl = TextEditingController();
  final _messageEnCtrl = TextEditingController();
  final _messageArCtrl = TextEditingController();
  bool _loading = false;

  AppLocalizations get l10n => widget.l10n;

  @override
  void dispose() {
    _titleEnCtrl.dispose();
    _titleArCtrl.dispose();
    _messageEnCtrl.dispose();
    _messageArCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FcmService.sendToTopic(
        topic: 'announcements',
        title: _titleEnCtrl.text.trim(),
        body: _messageEnCtrl.text.trim(),
        titleAr: _titleArCtrl.text.trim(),
        bodyAr: _messageArCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.quickPushSent),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.send_to_mobile_rounded, color: Colors.deepOrange),
          const SizedBox(width: 8),
          Text(l10n.quickPush),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.deepOrange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l10n.quickPushSubtitle,
                            style: const TextStyle(fontSize: 12, color: Colors.deepOrange)),
                      ),
                    ],
                  ),
                ),
                _LangSectionHeader(flag: '🇬🇧', label: l10n.langEnglish),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleEnCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.announcementTitle,
                    hintText: l10n.announcementHintTitle,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.title),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.announcementTitle : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageEnCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.announcementMessage,
                    hintText: l10n.announcementHintMessage,
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.announcementMessage : null,
                ),
                const SizedBox(height: 20),
                _LangSectionHeader(flag: '🇸🇦', label: l10n.langArabic),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleArCtrl,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: l10n.announcementTitle,
                    hintText: l10n.announcementHintTitleAr,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.title),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.announcementTitle : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageArCtrl,
                  maxLines: 3,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: l10n.announcementMessage,
                    hintText: l10n.announcementHintMessageAr,
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.announcementMessage : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _send,
          icon: _loading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_to_mobile_rounded),
          label: Text(l10n.quickPush),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ── Language section header ────────────────────────────────────────────────────

class _LangSectionHeader extends StatelessWidget {
  final String flag;
  final String label;
  const _LangSectionHeader({required this.flag, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(flag, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
      ],
    );
  }
}
