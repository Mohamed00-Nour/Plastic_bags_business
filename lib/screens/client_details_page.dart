import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:printing/printing.dart';
import '../core/theme/app_theme.dart';
import '../services/client_invoice_balance_sync_service.dart';
import '../services/client_statement_pdf_service.dart';
import '../services/sales_invoice_actions_service.dart';
import '../services/whatsapp_invoice_share_service.dart';
import 'sales_invoice_page.dart';

/// Complete, production-ready Client Details & Invoices Page (`ClientDetailsPage`).
class ClientDetailsPage extends StatefulWidget {
  final Map<String, dynamic>? clientData;
  final String? clientId;

  const ClientDetailsPage({
    super.key,
    this.clientData,
    this.clientId,
  });

  @override
  State<ClientDetailsPage> createState() => _ClientDetailsPageState();
}

class _ClientDetailsPageState extends State<ClientDetailsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd HH:mm');
  final ClientInvoiceBalanceSyncService _syncService = ClientInvoiceBalanceSyncService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _effectiveClientId {
    if (widget.clientId != null && widget.clientId!.isNotEmpty) {
      return widget.clientId!;
    }
    if (widget.clientData != null && widget.clientData!['id'] != null) {
      return widget.clientData!['id'].toString();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل العميل والمعاملات'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _effectiveClientId.isNotEmpty
            ? FirebaseFirestore.instance.collection('clients').doc(_effectiveClientId).snapshots()
            : null,
        builder: (context, snapshot) {
          Map<String, dynamic> client = widget.clientData ?? {};
          if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
            client = Map<String, dynamic>.from(snapshot.data!.data() as Map);
            client['id'] = snapshot.data!.id;
          }

          final clientName = client['name']?.toString() ?? 'عميل بدون اسم';
          final clientPhone = client['phone']?.toString() ?? '';
          final clientAddress = client['address']?.toString() ?? '';
          final balance = (client['balance'] ?? 0.0).toDouble();

          return Column(
            children: [
              // 1. Client Header Card
              _buildClientHeaderCard(
                client: client,
                clientName: clientName,
                clientPhone: clientPhone,
                clientAddress: clientAddress,
                balance: balance,
              ),

              // 2. Tab Navigation
              Container(
                color: Theme.of(context).cardColor,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.primaryColor,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(icon: Icon(Icons.receipt_long_rounded), text: 'الفواتير'),
                    Tab(icon: Icon(Icons.assignment_return_rounded), text: 'المرتجعات'),
                    Tab(icon: Icon(Icons.history_rounded), text: 'سجل الرصيد'),
                  ],
                ),
              ),

              // 3. Tab Views Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInvoicesTab(clientName: clientName, isSales: true),
                    _buildInvoicesTab(clientName: clientName, isSales: false),
                    _buildBalanceHistoryTab(client: client),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Header Card showing Client Info, Balance, and Top Action Buttons
  Widget _buildClientHeaderCard({
    required Map<String, dynamic> client,
    required String clientName,
    required String clientPhone,
    required String clientAddress,
    required double balance,
  }) {
    Color balanceColor;
    String balanceTitle;
    if (balance > 0) {
      balanceColor = AppTheme.dangerColor;
      balanceTitle = 'مديونية مستحقة على العميل';
    } else if (balance < 0) {
      balanceColor = Colors.blue;
      balanceTitle = 'رصيد دائن للمحل';
    } else {
      balanceColor = AppTheme.successColor;
      balanceTitle = 'لا يوجد مديونية';
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  child: Text(
                    clientName.isNotEmpty ? clientName.substring(0, 1).toUpperCase() : 'C',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (clientPhone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(clientPhone, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ],
                      if (clientAddress.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                clientAddress,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Balance Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: balanceColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: balanceColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        balanceTitle,
                        style: TextStyle(fontSize: 10, color: balanceColor, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$${balance.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: balanceColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Action Buttons Bar
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                    label: const Text('تعديل الرصيد', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _showBalanceAdjustmentModal(context, client),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('كشف الحساب', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _showStatementFilterDialog(context, client),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Invoices Tab (Collapsible List for Sales or Returns)
  Widget _buildInvoicesTab({required String clientName, required bool isSales}) {
    final collectionName = isSales ? 'sales_invoices' : 'return_invoices';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionName)
          .where('clientName', isEqualTo: clientName)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSales ? Icons.receipt_long_outlined : Icons.assignment_return_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                Text(
                  isSales ? 'لا يوجد فواتير مبيعات لهذا العميل' : 'لا يوجد فواتير مرتجعات لهذا العميل',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final invoices = docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          data['id'] = doc.id;
          return data;
        }).toList()
          ..sort((a, b) {
            final da = a['createdAt'] ?? a['date'];
            final db = b['createdAt'] ?? b['date'];
            DateTime ta = DateTime.now();
            DateTime tb = DateTime.now();
            if (da is Timestamp) ta = da.toDate();
            if (db is Timestamp) tb = db.toDate();
            return tb.compareTo(ta);
          });

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: invoices.length,
          itemBuilder: (context, index) {
            final inv = invoices[index];
            return _buildCollapsibleInvoiceCard(invoice: inv, isSales: isSales);
          },
        );
      },
    );
  }

  // Collapsible Invoice Card Item
  Widget _buildCollapsibleInvoiceCard({required Map<String, dynamic> invoice, required bool isSales}) {
    final invoiceNumber = invoice['invoiceNumber']?.toString() ?? 'INV-000';
    final totalAmount = (invoice['totalAmount'] ?? 0.0).toDouble();
    final paidAmount = (invoice['paidAmount'] ?? 0.0).toDouble();
    final remainingAmount = (invoice['remainingAmount'] ?? (totalAmount - paidAmount)).toDouble();
    final items = (invoice['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final paymentMethod = invoice['paymentMethod']?.toString() ?? 'نقدي';

    final rawDate = invoice['createdAt'] ?? invoice['date'];
    DateTime date = DateTime.now();
    if (rawDate is Timestamp) date = rawDate.toDate();

    Color statusColor;
    String statusText;
    if (remainingAmount <= 0) {
      statusColor = AppTheme.successColor;
      statusText = 'مدفوع بالكامل';
    } else if (paidAmount > 0) {
      statusColor = Colors.amber;
      statusText = 'مدفوع جزئياً';
    } else {
      statusColor = AppTheme.dangerColor;
      statusText = 'آجل / متبقي';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: isSales
              ? AppTheme.successColor.withValues(alpha: 0.15)
              : Colors.orange.withValues(alpha: 0.15),
          child: Icon(
            isSales ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: isSales ? AppTheme.successColor : Colors.orange,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              '#$invoiceNumber',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusText,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${_dateFormat.format(date)} • $paymentMethod',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (remainingAmount > 0)
              Text(
                'متبقي: \$${remainingAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.dangerColor, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const Text(
                  'تفاصيل الأصناف:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: items.map((item) {
                      final name = item['productName'] ?? item['name'] ?? 'منتج';
                      final qty = item['quantity'] ?? 1;
                      final price = (item['price'] ?? 0.0).toDouble();
                      final total = price * qty;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
                            Text('x$qty', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(width: 16),
                            Text('\$${price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(width: 16),
                            Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('المدفوع: \$${paidAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('المتبقي: \$${remainingAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.dangerColor)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),

                // Action Buttons for this Invoice
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('تعديل'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SalesInvoicePage(initialInvoiceData: invoice),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.delete_forever_rounded, size: 18),
                      label: const Text('حذف'),
                      onPressed: () async {
                        await SalesInvoiceActionsService.deleteSalesInvoice(
                          context: context,
                          invoiceData: invoice,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('طباعة'),
                      onPressed: () async {
                        final pdfBytes = await ClientStatementPdfService.generateSalesInvoicePdf(
                          invoiceData: invoice,
                        );
                        await Printing.layoutPdf(onLayout: (_) => pdfBytes);
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('مشاركة واتساب'),
                      onPressed: () async {
                        final pdfBytes = await ClientStatementPdfService.generateSalesInvoicePdf(
                          invoiceData: invoice,
                        );
                        if (!mounted) return;
                        await WhatsappInvoiceShareService.showShareOptions(
                          context: context,
                          invoiceData: invoice,
                          pdfBytes: pdfBytes,
                          isSalesInvoice: isSales,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Balance History Tab
  Widget _buildBalanceHistoryTab({required Map<String, dynamic> client}) {
    return StreamBuilder<List<ClientBalanceRecord>>(
      stream: _effectiveClientId.isNotEmpty
          ? _syncService.getClientBalanceHistoryStream(_effectiveClientId)
          : Stream.value([]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return const Center(
            child: Text(
              'لا يوجد سجل كشف حساب لهذا العميل حتى الآن',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final rec = records[index];
            final isPayment = rec.type == 'payment' || rec.type == 'sales_return';
            final isInvoice = rec.type == 'sales_invoice' || rec.type == 'opening';

            Color amountColor = Colors.grey;
            IconData icon = Icons.swap_horiz_rounded;
            if (isPayment) {
              amountColor = AppTheme.successColor;
              icon = Icons.add_circle_outline_rounded;
            } else if (isInvoice) {
              amountColor = AppTheme.dangerColor;
              icon = Icons.remove_circle_outline_rounded;
            }

            final String typeDesc;
            if (rec.type == 'manual_debt' || rec.type == 'debt' || (rec.type == 'sales_invoice' && rec.invoiceNumber.isEmpty)) {
              typeDesc = 'إضافة مديونية';
            } else if (rec.type == 'sales_invoice') {
              typeDesc = 'فاتورة مبيعات ${rec.invoiceNumber.isNotEmpty ? "#${rec.invoiceNumber}" : ""}';
            } else if (rec.type == 'payment') {
              typeDesc = 'تحصيل دفعة مالية';
            } else if (rec.type == 'sales_return') {
              typeDesc = 'فاتورة مرتجع';
            } else if (rec.type == 'cancellation') {
              typeDesc = 'إلغاء فاتورة';
            } else {
              typeDesc = 'حركة رصيد';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: amountColor.withValues(alpha: 0.15),
                  child: Icon(icon, color: amountColor),
                ),
                title: Text(typeDesc, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(_dateFormat.format(rec.timestamp), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${rec.amount.toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: amountColor),
                    ),
                    Text(
                      'الرصيد بعدها: \$${rec.balanceAfter.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Balance Adjustment Modal (Tabs for Add Payment / Add Debt)
  void _showBalanceAdjustmentModal(BuildContext context, Map<String, dynamic> client) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bCtx) {
        return DefaultTabController(
          length: 2,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(bCtx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'تعديل رصيد العميل',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),
                TabBar(
                  indicatorColor: AppTheme.primaryColor,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: 'إضافة دفعة (خصم رصيد)'),
                    Tab(text: 'إضافة مديونية (زيادة رصيد)'),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ (\$)',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات / طريقة الدفع',
                    prefixIcon: Icon(Icons.note_alt_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TabBarView(
                    children: [
                      // Mode 1: Add Payment (Reduce Balance)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor, foregroundColor: Colors.white),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('تسجيل الدفعة وخصم المديونية', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final amt = double.tryParse(amountController.text) ?? 0.0;
                          if (amt <= 0) return;
                          Navigator.of(bCtx).pop();

                          await _addManualPayment(amount: amt, notes: notesController.text.trim(), date: selectedDate);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم تسجيل الدفعة وتحديث رصيد العميل بنجاح')),
                            );
                          }
                        },
                      ),

                      // Mode 2: Add Debt (Increase Balance)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor, foregroundColor: Colors.white),
                        icon: const Icon(Icons.add_circle_rounded),
                        label: const Text('إضافة مديونية جديدة على العميل', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final amt = double.tryParse(amountController.text) ?? 0.0;
                          if (amt <= 0) return;
                          Navigator.of(bCtx).pop();

                          await _addManualDebt(amount: amt, notes: notesController.text.trim(), date: selectedDate);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم إضافة المديونية وتحديث رصيد العميل بنجاح')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Atomic payment addition transaction
  Future<void> _addManualPayment({
    required double amount,
    required String notes,
    required DateTime date,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final clientRef = firestore.collection('clients').doc(_effectiveClientId);

    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(clientRef);
      if (!snapshot.exists) return;

      final currentBalance = (snapshot.data()?['balance'] ?? 0.0).toDouble();
      final newBalance = currentBalance - amount;

      transaction.update(clientRef, {'balance': newBalance});

      final historyRef = clientRef.collection('balanceHistory').doc();
      transaction.set(historyRef, {
        'type': 'payment',
        'description': notes.isEmpty ? 'تحصيل دفعة نقداً' : notes,
        'amount': amount,
        'balanceBefore': currentBalance,
        'balanceAfter': newBalance,
        'timestamp': Timestamp.fromDate(date),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Atomic manual debt addition transaction
  Future<void> _addManualDebt({
    required double amount,
    required String notes,
    required DateTime date,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final clientRef = firestore.collection('clients').doc(_effectiveClientId);

    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(clientRef);
      if (!snapshot.exists) return;

      final currentBalance = (snapshot.data()?['balance'] ?? 0.0).toDouble();
      final newBalance = currentBalance + amount;

      transaction.update(clientRef, {'balance': newBalance});

      final historyRef = clientRef.collection('balanceHistory').doc();
      transaction.set(historyRef, {
        'type': 'manual_debt',
        'description': notes.isEmpty ? 'إضافة مديونية' : notes,
        'amount': amount,
        'balanceBefore': currentBalance,
        'balanceAfter': newBalance,
        'timestamp': Timestamp.fromDate(date),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Statement Filter Dialog (Date range & Statement Type)
  void _showStatementFilterDialog(BuildContext context, Map<String, dynamic> client) {
    DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
    DateTime toDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('كشف حساب العميل (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.date_range_rounded, color: AppTheme.primaryColor),
                    title: const Text('من تاريخ:'),
                    subtitle: Text(DateFormat('yyyy/MM/dd').format(fromDate)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fromDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => fromDate = picked);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.event_rounded, color: AppTheme.primaryColor),
                    title: const Text('إلى تاريخ:'),
                    subtitle: Text(DateFormat('yyyy/MM/dd').format(toDate)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: toDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => toDate = picked);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dCtx).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('عرض وتصدير كشف الحساب'),
                  onPressed: () async {
                    Navigator.of(dCtx).pop();

                    final recordsQuery = await FirebaseFirestore.instance
                        .collection('clients')
                        .doc(_effectiveClientId)
                        .collection('balanceHistory')
                        .get();

                    final records = recordsQuery.docs
                        .map((doc) => ClientBalanceRecord.fromFirestore(doc))
                        .where((r) {
                      return r.timestamp.isAfter(fromDate.subtract(const Duration(days: 1))) &&
                          r.timestamp.isBefore(toDate.add(const Duration(days: 1)));
                    }).toList()
                      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

                    if (!context.mounted) return;

                    await ClientStatementPdfService.printOrShareClientStatement(
                      clientData: client,
                      records: records,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
