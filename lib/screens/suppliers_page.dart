import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supplier_invoice_balance_sync_service.dart';
import '../services/supplier_statement_pdf_service.dart';
import '../core/theme/app_theme.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final SupplierInvoiceBalanceSyncService _supplierSyncService = SupplierInvoiceBalanceSyncService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddSupplierDialog(BuildContext context, bool isArabic) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final openingBalanceController = TextEditingController(text: '0.0');
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
              child: AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.local_shipping_rounded, color: AppTheme.accentColor),
                    const SizedBox(width: 8),
                    Text(isArabic ? 'إضافة مورد جديد' : 'Add New Supplier'),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: isArabic ? 'اسم المورد *' : 'Supplier Name *',
                            prefixIcon: const Icon(Icons.business),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return isArabic ? 'برجاء إدخال اسم المورد' : 'Please enter supplier name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: isArabic ? 'رقم الهاتف *' : 'Phone Number *',
                            prefixIcon: const Icon(Icons.phone_outlined),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return isArabic ? 'برجاء إدخال رقم الهاتف' : 'Please enter phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addressController,
                          decoration: InputDecoration(
                            labelText: isArabic ? 'العنوان' : 'Address',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: openingBalanceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: isArabic ? 'الرصيد الافتتاحي (دائن للمورد)' : 'Opening Balance (Credit)',
                            prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                            helperText: isArabic
                                ? 'المبلغ المستحق للمورد عند تسجيله'
                                : 'Amount owed to supplier at registration',
                          ),
                          validator: (val) {
                            if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                              return isArabic ? 'مبلغ غير صحيح' : 'Invalid amount';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            setDialogState(() => isLoading = true);
                            try {
                              final name = nameController.text.trim();
                              final phone = phoneController.text.trim();
                              final address = addressController.text.trim();
                              final openingBal = double.tryParse(openingBalanceController.text.trim()) ?? 0.0;

                              final isDup = await _supplierSyncService.isDuplicateSupplierName(name);
                              if (isDup) {
                                setDialogState(() => isLoading = false);
                                if (!dialogContext.mounted) return;
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isArabic
                                          ? 'عفواً، يوجد مورد بنفس الاسم بالفعل!'
                                          : 'A supplier with this name already exists!',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              await _supplierSyncService.createSupplier(
                                name: name,
                                phone: phone,
                                address: address,
                                openingBalance: openingBal,
                              );

                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isArabic ? 'تم إضافـة المورد بنجاح' : 'Supplier created successfully',
                                  ),
                                  backgroundColor: AppTheme.successColor,
                                ),
                              );
                            } catch (e) {
                              setDialogState(() => isLoading = false);
                              if (!dialogContext.mounted) return;
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    child: isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isArabic ? 'حفظ' : 'Save'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showBalanceHistoryDialog(BuildContext context, Map<String, dynamic> supplierData, bool isArabic) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _SupplierBalanceHistoryDialogContent(
          supplierData: supplierData,
          isArabic: isArabic,
          supplierSyncService: _supplierSyncService,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Top Bar & Action Button
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  if (isMobile) {
                    return Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          decoration: InputDecoration(
                            hintText: isArabic ? 'بحث بالاسم أو رقم الهاتف...' : 'Search by name or phone...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => _showAddSupplierDialog(context, isArabic),
                            icon: const Icon(Icons.add),
                            label: Text(isArabic ? 'إضافة مورد' : 'Add Supplier'),
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          decoration: InputDecoration(
                            hintText: isArabic ? 'بحث بالاسم أو رقم الهاتف...' : 'Search by name or phone...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showAddSupplierDialog(context, isArabic),
                        icon: const Icon(Icons.add),
                        label: Text(isArabic ? 'إضافة مورد' : 'Add Supplier'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(140, 48)),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // Main List & KPI Summary
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _supplierSyncService.getSuppliersStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final suppliers = snapshot.data ?? [];
                    final filteredSuppliers = suppliers.where((s) {
                      final name = (s['name'] ?? '').toString().toLowerCase();
                      final phone = (s['phone'] ?? '').toString().toLowerCase();
                      final q = _searchQuery.toLowerCase();
                      return name.contains(q) || phone.contains(q);
                    }).toList();

                    final totalCredit = filteredSuppliers.fold<double>(
                      0.0,
                      (acc, item) => acc + (((item['totalBalance'] ?? item['balance'] ?? 0.0) as num).toDouble()),
                    );

                    final supplierCountLabel = isArabic ? '${filteredSuppliers.length} موردين' : '${filteredSuppliers.length} Suppliers';

                    return Column(
                      children: [
                        // KPI Summary Card
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance, color: AppTheme.accentColor, size: 28),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isArabic ? 'إجمالي الديون المستحقة للموردين' : 'Total Supplier Credit Payables',
                                      style: Theme.of(context).textTheme.titleSmall,
                                    ),
                                    Text(
                                      '\$${totalCredit.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.warningColor),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Chip(
                                  label: Text(supplierCountLabel),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Suppliers List
                        Expanded(
                          child: filteredSuppliers.isEmpty
                              ? Center(
                                  child: Text(
                                    isArabic ? 'لا يوجد موردين مطبقين للبحث' : 'No suppliers found',
                                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filteredSuppliers.length,
                                  itemBuilder: (context, index) {
                                    final supplier = filteredSuppliers[index];
                                    final balance = ((supplier['totalBalance'] ?? supplier['balance'] ?? 0.0) as num).toDouble();

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: AppTheme.accentColor.withValues(alpha: 0.15),
                                          child: Text(
                                            (supplier['name'] ?? 'S').toString().substring(0, 1).toUpperCase(),
                                            style: const TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        title: Text(
                                          supplier['name'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          '${supplier['phone'] ?? ''} ${supplier['address'] != null && supplier['address'].isNotEmpty ? "• ${supplier['address']}" : ""}',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  isArabic ? 'مستحق للمورد' : 'Credit Due',
                                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                ),
                                                Text(
                                                  '\$${balance.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: balance > 0 ? AppTheme.warningColor : AppTheme.successColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 12),
                                            IconButton(
                                              icon: const Icon(Icons.history_rounded, color: AppTheme.accentColor),
                                              tooltip: isArabic ? 'كشف حساب وتاريخ الرصيد' : 'Balance History & Statement',
                                              onPressed: () => _showBalanceHistoryDialog(context, supplier, isArabic),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplierBalanceHistoryDialogContent extends StatefulWidget {
  final Map<String, dynamic> supplierData;
  final bool isArabic;
  final SupplierInvoiceBalanceSyncService supplierSyncService;

  const _SupplierBalanceHistoryDialogContent({
    required this.supplierData,
    required this.isArabic,
    required this.supplierSyncService,
  });

  @override
  State<_SupplierBalanceHistoryDialogContent> createState() => _SupplierBalanceHistoryDialogContentState();
}

class _SupplierBalanceHistoryDialogContentState extends State<_SupplierBalanceHistoryDialogContent> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  String _getTypeLabel(String type, bool isArabic) {
    if (isArabic) {
      switch (type) {
        case 'opening':
          return 'رصيد افتتاحي';
        case 'buying_invoice':
          return 'فاتورة شراء';
        case 'purchase_return':
          return 'مرتجع مشتريات';
        case 'payment':
          return 'سداد للمورد';
        default:
          return 'حركة رصيد';
      }
    } else {
      switch (type) {
        case 'opening':
          return 'Opening Balance';
        case 'buying_invoice':
          return 'Buying Invoice';
        case 'purchase_return':
          return 'Purchase Return';
        case 'payment':
          return 'Supplier Payment';
        default:
          return 'Transaction';
      }
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'opening':
        return Colors.blue;
      case 'buying_invoice':
        return Colors.orange;
      case 'purchase_return':
        return Colors.teal;
      case 'payment':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final supplierId = widget.supplierData['id'] ?? '';
    final supplierName = widget.supplierData['name'] ?? '';
    final isArabic = widget.isArabic;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = screenWidth > 850 ? 800.0 : screenWidth * 0.94;
    final dialogHeight = screenHeight > 650 ? 600.0 : screenHeight * 0.90;

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, color: AppTheme.accentColor),
                      const SizedBox(width: 8),
                      Text(
                        '${isArabic ? "تاريخ الرصيد -" : "Balance History -"} $supplierName',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // Actions bar
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: Text(isArabic ? 'طباعة كشف حساب (PDF)' : 'Print Statement (PDF)'),
                    onPressed: () async {
                      final records = await widget.supplierSyncService.getSupplierBalanceHistoryStream(supplierId).first;
                      if (!context.mounted) return;
                      await SupplierStatementPdfService.printOrShareSupplierStatement(
                        supplierData: widget.supplierData,
                        records: records,
                        locale: isArabic ? 'ar' : 'en',
                      );
                    },
                  ),
                  const Spacer(),
                  Text(
                    '${isArabic ? "مستحق للمورد: " : "Credit Due: "}\$${((widget.supplierData['totalBalance'] ?? widget.supplierData['balance'] ?? 0.0) as num).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentColor, fontSize: 16),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // History Table with BOTH Vertical & Horizontal Visible Scrollbars
              Expanded(
                child: StreamBuilder<List<SupplierBalanceRecord>>(
                  stream: widget.supplierSyncService.getSupplierBalanceHistoryStream(supplierId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final records = snapshot.data ?? [];
                    if (records.isEmpty) {
                      return Center(
                        child: Text(isArabic ? 'لا توجد حركات رصيد سابقة للمورد' : 'No balance history recorded'),
                      );
                    }

                    return Scrollbar(
                      controller: _verticalController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      child: SingleChildScrollView(
                        controller: _verticalController,
                        scrollDirection: Axis.vertical,
                        child: Scrollbar(
                          controller: _horizontalController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          notificationPredicate: (notif) => notif.depth == 1,
                          child: SingleChildScrollView(
                            controller: _horizontalController,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 720),
                              child: DataTable(
                                columns: [
                                  DataColumn(label: Text(isArabic ? 'التاريخ' : 'Date')),
                                  DataColumn(label: Text(isArabic ? 'نوع الحركة' : 'Type')),
                                  DataColumn(label: Text(isArabic ? 'رقم الفاتورة' : 'Invoice #')),
                                  DataColumn(label: Text(isArabic ? 'المبلغ' : 'Amount')),
                                  DataColumn(label: Text(isArabic ? 'الرصيد المتبقي' : 'Balance After')),
                                ],
                                rows: records.map((rec) {
                                  final isOpening = rec.type == 'opening';
                                  return DataRow(
                                    color: isOpening
                                        ? WidgetStateProperty.all(AppTheme.accentColor.withValues(alpha: 0.08))
                                        : null,
                                    cells: [
                                      DataCell(Text(DateFormat('yyyy/MM/dd HH:mm').format(rec.timestamp))),
                                      DataCell(
                                        Chip(
                                          label: Text(
                                            _getTypeLabel(rec.type, isArabic),
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          backgroundColor: _getTypeColor(rec.type).withValues(alpha: 0.2),
                                        ),
                                      ),
                                      DataCell(Text(rec.invoiceNumber.isEmpty ? '-' : rec.invoiceNumber)),
                                      DataCell(Text('\$${rec.amount.toStringAsFixed(2)}')),
                                      DataCell(
                                        Text(
                                          '\$${rec.balanceAfter.toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
