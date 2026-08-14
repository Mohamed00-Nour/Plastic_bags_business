import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supplier_invoice_balance_sync_service.dart';
import '../services/supplier_statement_pdf_service.dart';
import '../core/theme/app_theme.dart';

class BuyingInvoicePage extends StatefulWidget {
  const BuyingInvoicePage({super.key});

  @override
  State<BuyingInvoicePage> createState() => _BuyingInvoicePageState();
}

class _BuyingInvoicePageState extends State<BuyingInvoicePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupplierInvoiceBalanceSyncService _syncService = SupplierInvoiceBalanceSyncService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // New Invoice State
  late String _invoiceNumber;
  DateTime _selectedDate = DateTime.now();
  String? _selectedSupplierId;
  String? _selectedSupplierName;
  String? _selectedSupplierPhone;
  String _paymentMethod = 'Cash';

  final List<Map<String, dynamic>> _lineItems = [];
  double _discount = 0.0;
  double _paidAmount = 0.0;
  String _notes = '';
  bool _isSubmitting = false;

  final TextEditingController _discountController = TextEditingController(text: '0.0');
  final TextEditingController _paidController = TextEditingController(text: '0.0');
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _productSearchController = TextEditingController();
  String _productSearchQuery = '';

  int _selectedHistoryYear = DateTime.now().year;
  int _selectedHistoryMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _generateInvoiceNumber();
  }

  void _generateInvoiceNumber() {
    _invoiceNumber = 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _discountController.dispose();
    _paidController.dispose();
    _notesController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _lineItems.fold(0.0, (acc, item) {
      final qty = (item['quantity'] ?? 0) as num;
      final cost = (item['costPrice'] ?? item['price'] ?? 0.0) as num;
      return acc + (qty * cost);
    });
  }

  double get _totalAmount {
    final t = _subtotal - _discount;
    return t < 0 ? 0.0 : t;
  }

  double get _remainingAmount {
    final rem = _totalAmount - _paidAmount;
    return rem < 0 ? 0.0 : rem;
  }

  void _addLineItem(Map<String, dynamic> product) {
    setState(() {
      final existingIndex = _lineItems.indexWhere((i) => i['productId'] == product['id']);
      final cost = (product['costPrice'] ?? product['price'] ?? 0.0).toDouble();

      if (existingIndex >= 0) {
        _lineItems[existingIndex]['quantity'] += 1;
        _lineItems[existingIndex]['total'] =
            _lineItems[existingIndex]['quantity'] * _lineItems[existingIndex]['costPrice'];
      } else {
        _lineItems.add({
          'productId': product['id'],
          'productName': product['name'] ?? '',
          'quantity': 1,
          'costPrice': cost,
          'price': cost,
          'total': cost,
        });
      }
    });
  }

  void _submitInvoice(bool isArabic) async {
    if (_selectedSupplierId == null || _selectedSupplierId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'برجاء اختيار المورد أولاً' : 'Please select a supplier first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'برجاء إضافة منتج واحد على الأقل' : 'Please add at least one product line item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _syncService.createBuyingInvoice(
        supplierId: _selectedSupplierId!,
        supplierName: _selectedSupplierName ?? '',
        invoiceNumber: _invoiceNumber,
        paymentMethod: _paymentMethod,
        items: _lineItems,
        subtotal: _subtotal,
        discount: _discount,
        totalAmount: _totalAmount,
        paidAmount: _paidAmount,
        remainingAmount: _remainingAmount,
        invoiceDate: _selectedDate,
        notes: _notes,
      );

      if (!mounted) return;

      final invoiceDataToPrint = {
        'invoiceNumber': _invoiceNumber,
        'supplierName': _selectedSupplierName,
        'supplierPhone': _selectedSupplierPhone,
        'phone': _selectedSupplierPhone,
        'paymentMethod': _paymentMethod,
        'date': _selectedDate,
        'items': List<Map<String, dynamic>>.from(_lineItems),
        'subtotal': _subtotal,
        'discount': _discount,
        'totalAmount': _totalAmount,
        'paidAmount': _paidAmount,
        'remainingAmount': _remainingAmount,
      };

      setState(() {
        _isSubmitting = false;
        _lineItems.clear();
        _discount = 0.0;
        _paidAmount = 0.0;
        _discountController.text = '0.0';
        _paidController.text = '0.0';
        _notesController.clear();
        _productSearchController.clear();
        _productSearchQuery = '';
        _generateInvoiceNumber();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'تم حفظ فاتورة الشراء وزيادة المخزون وتحديث رصيد المورد بنجاح' : 'Buying invoice saved & stock updated!'),
          backgroundColor: AppTheme.successColor,
        ),
      );

      // Offer PDF Actions Dialog (WhatsApp, Print, Display, Save to device)
      await SupplierStatementPdfService.showBuyingInvoiceActionDialog(
        context: context,
        invoiceData: invoiceDataToPrint,
        locale: isArabic ? 'ar' : 'en',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving invoice: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showPurchaseReturnDialog(BuildContext context, bool isArabic) {
    final returnNumController = TextEditingController(text: 'PRET-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}');
    final origInvoiceController = TextEditingController();
    final reasonController = TextEditingController();
    final returnAmountController = TextEditingController();

    String? returnSupplierId;
    String? returnSupplierName;
    List<Map<String, dynamic>> returnItems = [];
    bool isSaving = false;

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
                    const Icon(Icons.assignment_return_rounded, color: AppTheme.warningColor),
                    const SizedBox(width: 8),
                    Text(isArabic ? 'إنشاء مرتجع مشتريات' : 'Create Purchase Return'),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _syncService.getSuppliersStream(),
                        builder: (context, snapshot) {
                          final suppliers = snapshot.data ?? [];
                          return RawAutocomplete<Map<String, dynamic>>(
                            displayStringForOption: (s) => s['name'] ?? '',
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) return suppliers;
                              final q = textEditingValue.text.toLowerCase();
                              return suppliers.where((s) {
                                final name = (s['name'] ?? '').toString().toLowerCase();
                                final phone = (s['phone'] ?? '').toString().toLowerCase();
                                return name.contains(q) || phone.contains(q);
                              });
                            },
                            onSelected: (Map<String, dynamic> s) {
                              setDialogState(() {
                                returnSupplierId = s['id'];
                                returnSupplierName = s['name'];
                              });
                            },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: isArabic ? 'ابحث عن المورد *' : 'Search & Select Supplier *',
                                  prefixIcon: const Icon(Icons.business),
                                ),
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 8,
                                  child: Container(
                                    width: 320,
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    color: Theme.of(context).cardColor,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (context, index) {
                                        final opt = options.elementAt(index);
                                        return ListTile(
                                          title: Text(opt['name'] ?? ''),
                                          subtitle: Text(opt['phone'] ?? ''),
                                          onTap: () => onSelected(opt),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: origInvoiceController,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'رقم فاتورة الشراء الأصلية' : 'Original Purchase Invoice #',
                          prefixIcon: const Icon(Icons.receipt),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: returnAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: isArabic ? 'إجمالي قيمة المرتجع (\$)' : 'Return Total Amount (\$)',
                          prefixIcon: const Icon(Icons.attach_money),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonController,
                        decoration: InputDecoration(
                          labelText: isArabic ? 'سبب الإرجاع للمورد' : 'Return Reason',
                          prefixIcon: const Icon(Icons.notes),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (returnSupplierId == null || returnAmountController.text.isEmpty) return;

                            setDialogState(() => isSaving = true);
                            try {
                              final amount = double.tryParse(returnAmountController.text.trim()) ?? 0.0;

                              await _syncService.processPurchaseReturn(
                                supplierId: returnSupplierId!,
                                supplierName: returnSupplierName ?? '',
                                originalInvoiceId: '',
                                originalInvoiceNumber: origInvoiceController.text.trim(),
                                returnNumber: returnNumController.text.trim(),
                                returnedItems: returnItems,
                                returnTotalAmount: amount,
                                reason: reasonController.text.trim(),
                              );

                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isArabic
                                        ? 'تم خصم المرتجع من المخزون وتخفيض دائنية المورد بنجاح'
                                        : 'Purchase return processed & supplier credit updated!',
                                  ),
                                  backgroundColor: AppTheme.successColor,
                                ),
                              );
                            } catch (e) {
                              setDialogState(() => isSaving = false);
                              if (!dialogContext.mounted) return;
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isArabic ? 'معالجة المرتجع' : 'Process Return'),
                  ),
                ],
              ),
            );
          },
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
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(icon: const Icon(Icons.add_business), text: isArabic ? 'فاتورة شراء جديدة' : 'New Buying Invoice'),
              Tab(icon: const Icon(Icons.assignment_return), text: isArabic ? 'إرجاع مشتريات' : 'Purchase Return'),
              Tab(icon: const Icon(Icons.receipt_long), text: isArabic ? 'سجل فواتير الشراء' : 'Buying Invoices History'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: New Buying Invoice Builder
            _buildInvoiceBuilderTab(context, isArabic),

            // Tab 2: Purchase Returns View
            _buildReturnsTab(context, isArabic),

            // Tab 3: Buying Invoices History List
            _buildInvoicesHistoryTab(context, isArabic),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceBuilderTab(BuildContext context, bool isArabic) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        final itemsSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Card (Invoice Number & Date & Searchable Supplier)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          '${isArabic ? "رقم فاتورة الشراء: " : "Buying Invoice #: "}$_invoiceNumber',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(DateFormat('yyyy/MM/dd').format(_selectedDate)),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setState(() => _selectedDate = d);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Searchable Supplier Autocomplete Selection
                        Expanded(
                          child: StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _syncService.getSuppliersStream(),
                            builder: (context, snapshot) {
                              final suppliers = snapshot.data ?? [];

                              return RawAutocomplete<Map<String, dynamic>>(
                                displayStringForOption: (s) {
                                  final bal = ((s['totalBalance'] ?? s['balance'] ?? 0.0) as num).toDouble();
                                  final balStr = bal.toStringAsFixed(2);
                                  final prefixLabel = isArabic ? 'دائنية: ' : 'Credit: ';
                                  return '${s['name']} ($prefixLabel\$$balStr)';
                                },
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) return suppliers;
                                  final q = textEditingValue.text.toLowerCase();
                                  return suppliers.where((s) {
                                    final name = (s['name'] ?? '').toString().toLowerCase();
                                    final phone = (s['phone'] ?? '').toString().toLowerCase();
                                    return name.contains(q) || phone.contains(q);
                                  });
                                },
                                onSelected: (Map<String, dynamic> s) {
                                  setState(() {
                                    _selectedSupplierId = s['id'];
                                    _selectedSupplierName = s['name'];
                                    _selectedSupplierPhone = s['phone'];
                                  });
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  if (_selectedSupplierName != null && controller.text.isEmpty) {
                                    controller.text = _selectedSupplierName!;
                                  }
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText: isArabic ? 'ابحث عن المورد واختاره *' : 'Search & Select Supplier *',
                                      prefixIcon: const Icon(Icons.business_center_rounded),
                                      suffixIcon: _selectedSupplierId != null
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, color: Colors.grey),
                                              onPressed: () {
                                                controller.clear();
                                                setState(() {
                                                  _selectedSupplierId = null;
                                                  _selectedSupplierName = null;
                                                  _selectedSupplierPhone = null;
                                                });
                                              },
                                            )
                                          : null,
                                    ),
                                  );
                                },
                                optionsViewBuilder: (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 8,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 380,
                                        constraints: const BoxConstraints(maxHeight: 240),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Theme.of(context).dividerColor),
                                        ),
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          itemCount: options.length,
                                          itemBuilder: (context, index) {
                                            final option = options.elementAt(index);
                                            final bal = ((option['totalBalance'] ?? option['balance'] ?? 0.0) as num).toDouble();
                                            final balStr = bal.toStringAsFixed(2);
                                            final prefixLabel = isArabic ? 'الدائنية: ' : 'Credit: ';
                                            return ListTile(
                                              leading: const Icon(Icons.business, color: AppTheme.accentColor),
                                              title: Text(option['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                              subtitle: Text('${option['phone'] ?? ''} • $prefixLabel\$$balStr'),
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: _paymentMethod,
                          items: ['Cash', 'Credit', 'Card', 'Check'].map((m) {
                            return DropdownMenuItem(value: m, child: Text(m));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _paymentMethod = val);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Searchable Products Picker Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isArabic ? 'إضافة منتجات مستلمة للمخزن' : 'Add Received Products to Stock', style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          isArabic ? 'اكتب اسم المنتج أو اضغط عليه للإضافة' : 'Type product name or tap chip to add',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search Input for Products
                    TextField(
                      controller: _productSearchController,
                      onChanged: (val) => setState(() => _productSearchQuery = val.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: isArabic ? 'بحث سريع عن منتج بالاسم أو المقاس...' : 'Quick search product by name or size...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _productSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _productSearchController.clear();
                                  setState(() => _productSearchQuery = '');
                                },
                              )
                            : null,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Filtered Products Stream (Increments Stock Inflow)
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('products').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const CircularProgressIndicator();
                        final docs = snapshot.data!.docs;

                        final filteredDocs = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          if (_productSearchQuery.isEmpty) return true;
                          final name = (data['name'] ?? '').toString().toLowerCase();
                          final size = (data['size'] ?? '').toString().toLowerCase();
                          return name.contains(_productSearchQuery) || size.contains(_productSearchQuery);
                        }).take(10).toList();

                        if (filteredDocs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              isArabic ? 'لا توجد منتجات مطابقة لنتيجة البحث' : 'No matching products found',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: filteredDocs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            data['id'] = doc.id;
                            final stock = data['stockQuantity'] ?? 0;
                            final cost = (data['costPrice'] ?? data['price'] ?? 0.0).toDouble();

                            return ActionChip(
                              avatar: const Icon(Icons.add, size: 16),
                              label: Text('${data['name']} (Cost: \$$cost) [Stock: $stock]'),
                              onPressed: () => _addLineItem(data),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Line Items Table
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isArabic ? 'بنود الشراء المستلمة' : 'Purchase Received Items', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _lineItems.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(child: Text(isArabic ? 'لم يتم إضافة أصناف للشراء بعد' : 'No purchase items added yet')),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _lineItems.length,
                            itemBuilder: (context, index) {
                              final item = _lineItems[index];
                              return ListTile(
                                title: Text(item['productName']),
                                subtitle: Text('Unit Cost: \$${item['costPrice']} x ${item['quantity']} = Total: \$${item['total']}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: () {
                                        setState(() {
                                          if (item['quantity'] > 1) {
                                            item['quantity'] -= 1;
                                            item['total'] = item['quantity'] * item['costPrice'];
                                          } else {
                                            _lineItems.removeAt(index);
                                          }
                                        });
                                      },
                                    ),
                                    SizedBox(
                                      width: 70,
                                      height: 38,
                                      child: TextFormField(
                                        key: ValueKey('qty_${item['productId']}_${item['quantity']}'),
                                        initialValue: '${item['quantity']}',
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          isDense: true,
                                        ),
                                        onChanged: (val) {
                                          final newQty = int.tryParse(val.trim());
                                          if (newQty != null && newQty > 0) {
                                            setState(() {
                                              item['quantity'] = newQty;
                                              item['total'] = item['quantity'] * item['costPrice'];
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: () {
                                        setState(() {
                                          item['quantity'] += 1;
                                          item['total'] = item['quantity'] * item['costPrice'];
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        setState(() => _lineItems.removeAt(index));
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
          ],
        );

        final summarySection = Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isArabic ? 'ملخص فاتورة الشراء' : 'Buying Summary', style: Theme.of(context).textTheme.titleLarge),
                const Divider(),
                const SizedBox(height: 12),
                _buildCalcRow(isArabic ? 'المجموع الفرعي' : 'Subtotal', '\$${_subtotal.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                TextField(
                  controller: _discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: isArabic ? 'خصم المورد (\$)' : 'Supplier Discount (\$)',
                    prefixIcon: const Icon(Icons.discount),
                  ),
                  onChanged: (val) {
                    setState(() => _discount = double.tryParse(val) ?? 0.0);
                  },
                ),
                const SizedBox(height: 12),
                _buildCalcRow(
                  isArabic ? 'الإجمالي النهائـي' : 'Total Amount',
                  '\$${_totalAmount.toStringAsFixed(2)}',
                  isBold: true,
                  color: AppTheme.accentColor,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _paidController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: isArabic ? 'المبلغ المدفوع للمورد (\$)' : 'Paid Amount (\$)',
                    prefixIcon: const Icon(Icons.money),
                  ),
                  onChanged: (val) {
                    setState(() => _paidAmount = double.tryParse(val) ?? 0.0);
                  },
                ),
                const SizedBox(height: 12),
                _buildCalcRow(
                  isArabic ? 'المتبقي للمورد (يزيد دائنية المورد)' : 'Remaining Due to Supplier',
                  '\$${_remainingAmount.toStringAsFixed(2)}',
                  isBold: true,
                  color: _remainingAmount > 0 ? AppTheme.warningColor : AppTheme.successColor,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'ملاحظات وتفاصيل الشراء' : 'Notes',
                    prefixIcon: const Icon(Icons.note),
                  ),
                  onChanged: (val) => _notes = val,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.inventory_rounded),
                    label: Text(isArabic ? 'تأكيد الشراء وإدخال للمخزن (PDF)' : 'Confirm Buying & Restock (PDF)'),
                    onPressed: _isSubmitting ? null : () => _submitInvoice(isArabic),
                  ),
                ),
              ],
            ),
          ),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: itemsSection),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: summarySection),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    itemsSection,
                    const SizedBox(height: 16),
                    summarySection,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildReturnsTab(BuildContext context, bool isArabic) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_return_rounded, size: 72, color: AppTheme.warningColor),
            const SizedBox(height: 16),
            Text(
              isArabic ? 'إدارة مرتجعات المشتريات للموردين' : 'Purchase Returns Management',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              isArabic ? 'إعادة البضاعة للمورد، خصم الكمية من المخزن، وتخفيض دائنية المورد' : 'Return goods to supplier, deduct from inventory & update supplier balance',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(isArabic ? 'إنشاء إرجاع مشتريات جديد' : 'New Purchase Return Request'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor),
              onPressed: () => _showPurchaseReturnDialog(context, isArabic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesHistoryTab(BuildContext context, bool isArabic) {
    Query query = _firestore.collection('buying_invoices');

    if (_selectedHistoryYear > 0 && _selectedHistoryMonth > 0) {
      final start = DateTime(_selectedHistoryYear, _selectedHistoryMonth, 1);
      final end = DateTime(_selectedHistoryYear, _selectedHistoryMonth + 1, 1);
      query = query
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .orderBy('createdAt', descending: true);
    } else if (_selectedHistoryYear > 0) {
      final start = DateTime(_selectedHistoryYear, 1, 1);
      final end = DateTime(_selectedHistoryYear + 1, 1, 1);
      query = query
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .orderBy('createdAt', descending: true);
    } else {
      query = query.orderBy('createdAt', descending: true).limit(50);
    }

    return Column(
      children: [
        // Month & Year Filter Card (Firebase Quota Saver)
        Card(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.filter_alt_rounded, color: AppTheme.accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'تصفية فواتير الشراء بالفترة' : 'Buying Invoice Date Filter',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isArabic ? 'ترشيد استهلاك قراءة الفايربيس (Firebase Quota Saver)' : 'Optimizes Firebase database reads quota',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                // Month Selector Dropdown
                DropdownButton<int>(
                  value: _selectedHistoryMonth,
                  style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color),
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(isArabic ? 'كل الشهور' : 'All Months'),
                    ),
                    ...List.generate(12, (index) {
                      final m = index + 1;
                      final monthName = DateFormat.MMMM(isArabic ? 'ar' : 'en').format(DateTime(2026, m));
                      return DropdownMenuItem(value: m, child: Text(monthName));
                    }),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedHistoryMonth = val);
                  },
                ),
                const SizedBox(width: 12),

                // Year Selector Dropdown
                DropdownButton<int>(
                  value: _selectedHistoryYear,
                  style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color),
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(isArabic ? 'كل السنوات' : 'All Years'),
                    ),
                    ...List.generate(6, (index) {
                      final y = DateTime.now().year - 3 + index;
                      return DropdownMenuItem(value: y, child: Text('$y'));
                    }),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedHistoryYear = val);
                  },
                ),
              ],
            ),
          ),
        ),

        // History Stream List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
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
                      const Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        isArabic ? 'لا توجد فواتير شراء في هذه الفترة المحددة' : 'No buying invoices recorded for this selected period',
                        style: const TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final invNum = data['invoiceNumber'] ?? '';
                  final supplier = data['supplierName'] ?? '';
                  final total = (data['totalAmount'] ?? 0.0).toDouble();
                  final paid = (data['paidAmount'] ?? 0.0).toDouble();
                  final remaining = (data['remainingAmount'] ?? 0.0).toDouble();
                  final date = SupplierInvoiceBalanceSyncService.parseInvoiceDate(data['date'] ?? data['createdAt']);

                  final paidLabel = isArabic ? 'مدفوع: ' : 'Paid: ';
                  final remLabel = isArabic ? 'متبقي للمورد: ' : 'Due: ';
                  final subText = '$paidLabel\$${paid.toStringAsFixed(2)} | $remLabel\$${remaining.toStringAsFixed(2)}';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.accentColor,
                        child: Icon(Icons.local_shipping, color: Colors.white),
                      ),
                      title: Text('#$invNum - $supplier', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${DateFormat('yyyy/MM/dd HH:mm').format(date)} • Payment: ${data['paymentMethod']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(subText, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.print_rounded, color: AppTheme.accentColor),
                            onPressed: () {
                              SupplierStatementPdfService.showBuyingInvoiceActionDialog(
                                context: context,
                                invoiceData: data,
                                locale: isArabic ? 'ar' : 'en',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalcRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 16 : 14,
            color: color,
          ),
        ),
      ],
    );
  }
}
