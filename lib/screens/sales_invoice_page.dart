import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/products/bloc/product_bloc_new.dart';
import '../features/products/bloc/product_event.dart';
import '../services/client_invoice_balance_sync_service.dart';
import '../services/client_statement_pdf_service.dart';
import '../services/sales_invoice_actions_service.dart';
import '../services/sales_invoice_update_service.dart';
import '../core/theme/app_theme.dart';

class SalesInvoicePage extends StatefulWidget {
  final Map<String, dynamic>? initialInvoiceData;

  const SalesInvoicePage({super.key, this.initialInvoiceData});

  @override
  State<SalesInvoicePage> createState() => _SalesInvoicePageState();
}

class _SalesInvoicePageState extends State<SalesInvoicePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ClientInvoiceBalanceSyncService _syncService =
      ClientInvoiceBalanceSyncService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // New Invoice State
  late String _invoiceNumber;
  DateTime _selectedDate = DateTime.now();
  String? _selectedClientId;
  String? _selectedClientName;
  String? _selectedClientPhone;
  String _paymentMethod = 'Cash';

  final List<Map<String, dynamic>> _lineItems = [];
  double _discount = 0.0;
  double _paidAmount = 0.0;
  String _notes = '';
  bool _isSubmitting = false;

  final TextEditingController _discountController = TextEditingController(
    text: '0.0',
  );
  final TextEditingController _paidController = TextEditingController(
    text: '0.0',
  );
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _productSearchController =
      TextEditingController();
  String _productSearchQuery = '';

  // Return Invoice State
  late String _returnNumber;
  DateTime _returnDate = DateTime.now();
  String? _returnClientId;
  String? _returnClientName;
  String? _returnClientPhone;
  String _returnPaymentMethod = 'Cash';

  final List<Map<String, dynamic>> _returnLineItems = [];
  double _returnDiscount = 0.0;
  double _returnRefundAmount = 0.0;
  String _returnNotes = '';
  bool _isReturnSubmitting = false;

  final TextEditingController _returnDiscountController = TextEditingController(
    text: '0.0',
  );
  final TextEditingController _returnRefundController = TextEditingController(
    text: '0.0',
  );
  final TextEditingController _returnNotesController = TextEditingController();
  final TextEditingController _returnProductSearchController =
      TextEditingController();
  String _returnProductSearchQuery = '';

  int _selectedHistoryYear = DateTime.now().year;
  int _selectedHistoryMonth = DateTime.now().month;

  bool get _isEditMode => widget.initialInvoiceData != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _generateReturnNumber();
    if (widget.initialInvoiceData != null) {
      _loadInvoiceForEditing(widget.initialInvoiceData!);
    } else {
      _generateInvoiceNumber();
    }
  }

  void _loadInvoiceForEditing(Map<String, dynamic> inv) {
    _invoiceNumber = inv['invoiceNumber']?.toString() ?? 'INV-000';
    _selectedClientId = inv['clientId']?.toString();
    _selectedClientName = inv['clientName']?.toString();
    _selectedClientPhone =
        inv['clientPhone']?.toString() ?? inv['phone']?.toString();
    _paymentMethod = inv['paymentMethod']?.toString() ?? 'Cash';
    _discount = (inv['discount'] ?? 0.0).toDouble();
    _paidAmount = (inv['paidAmount'] ?? 0.0).toDouble();
    _notes = inv['notes']?.toString() ?? '';

    _discountController.text = _discount.toStringAsFixed(2);
    _paidController.text = _paidAmount.toStringAsFixed(2);
    _notesController.text = _notes;

    final rawDate = inv['createdAt'] ?? inv['date'];
    if (rawDate is Timestamp) {
      _selectedDate = rawDate.toDate();
    } else if (rawDate is DateTime) {
      _selectedDate = rawDate;
    }

    _lineItems.clear();
    final items = (inv['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    for (final item in items) {
      _lineItems.add(Map<String, dynamic>.from(item));
    }
  }

  void _generateInvoiceNumber() {
    _invoiceNumber =
        'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
  }

  void _generateReturnNumber() {
    _returnNumber =
        'RET-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _discountController.dispose();
    _paidController.dispose();
    _notesController.dispose();
    _productSearchController.dispose();
    _returnDiscountController.dispose();
    _returnRefundController.dispose();
    _returnNotesController.dispose();
    _returnProductSearchController.dispose();
    super.dispose();
  }

  double get _returnSubtotal {
    return _returnLineItems.fold(0.0, (acc, item) {
      final qty = (item['quantity'] ?? 0) as num;
      final price = (item['price'] ?? 0.0) as num;
      return acc + (qty * price);
    });
  }

  double get _returnTotalAmount {
    final t = _returnSubtotal - _returnDiscount;
    return t < 0 ? 0.0 : t;
  }

  double get _returnRemainingAmount {
    final rem = _returnTotalAmount - _returnRefundAmount;
    return rem < 0 ? 0.0 : rem;
  }

  void _addReturnLineItem(Map<String, dynamic> product) {
    setState(() {
      final existingIndex = _returnLineItems.indexWhere(
        (i) => i['productId'] == product['id'],
      );
      final p1 = (product['price1'] ?? product['price'] ?? 0.0).toDouble();
      final p2 =
          product['price2'] != null
              ? (product['price2'] as num).toDouble()
              : null;
      final p3 =
          product['price3'] != null
              ? (product['price3'] as num).toDouble()
              : null;

      if (existingIndex >= 0) {
        _returnLineItems[existingIndex]['quantity'] += 1;
        _returnLineItems[existingIndex]['total'] =
            _returnLineItems[existingIndex]['quantity'] *
            _returnLineItems[existingIndex]['price'];
      } else {
        _returnLineItems.add({
          'productId': product['id'],
          'productName': product['name'] ?? '',
          'quantity': 1,
          'price1': p1,
          'price2': p2,
          'price3': p3,
          'selectedTier': 'price1',
          'price': p1,
          'total': p1,
        });
      }
    });
  }

  double get _subtotal {
    return _lineItems.fold(0.0, (acc, item) {
      final qty = (item['quantity'] ?? 0) as num;
      final price = (item['price'] ?? 0.0) as num;
      return acc + (qty * price);
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
    final stockInDb = (product['stockQuantity'] ?? 0) as int;
    final existingIndex = _lineItems.indexWhere(
      (i) => i['productId'] == product['id'],
    );

    if (existingIndex >= 0) {
      final currentQty = (_lineItems[existingIndex]['quantity'] as num).toInt();
      if (stockInDb > 0 && currentQty >= stockInDb) return;
    } else {
      if (stockInDb <= 0) return;
    }

    setState(() {
      final p1 = (product['price1'] ?? product['price'] ?? 0.0).toDouble();
      final p2 =
          product['price2'] != null
              ? (product['price2'] as num).toDouble()
              : null;
      final p3 =
          product['price3'] != null
              ? (product['price3'] as num).toDouble()
              : null;

      if (existingIndex >= 0) {
        _lineItems[existingIndex]['quantity'] += 1;
        _lineItems[existingIndex]['total'] =
            _lineItems[existingIndex]['quantity'] *
            _lineItems[existingIndex]['price'];
      } else {
        _lineItems.add({
          'productId': product['id'],
          'productName': product['name'] ?? '',
          'stockQuantity': stockInDb,
          'quantity': 1,
          'price1': p1,
          'price2': p2,
          'price3': p3,
          'selectedTier': 'price1',
          'price': p1,
          'total': p1,
        });
      }
    });
  }

  void _submitInvoice(bool isArabic) async {
    if (_selectedClientId == null || _selectedClientId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'برجاء اختيار العميل أولاً'
                : 'Please select a customer first',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'برجاء إضافة منتج واحد على الأقل'
                : 'Please add at least one product line item',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    if (_isEditMode) {
      final newInvoiceData = {
        'id':
            widget.initialInvoiceData!['id'] ??
            widget.initialInvoiceData!['invoiceId'],
        'invoiceNumber': _invoiceNumber,
        'clientId': _selectedClientId,
        'clientName': _selectedClientName,
        'clientPhone': _selectedClientPhone,
        'paymentMethod': _paymentMethod,
        'date': _selectedDate,
        'items': List<Map<String, dynamic>>.from(_lineItems),
        'subtotal': _subtotal,
        'discount': _discount,
        'totalAmount': _totalAmount,
        'paidAmount': _paidAmount,
        'remainingAmount': _remainingAmount,
        'notes': _notes,
      };

      final success = await SalesInvoiceUpdateService.updateSalesInvoice(
        context: context,
        oldInvoice: widget.initialInvoiceData!,
        newInvoice: newInvoiceData,
      );

      setState(() => _isSubmitting = false);

      if (success && mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    try {
      await _syncService.createSalesInvoice(
        clientId: _selectedClientId!,
        clientName: _selectedClientName ?? '',
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
        'clientName': _selectedClientName,
        'clientPhone': _selectedClientPhone,
        'phone': _selectedClientPhone,
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

      try {
        context.read<ProductBloc>().add(ProductLoadRequested());
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم حفظ فاتورة المبيعات وتحديث المخزون والرصيد بنجاح'
                : 'Sales invoice saved successfully!',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );

      // Offer PDF Actions Dialog (WhatsApp, Print, Display, Save to device)
      await ClientStatementPdfService.showSalesInvoiceActionDialog(
        context: context,
        invoiceData: invoiceDataToPrint,
        locale: isArabic ? 'ar' : 'en',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving invoice: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _submitSalesReturn(bool isArabic) async {
    if (_returnClientId == null || _returnClientId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'برجاء اختيار العميل أولاً'
                : 'Please select a customer first',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_returnLineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'برجاء إضافة منتج واحد على الأقل للمرتجع'
                : 'Please add at least one item to return',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isReturnSubmitting = true);

    try {
      await _syncService.processSalesReturn(
        clientId: _returnClientId!,
        clientName: _returnClientName ?? '',
        returnNumber: _returnNumber,
        returnedItems: _returnLineItems,
        subtotal: _returnSubtotal,
        discount: _returnDiscount,
        returnTotalAmount: _returnTotalAmount,
        refundAmount: _returnRefundAmount,
        returnDate: _returnDate,
        reason: _returnNotes,
      );

      if (!mounted) return;

      final returnDataToPrint = {
        'invoiceNumber': _returnNumber,
        'returnNumber': _returnNumber,
        'clientName': _returnClientName,
        'clientPhone': _returnClientPhone,
        'phone': _returnClientPhone,
        'paymentMethod': _returnPaymentMethod,
        'date': _returnDate,
        'items': List<Map<String, dynamic>>.from(_returnLineItems),
        'subtotal': _returnSubtotal,
        'discount': _returnDiscount,
        'totalAmount': _returnTotalAmount,
        'paidAmount': _returnRefundAmount,
        'remainingAmount': _returnRemainingAmount,
        'isReturn': true,
      };

      setState(() {
        _isReturnSubmitting = false;
        _returnLineItems.clear();
        _returnDiscount = 0.0;
        _returnRefundAmount = 0.0;
        _returnDiscountController.text = '0.0';
        _returnRefundController.text = '0.0';
        _returnNotesController.clear();
        _returnProductSearchController.clear();
        _returnProductSearchQuery = '';
        _generateReturnNumber();
      });

      try {
        context.read<ProductBloc>().add(ProductLoadRequested());
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم حفظ مرتجع المبيعات وتحديث المخزون والرصيد بنجاح'
                : 'Sales return saved successfully!',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );

      // Offer PDF Actions Dialog (WhatsApp, Print, Display, Save to device)
      await ClientStatementPdfService.showSalesInvoiceActionDialog(
        context: context,
        invoiceData: returnDataToPrint,
        locale: isArabic ? 'ar' : 'en',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isReturnSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving return: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditMode
                ? (isArabic
                    ? 'تعديل فاتورة مبيعات #$_invoiceNumber'
                    : 'Edit Sales Invoice #$_invoiceNumber')
                : (isArabic
                    ? 'إدارة فواتير المبيعات'
                    : 'Sales Invoices Management'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          leading:
              Navigator.canPop(context)
                  ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: isArabic ? 'رجوع' : 'Back',
                    onPressed: () => Navigator.maybePop(context),
                  )
                  : null,
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                icon: const Icon(Icons.point_of_sale),
                text:
                    _isEditMode
                        ? (isArabic ? 'تعديل الفاتورة' : 'Edit Invoice')
                        : (isArabic
                            ? 'فاتورة مبيعات جديدة'
                            : 'New Sales Invoice'),
              ),
              Tab(
                icon: const Icon(Icons.assignment_return),
                text: isArabic ? 'إرجاع مبيعات' : 'Sales Return',
              ),
              Tab(
                icon: const Icon(Icons.receipt_long),
                text: isArabic ? 'سجل الفواتير' : 'Invoices History',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: New Sales Invoice Builder
            _buildInvoiceBuilderTab(context, isArabic),

            // Tab 2: Sales Returns Direct View
            _buildReturnsTab(context, isArabic),

            // Tab 3: Sales Invoices History List
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
            // Top Header Card (Invoice Number & Date & Searchable Client)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          '${isArabic ? "رقم الفاتورة: " : "Invoice #: "}$_invoiceNumber',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            DateFormat('yyyy/MM/dd').format(_selectedDate),
                          ),
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
                        // Searchable Client Autocomplete Selection
                        Expanded(
                          child: StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _syncService.getClientsStream(),
                            builder: (context, snapshot) {
                              final clients = snapshot.data ?? [];

                              return RawAutocomplete<Map<String, dynamic>>(
                                displayStringForOption: (c) {
                                  final balStr = (c['balance'] ?? 0.0)
                                      .toStringAsFixed(2);
                                  final prefixLabel =
                                      isArabic ? 'رصيد: ' : 'Bal: ';
                                  return '${c['name']} ($prefixLabel\$$balStr)';
                                },
                                optionsBuilder: (
                                  TextEditingValue textEditingValue,
                                ) {
                                  if (textEditingValue.text.isEmpty) {
                                    return clients;
                                  }
                                  final q = textEditingValue.text.toLowerCase();
                                  return clients.where((c) {
                                    final name =
                                        (c['name'] ?? '')
                                            .toString()
                                            .toLowerCase();
                                    final phone =
                                        (c['phone'] ?? '')
                                            .toString()
                                            .toLowerCase();
                                    return name.contains(q) ||
                                        phone.contains(q);
                                  });
                                },
                                onSelected: (Map<String, dynamic> c) {
                                  setState(() {
                                    _selectedClientId = c['id'];
                                    _selectedClientName = c['name'];
                                    _selectedClientPhone = c['phone'];
                                  });
                                },
                                fieldViewBuilder: (
                                  context,
                                  controller,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  if (_selectedClientName != null &&
                                      controller.text.isEmpty) {
                                    controller.text = _selectedClientName!;
                                  }
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText:
                                          isArabic
                                              ? 'ابحث عن العميل واختاره *'
                                              : 'Search & Select Client *',
                                      prefixIcon: const Icon(
                                        Icons.person_search_rounded,
                                      ),
                                      suffixIcon:
                                          _selectedClientId != null
                                              ? IconButton(
                                                icon: const Icon(
                                                  Icons.clear,
                                                  color: Colors.grey,
                                                ),
                                                onPressed: () {
                                                  controller.clear();
                                                  setState(() {
                                                    _selectedClientId = null;
                                                    _selectedClientName = null;
                                                    _selectedClientPhone = null;
                                                  });
                                                },
                                              )
                                              : null,
                                    ),
                                  );
                                },
                                optionsViewBuilder: (
                                  context,
                                  onSelected,
                                  options,
                                ) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 8,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 380,
                                        constraints: const BoxConstraints(
                                          maxHeight: 240,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color:
                                                Theme.of(context).dividerColor,
                                          ),
                                        ),
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          itemCount: options.length,
                                          itemBuilder: (context, index) {
                                            final option = options.elementAt(
                                              index,
                                            );
                                            final balStr = (option['balance'] ??
                                                    0.0)
                                                .toStringAsFixed(2);
                                            final prefixLabel =
                                                isArabic ? 'الرصيد: ' : 'Bal: ';
                                            return ListTile(
                                              leading: const Icon(
                                                Icons.person,
                                                color: AppTheme.primaryColor,
                                              ),
                                              title: Text(
                                                option['name'] ?? '',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              subtitle: Text(
                                                '${option['phone'] ?? ''} • $prefixLabel\$$balStr',
                                              ),
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
                          items:
                              ['Cash', 'Credit', 'Card', 'Check'].map((m) {
                                return DropdownMenuItem(
                                  value: m,
                                  child: Text(m),
                                );
                              }).toList(),
                          onChanged: (val) {
                            if (val != null)
                              setState(() => _paymentMethod = val);
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
                        Text(
                          isArabic
                              ? 'إضافة منتجات للفاتورة'
                              : 'Add Products to Invoice',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          isArabic
                              ? 'اكتب اسم المنتج أو اضغط عليه للإضافة'
                              : 'Type product name or tap chip to add',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search Input for Products
                    TextField(
                      controller: _productSearchController,
                      onChanged:
                          (val) => setState(
                            () =>
                                _productSearchQuery = val.trim().toLowerCase(),
                          ),
                      decoration: InputDecoration(
                        hintText:
                            isArabic
                                ? 'بحث سريع عن منتج بالاسم أو المقاس...'
                                : 'Quick search product by name or size...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon:
                            _productSearchQuery.isNotEmpty
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

                    // Filtered Products Stream
                    StreamBuilder<QuerySnapshot>(
                      stream:
                          _firestore
                              .collection('products')
                              .where('isActive', isEqualTo: true)
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        final docs = snapshot.data!.docs;

                        final filteredDocs =
                            docs
                                .where((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  if (_productSearchQuery.isEmpty) return true;
                                  final name =
                                      (data['name'] ?? '')
                                          .toString()
                                          .toLowerCase();
                                  final size =
                                      (data['size'] ?? '')
                                          .toString()
                                          .toLowerCase();
                                  return name.contains(_productSearchQuery) ||
                                      size.contains(_productSearchQuery);
                                })
                                .take(10)
                                .toList();

                        if (filteredDocs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              isArabic
                                  ? 'لا توجد منتجات مطابقة لنتيجة البحث'
                                  : 'No matching products found',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              filteredDocs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                data['id'] = doc.id;
                                final stock =
                                    (data['stockQuantity'] ?? 0) as int;

                                final draftItem = _lineItems.firstWhere(
                                  (item) => item['productId'] == doc.id,
                                  orElse: () => {'quantity': 0},
                                );
                                final draftQty =
                                    (draftItem['quantity'] ?? 0) as int;
                                final availableStock = stock - draftQty;

                                return ActionChip(
                                  avatar: const Icon(
                                    Icons.add_shopping_cart,
                                    size: 16,
                                  ),
                                  label: Text(
                                    '${data['name']} (\$${data['price']}) [${isArabic ? "المتبقي" : "Stock"}: $availableStock]',
                                  ),
                                  onPressed:
                                      availableStock <= 0
                                          ? null
                                          : () => _addLineItem(data),
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
                    Text(
                      isArabic ? 'بنود الفاتورة' : 'Invoice Items',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _lineItems.isEmpty
                        ? Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              isArabic
                                  ? 'لم يتم إضافة منتجات بعد'
                                  : 'No items added yet',
                            ),
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _lineItems.length,
                          itemBuilder: (context, index) {
                            final item = _lineItems[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['productName'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '\$${(item['total'] as num).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      // Price Tier Selector
                                      Text(
                                        isArabic ? 'السعر: ' : 'Price: ',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      DropdownButton<String>(
                                        value: item['selectedTier'] ?? 'price1',
                                        isDense: true,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodyMedium?.color,
                                        ),
                                        items: [
                                          DropdownMenuItem(
                                            value: 'price1',
                                            child: Text(
                                              '${isArabic ? "سعر 1" : "Price 1"} (\$${((item['price1'] ?? item['price']) as num).toStringAsFixed(2)})',
                                            ),
                                          ),
                                          if (item['price2'] != null)
                                            DropdownMenuItem(
                                              value: 'price2',
                                              child: Text(
                                                '${isArabic ? "سعر 2" : "Price 2"} (\$${(item['price2'] as num).toStringAsFixed(2)})',
                                              ),
                                            ),
                                          if (item['price3'] != null)
                                            DropdownMenuItem(
                                              value: 'price3',
                                              child: Text(
                                                '${isArabic ? "سعر 3" : "Price 3"} (\$${(item['price3'] as num).toStringAsFixed(2)})',
                                              ),
                                            ),
                                          DropdownMenuItem(
                                            value: 'custom',
                                            child: Text(
                                              isArabic
                                                  ? 'سعر خاص ✏️'
                                                  : 'Custom Price ✏️',
                                            ),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          if (val == null) return;
                                          setState(() {
                                            item['selectedTier'] = val;
                                            if (val == 'price1') {
                                              item['price'] =
                                                  item['price1'] ??
                                                  item['price'];
                                            } else if (val == 'price2') {
                                              item['price'] = item['price2'];
                                            } else if (val == 'price3') {
                                              item['price'] = item['price3'];
                                            }
                                            item['total'] =
                                                (item['quantity'] as num) *
                                                (item['price'] as num);
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 8),

                                      // Editable Custom Price Input Field
                                      if (item['selectedTier'] == 'custom')
                                        SizedBox(
                                          width: 80,
                                          height: 34,
                                          child: TextFormField(
                                            key: ValueKey(
                                              'custom_price_${item['productId']}',
                                            ),
                                            initialValue: '${item['price']}',
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration: InputDecoration(
                                              prefixText: '\$',
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 2,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              isDense: true,
                                            ),
                                            onChanged: (val) {
                                              final p = double.tryParse(
                                                val.trim(),
                                              );
                                              if (p != null && p >= 0) {
                                                setState(() {
                                                  item['price'] = p;
                                                  item['total'] =
                                                      (item['quantity']
                                                          as num) *
                                                      (item['price'] as num);
                                                });
                                              }
                                            },
                                          ),
                                        ),

                                      const Spacer(),

                                      // Quantity Controls
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            if (item['quantity'] > 1) {
                                              item['quantity'] -= 1;
                                              item['total'] =
                                                  item['quantity'] *
                                                  item['price'];
                                            } else {
                                              _lineItems.removeAt(index);
                                            }
                                          });
                                        },
                                      ),
                                      SizedBox(
                                        width: 60,
                                        height: 34,
                                        child: TextFormField(
                                          key: ValueKey(
                                            'qty_${item['productId']}_${item['quantity']}',
                                          ),
                                          initialValue: '${item['quantity']}',
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 2,
                                                  vertical: 2,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            isDense: true,
                                          ),
                                          onChanged: (val) {
                                            final newQty = int.tryParse(
                                              val.trim(),
                                            );
                                            if (newQty != null && newQty > 0) {
                                              setState(() {
                                                item['quantity'] = newQty;
                                                item['total'] =
                                                    item['quantity'] *
                                                    item['price'];
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            item['quantity'] += 1;
                                            item['total'] =
                                                item['quantity'] *
                                                item['price'];
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          setState(
                                            () => _lineItems.removeAt(index),
                                          );
                                        },
                                      ),
                                    ],
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
                Text(
                  isArabic ? 'ملخص الفاتورة والحساب' : 'Invoice Summary',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Divider(),
                const SizedBox(height: 12),
                _buildCalcRow(
                  isArabic ? 'المجموع الفرعي' : 'Subtotal',
                  '\$${_subtotal.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _discountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: isArabic ? 'الخصم (\$)' : 'Discount (\$)',
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
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _paidController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        isArabic ? 'المبلغ المدفوع (\$)' : 'Paid Amount (\$)',
                    prefixIcon: const Icon(Icons.money),
                  ),
                  onChanged: (val) {
                    setState(() => _paidAmount = double.tryParse(val) ?? 0.0);
                  },
                ),
                const SizedBox(height: 12),
                _buildCalcRow(
                  isArabic
                      ? 'المتبقي (يضاف لرصيد العميل)'
                      : 'Remaining Balance',
                  '\$${_remainingAmount.toStringAsFixed(2)}',
                  isBold: true,
                  color:
                      _remainingAmount > 0
                          ? AppTheme.dangerColor
                          : AppTheme.successColor,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'ملاحظات الفاتورة' : 'Notes',
                    prefixIcon: const Icon(Icons.note),
                  ),
                  onChanged: (val) => _notes = val,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: Text(
                      isArabic
                          ? 'حفظ وحساب الفاتورة (PDF)'
                          : 'Save & Print Invoice (PDF)',
                    ),
                    onPressed:
                        _isSubmitting ? null : () => _submitInvoice(isArabic),
                  ),
                ),
              ],
            ),
          ),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child:
              isDesktop
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        final itemsSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Card (Return Number & Date & Searchable Client)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          '${isArabic ? "رقم المرتجع: " : "Return #: "}$_returnNumber',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.dangerColor,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(
                            Icons.calendar_today,
                            color: AppTheme.dangerColor,
                          ),
                          label: Text(
                            DateFormat('yyyy/MM/dd').format(_returnDate),
                            style: const TextStyle(color: AppTheme.dangerColor),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _returnDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setState(() => _returnDate = picked);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Searchable Client Auto-complete Input
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _syncService.getClientsStream(),
                      builder: (context, snapshot) {
                        final clients = snapshot.data ?? [];
                        return RawAutocomplete<Map<String, dynamic>>(
                          displayStringForOption: (c) => c['name'] ?? '',
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) return clients;
                            final q = textEditingValue.text.toLowerCase();
                            return clients.where((c) {
                              final name =
                                  (c['name'] ?? '').toString().toLowerCase();
                              final phone =
                                  (c['phone'] ?? '').toString().toLowerCase();
                              return name.contains(q) || phone.contains(q);
                            });
                          },
                          onSelected: (Map<String, dynamic> c) {
                            setState(() {
                              _returnClientId = c['id'];
                              _returnClientName = c['name'];
                              _returnClientPhone = c['phone'];
                            });
                          },
                          fieldViewBuilder: (
                            context,
                            controller,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            if (_returnClientName != null &&
                                controller.text.isEmpty) {
                              controller.text = _returnClientName!;
                            }
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText:
                                    isArabic
                                        ? 'ابحث عن العميل للمرتجع *'
                                        : 'Search Client for Return *',
                                prefixIcon: const Icon(
                                  Icons.person_search,
                                  color: AppTheme.dangerColor,
                                ),
                                suffixIcon:
                                    _returnClientId != null
                                        ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            controller.clear();
                                            setState(() {
                                              _returnClientId = null;
                                              _returnClientName = null;
                                              _returnClientPhone = null;
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
                                child: Container(
                                  width: 340,
                                  constraints: const BoxConstraints(
                                    maxHeight: 220,
                                  ),
                                  color: Theme.of(context).cardColor,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final option = options.elementAt(index);
                                      return ListTile(
                                        title: Text(
                                          option['name'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${option['phone'] ?? ''} • ${isArabic ? "رصيد: " : "Bal: "}\$${(option['balance'] ?? 0.0).toStringAsFixed(2)}',
                                        ),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Search Products Bar
            TextField(
              controller: _returnProductSearchController,
              decoration: InputDecoration(
                hintText:
                    isArabic
                        ? 'ابحث عن المنتج لإرجاعه (الاسم أو الباروكود)...'
                        : 'Search product to return...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppTheme.dangerColor,
                ),
                suffixIcon:
                    _returnProductSearchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _returnProductSearchController.clear();
                            setState(() => _returnProductSearchQuery = '');
                          },
                        )
                        : null,
              ),
              onChanged: (val) {
                setState(
                  () => _returnProductSearchQuery = val.trim().toLowerCase(),
                );
              },
            ),
            const SizedBox(height: 12),

            // Products Grid / List Selector for Returns
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                final filtered =
                    docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name =
                          (data['name'] ?? '').toString().toLowerCase();
                      final code =
                          (data['code'] ?? '').toString().toLowerCase();
                      return _returnProductSearchQuery.isEmpty ||
                          name.contains(_returnProductSearchQuery) ||
                          code.contains(_returnProductSearchQuery);
                    }).toList();

                if (filtered.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        isArabic
                            ? 'لا يوجد منتجات مطابقة'
                            : 'No matching products found',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final p = Map<String, dynamic>.from(doc.data() as Map);
                      p['id'] = doc.id;
                      final price =
                          (p['price1'] ?? p['price'] ?? 0.0).toDouble();

                      return Container(
                        width: 150,
                        margin: const EdgeInsets.only(right: 10),
                        child: Card(
                          child: InkWell(
                            onTap: () => _addReturnLineItem(p),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    p['name'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '\$${price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: AppTheme.dangerColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.add_circle,
                                        color: AppTheme.dangerColor,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Returned Line Items Table Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'الأصناف المرتجعة' : 'Returned Items',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Divider(),
                    if (_returnLineItems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            isArabic
                                ? 'اضغط على المنتجات أعلاه لإضافتها لقائمة المرتجع'
                                : 'Select products above to add to return list',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _returnLineItems.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = _returnLineItems[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['productName'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '\$${(item['total'] as num).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.dangerColor,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      isArabic
                                          ? 'سعر الإرجاع: '
                                          : 'Return Price: ',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    DropdownButton<String>(
                                      value: item['selectedTier'] ?? 'price1',
                                      isDense: true,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.color,
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: 'price1',
                                          child: Text(
                                            '${isArabic ? "سعر 1" : "Price 1"} (\$${((item['price1'] ?? item['price']) as num).toStringAsFixed(2)})',
                                          ),
                                        ),
                                        if (item['price2'] != null)
                                          DropdownMenuItem(
                                            value: 'price2',
                                            child: Text(
                                              '${isArabic ? "سعر 2" : "Price 2"} (\$${(item['price2'] as num).toStringAsFixed(2)})',
                                            ),
                                          ),
                                        if (item['price3'] != null)
                                          DropdownMenuItem(
                                            value: 'price3',
                                            child: Text(
                                              '${isArabic ? "سعر 3" : "Price 3"} (\$${(item['price3'] as num).toStringAsFixed(2)})',
                                            ),
                                          ),
                                        DropdownMenuItem(
                                          value: 'custom',
                                          child: Text(
                                            isArabic
                                                ? 'سعر خاص ✏️'
                                                : 'Custom Price ✏️',
                                          ),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val == null) return;
                                        setState(() {
                                          item['selectedTier'] = val;
                                          if (val == 'price1') {
                                            item['price'] =
                                                item['price1'] ?? item['price'];
                                          } else if (val == 'price2') {
                                            item['price'] = item['price2'];
                                          } else if (val == 'price3') {
                                            item['price'] = item['price3'];
                                          }
                                          item['total'] =
                                              (item['quantity'] as num) *
                                              (item['price'] as num);
                                        });
                                      },
                                    ),
                                    const Spacer(),

                                    // Quantity Selector
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (item['quantity'] > 1) {
                                            item['quantity'] -= 1;
                                            item['total'] =
                                                (item['quantity'] as num) *
                                                (item['price'] as num);
                                          } else {
                                            _returnLineItems.removeAt(index);
                                          }
                                        });
                                      },
                                    ),
                                    Text(
                                      '${item['quantity']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          item['quantity'] += 1;
                                          item['total'] =
                                              (item['quantity'] as num) *
                                              (item['price'] as num);
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(
                                          () =>
                                              _returnLineItems.removeAt(index),
                                        );
                                      },
                                    ),
                                  ],
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'ملخص مرتجع المبيعات' : 'Sales Return Summary',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                _buildCalcRow(
                  isArabic ? 'المجموع الفرعي للمرتجع' : 'Return Subtotal',
                  '\$${_returnSubtotal.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _returnDiscountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        isArabic
                            ? 'خصم على المرتجع (\$)'
                            : 'Return Discount (\$)',
                    prefixIcon: const Icon(
                      Icons.discount,
                      color: AppTheme.dangerColor,
                    ),
                  ),
                  onChanged: (val) {
                    setState(
                      () => _returnDiscount = double.tryParse(val) ?? 0.0,
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildCalcRow(
                  isArabic ? 'صافي إجمالي المرتجع' : 'Net Return Total',
                  '\$${_returnTotalAmount.toStringAsFixed(2)}',
                  isBold: true,
                  color: AppTheme.dangerColor,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _returnRefundController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        isArabic
                            ? 'المبلغ المسترد نقداً للعميل (\$)'
                            : 'Refunded Cash Amount (\$)',
                    prefixIcon: const Icon(
                      Icons.money,
                      color: AppTheme.dangerColor,
                    ),
                  ),
                  onChanged: (val) {
                    setState(
                      () => _returnRefundAmount = double.tryParse(val) ?? 0.0,
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildCalcRow(
                  isArabic ? 'المخصوم من رصيد العميل' : 'Credit to Client Debt',
                  '\$${_returnRemainingAmount.toStringAsFixed(2)}',
                  isBold: true,
                  color: AppTheme.successColor,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _returnNotesController,
                  decoration: InputDecoration(
                    labelText:
                        isArabic
                            ? 'سبب الإرجاع / ملاحظات'
                            : 'Return Reason / Notes',
                    prefixIcon: const Icon(
                      Icons.note,
                      color: AppTheme.dangerColor,
                    ),
                  ),
                  onChanged: (val) => _returnNotes = val,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.dangerColor,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: Text(
                      isArabic
                          ? 'حفظ وتصدير مرتجع المبيعات (PDF)'
                          : 'Save & Export Sales Return (PDF)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed:
                        _isReturnSubmitting
                            ? null
                            : () => _submitSalesReturn(isArabic),
                  ),
                ),
              ],
            ),
          ),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child:
              isDesktop
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

  Widget _buildInvoicesHistoryTab(BuildContext context, bool isArabic) {
    Query query = _firestore.collection('sales_invoices');

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
                const Icon(
                  Icons.filter_alt_rounded,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic
                            ? 'تصفية الفواتير بالفترة'
                            : 'Invoice Date Filter',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isArabic
                            ? 'ترشيد استهلاك قراءة الفايربيس (Firebase Quota Saver)'
                            : 'Optimizes Firebase database reads quota',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Month Selector Dropdown
                DropdownButton<int>(
                  value: _selectedHistoryMonth,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(isArabic ? 'كل الشهور' : 'All Months'),
                    ),
                    ...List.generate(12, (index) {
                      final m = index + 1;
                      final monthName = DateFormat.MMMM(
                        isArabic ? 'ar' : 'en',
                      ).format(DateTime(2026, m));
                      return DropdownMenuItem(value: m, child: Text(monthName));
                    }),
                  ],
                  onChanged: (val) {
                    if (val != null)
                      setState(() => _selectedHistoryMonth = val);
                  },
                ),
                const SizedBox(width: 12),

                // Year Selector Dropdown
                DropdownButton<int>(
                  value: _selectedHistoryYear,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
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
                      const Icon(
                        Icons.receipt_long_outlined,
                        size: 54,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isArabic
                            ? 'لا توجد فواتير مبيعات في هذه الفترة المحددة'
                            : 'No sales invoices recorded for this selected period',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 15,
                        ),
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
                  final client = data['clientName'] ?? '';
                  final total = (data['totalAmount'] ?? 0.0).toDouble();
                  final paid = (data['paidAmount'] ?? 0.0).toDouble();
                  final remaining = (data['remainingAmount'] ?? 0.0).toDouble();
                  final date = ClientInvoiceBalanceSyncService.parseInvoiceDate(
                    data['date'] ?? data['createdAt'],
                  );

                  final paidLabel = isArabic ? 'مدفوع: ' : 'Paid: ';
                  final remLabel = isArabic ? 'متبقي: ' : 'Rem: ';
                  final subText =
                      '$paidLabel\$${paid.toStringAsFixed(2)} | $remLabel\$${remaining.toStringAsFixed(2)}';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        child: Icon(Icons.receipt, color: Colors.white),
                      ),
                      title: Text(
                        '#$invNum - $client',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${DateFormat('yyyy/MM/dd HH:mm').format(date)} • Payment: ${data['paymentMethod']}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                subText,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.print_rounded,
                              color: AppTheme.primaryColor,
                            ),
                            onPressed: () {
                              ClientStatementPdfService.showSalesInvoiceActionDialog(
                                context: context,
                                invoiceData: data,
                                locale: isArabic ? 'ar' : 'en',
                              );
                            },
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: Colors.grey,
                            ),
                            onSelected: (value) async {
                              if (value == 'edit') {
                                final invoiceDataWithId =
                                    Map<String, dynamic>.from(data);
                                invoiceDataWithId['id'] = docs[index].id;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => SalesInvoicePage(
                                          initialInvoiceData: invoiceDataWithId,
                                        ),
                                  ),
                                );
                              } else if (value == 'delete') {
                                final invoiceDataWithId =
                                    Map<String, dynamic>.from(data);
                                invoiceDataWithId['id'] = docs[index].id;
                                await SalesInvoiceActionsService.deleteSalesInvoice(
                                  context: context,
                                  invoiceData: invoiceDataWithId,
                                );
                              }
                            },
                            itemBuilder:
                                (pCtx) => [
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.edit_rounded,
                                          color: AppTheme.primaryColor,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isArabic
                                              ? 'تعديل الفاتورة'
                                              : 'Edit Invoice',
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.delete_forever_rounded,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isArabic
                                              ? 'حذف الفاتورة'
                                              : 'Delete Invoice',
                                          style: const TextStyle(
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
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
        ),
      ],
    );
  }

  Widget _buildCalcRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
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
