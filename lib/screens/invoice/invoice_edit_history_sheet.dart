import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../features/home/widgets/home_accent.dart';
import '../../services/invoice_service.dart';
import '../../services/permission_service.dart';

class InvoiceEditHistorySheet extends StatefulWidget {
  final int transactionId;
  final Future<void> Function()? onRestored;

  const InvoiceEditHistorySheet({
    super.key,
    required this.transactionId,
    this.onRestored,
  });

  @override
  State<InvoiceEditHistorySheet> createState() =>
      _InvoiceEditHistorySheetState();
}

class _InvoiceEditHistorySheetState extends State<InvoiceEditHistorySheet> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _history;

  bool get _canRestore => PermissionService().canRestoreInvoiceSnapshot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await InvoiceService.instance.getEditHistory(
        widget.transactionId,
      );
      if (!mounted) return;
      setState(() {
        _history = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _restore(Map<String, dynamic> entry) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استرجاع نسخة قديمة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيتم إعادة الأصناف والإجماليات والمخزون للحالة السابقة، وسيُسجل الاسترجاع كتعديل جديد.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'سبب الاسترجاع *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(ctx, value);
            },
            icon: const Icon(Icons.settings_backup_restore_rounded),
            label: const Text('تأكيد الاسترجاع'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final auditId = entry['auditId'] is int
          ? entry['auditId'] as int
          : int.parse('${entry['auditId']}');
      await InvoiceService.instance.restoreSnapshot(
        widget.transactionId,
        auditId,
        reason: reason,
      );
      await widget.onRestored?.call();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم استرجاع النسخة وتحديث المخزون بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = ((_history?['entries'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.90,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: HomeAccent.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: HomeAccent.gold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'سجل تعديلات الفاتورة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            _history?['referenceNumber']?.toString() ??
                                '#${widget.transactionId}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _errorState()
                        : entries.isEmpty
                            ? const Center(child: Text('لا توجد تعديلات مسجلة'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: entries.length + 1,
                                itemBuilder: (_, index) {
                                  if (index == entries.length) {
                                    return _createdCard();
                                  }
                                  return _entryCard(entries[index]);
                                },
                              ),
              ),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 14),
                          Text('جاري استرجاع النسخة...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _errorState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 10),
            Text(_error ?? 'حدث خطأ'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );

  Widget _entryCard(Map<String, dynamic> entry) {
    final theme = Theme.of(context);
    final action = entry['actionType']?.toString() ?? '';
    final color = _actionColor(action);
    final canRestore = _canRestore && entry['canRestore'] == true;
    final diff = _extractDiff(entry);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_actionIcon(action), color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _actionLabel(action),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${entry['loginName'] ?? '—'} • ${_date(entry['actionDate'])}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((entry['reason'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('السبب: ${entry['reason']}', style: const TextStyle(fontSize: 12)),
          ],
          if (diff.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...diff.take(5).map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.arrow_left_rounded, color: color, size: 18),
                        Expanded(child: Text(line, style: const TextStyle(fontSize: 11.5))),
                      ],
                    ),
                  ),
                ),
          ],
          if (canRestore) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _restore(entry),
                icon: const Icon(Icons.settings_backup_restore_rounded),
                label: const Text('استرجاع هذه النسخة'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _createdCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HomeAccent.navy.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: HomeAccent.navy.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_circle_outline_rounded, color: HomeAccent.navy),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'إنشاء الفاتورة بواسطة ${_history?['createdBy'] ?? '—'}\n${_date(_history?['createdAt'])}',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
      );

  List<String> _extractDiff(Map<String, dynamic> entry) {
    try {
      final oldData = jsonDecode(entry['oldData']?.toString() ?? '{}');
      final newData = jsonDecode(entry['newData']?.toString() ?? '{}');
      if (oldData is! Map || newData is! Map) return const [];
      final lines = <String>[];
      void compare(String key, String label) {
        final a = oldData[key];
        final b = newData[key];
        if ('$a' != '$b') lines.add('$label: ${a ?? '—'} ← ${b ?? '—'}');
      }

      compare('GrandTotal', 'الإجمالي');
      compare('DiscountAmount', 'الخصم');
      compare('WarehouseId', 'المخزن');
      compare('DueDate', 'تاريخ التسليم');
      final oldItems = oldData['Items'] is List ? (oldData['Items'] as List).length : null;
      final newItems = newData['Items'] is List ? (newData['Items'] as List).length : null;
      if (oldItems != null && newItems != null && oldItems != newItems) {
        lines.add('عدد الأصناف: $oldItems ← $newItems');
      }
      return lines;
    } catch (_) {
      return const [];
    }
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null ? '—' : DateFormat('yyyy/MM/dd HH:mm').format(date);
  }

  String _actionLabel(String action) => switch (action) {
        'FullEdit' => 'تعديل كامل للفاتورة',
        'EditRequest' => 'طلب تعديل',
        'EditApprove' => 'اعتماد طلب التعديل',
        'EditReject' => 'رفض طلب التعديل',
        'Restore' => 'استرجاع نسخة',
        _ => action.isEmpty ? 'تحديث' : action,
      };

  IconData _actionIcon(String action) => switch (action) {
        'FullEdit' => Icons.edit_note_rounded,
        'EditRequest' => Icons.pending_actions_rounded,
        'EditApprove' => Icons.check_circle_rounded,
        'EditReject' => Icons.cancel_rounded,
        _ => Icons.history_rounded,
      };

  Color _actionColor(String action) => switch (action) {
        'FullEdit' => HomeAccent.gold,
        'EditRequest' => Colors.orange,
        'EditApprove' => Colors.green,
        'EditReject' => Colors.red,
        _ => HomeAccent.indigo,
      };
}
