import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';

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
              final title = data['title'] as String? ?? '';
              final message = data['message'] as String? ?? '';
              final createdAt =
                  (data['createdAt'] as Timestamp?)?.toDate();
              final dateFmt = DateFormat('dd MMM yyyy, HH:mm');

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
                            child: Text(title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold)),
                          ),
                          _StatusBadge(isActive: isActive, l10n: l10n),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(message,
                          style: Theme.of(context).textTheme.bodyMedium),
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
                            onPressed: () => _toggleActive(doc.id, isActive),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, l10n),
        icon: const Icon(Icons.campaign_rounded),
        label: Text(l10n.newAnnouncement),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _toggleActive(String docId, bool current) async {
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(docId)
        .update({'active': !current});
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
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _loading = false;

  AppLocalizations get l10n => widget.l10n;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': _titleCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
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
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: l10n.announcementTitle,
                  hintText: l10n.announcementHintTitle,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.announcementTitle : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.announcementMessage,
                  hintText: l10n.announcementHintMessage,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.message_outlined),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.announcementMessage : null,
              ),
            ],
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
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
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
