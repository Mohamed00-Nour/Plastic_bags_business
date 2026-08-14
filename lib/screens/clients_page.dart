import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/client_invoice_balance_sync_service.dart';
import '../services/client_statement_pdf_service.dart';
import 'client_details_page.dart';
import '../core/theme/app_theme.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final ClientInvoiceBalanceSyncService _clientSyncService =
      ClientInvoiceBalanceSyncService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddClientDialog(BuildContext context, bool isArabic) {
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
              textDirection:
                  isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
              child: AlertDialog(
                title: Row(
                  children: [
                    const Icon(
                      Icons.person_add_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(isArabic ? 'إضافة عميل جديد' : 'Add New Client'),
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
                            labelText:
                                isArabic ? 'اسم العميل *' : 'Client Name *',
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return isArabic
                                  ? 'برجاء إدخال اسم العميل'
                                  : 'Please enter client name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText:
                                isArabic ? 'رقم الهاتف *' : 'Phone Number *',
                            prefixIcon: const Icon(Icons.phone_outlined),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return isArabic
                                  ? 'برجاء إدخال رقم الهاتف'
                                  : 'Please enter phone number';
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
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                isArabic
                                    ? 'الرصيد الافتتاحي (مدين)'
                                    : 'Opening Balance (Debt)',
                            prefixIcon: const Icon(
                              Icons.account_balance_wallet_outlined,
                            ),
                            helperText:
                                isArabic
                                    ? 'المبلغ الذي يدين به العميل عند تسجيله'
                                    : 'Amount the client owes at registration',
                          ),
                          validator: (val) {
                            if (val != null &&
                                val.isNotEmpty &&
                                double.tryParse(val) == null) {
                              return isArabic
                                  ? 'مبلغ غير صحيح'
                                  : 'Invalid amount';
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
                    onPressed:
                        isLoading
                            ? null
                            : () async {
                              if (!formKey.currentState!.validate()) return;

                              setDialogState(() => isLoading = true);
                              try {
                                final name = nameController.text.trim();
                                final phone = phoneController.text.trim();
                                final address = addressController.text.trim();
                                final openingBal =
                                    double.tryParse(
                                      openingBalanceController.text.trim(),
                                    ) ??
                                    0.0;

                                final isDup = await _clientSyncService
                                    .isDuplicateClientName(name);
                                if (isDup) {
                                  setDialogState(() => isLoading = false);
                                  if (!dialogContext.mounted) return;
                                  ScaffoldMessenger.of(
                                    dialogContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isArabic
                                            ? 'عفواً، يوجد عميل بنفس الاسم بالفعل!'
                                            : 'A client with this name already exists!',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                await _clientSyncService.createClient(
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
                                      isArabic
                                          ? 'تم إضافـة العميل بنجاح'
                                          : 'Client created successfully',
                                    ),
                                    backgroundColor: AppTheme.successColor,
                                  ),
                                );
                              } catch (e) {
                                setDialogState(() => isLoading = false);
                                if (!dialogContext.mounted) return;
                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                    child:
                        isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
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

  void _showEditClientDialog(
    BuildContext context,
    Map<String, dynamic> client,
    bool isArabic,
  ) {
    final nameController = TextEditingController(text: client['name'] ?? '');
    final phoneController = TextEditingController(text: client['phone'] ?? '');
    final addressController = TextEditingController(
      text: client['address'] ?? '',
    );
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    final clientId = client['id'] ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection:
                  isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
              child: AlertDialog(
                title: Row(
                  children: [
                    const Icon(
                      Icons.edit_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(isArabic ? 'تعديل بيانات العميل' : 'Edit Client Info'),
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
                            labelText:
                                isArabic ? 'اسم العميل *' : 'Client Name *',
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return isArabic
                                  ? 'برجاء إدخال اسم العميل'
                                  : 'Please enter client name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText:
                                isArabic ? 'رقم الهاتف *' : 'Phone Number *',
                            prefixIcon: const Icon(Icons.phone_outlined),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return isArabic
                                  ? 'برجاء إدخال رقم الهاتف'
                                  : 'Please enter phone number';
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
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        isLoading ? null : () => Navigator.pop(dialogContext),
                    child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                  ),
                  ElevatedButton(
                    onPressed:
                        isLoading
                            ? null
                            : () async {
                              if (!formKey.currentState!.validate()) return;
                              setDialogState(() => isLoading = true);

                              // Show Loading Overlay
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder:
                                    (loadingCtx) => Center(
                                      child: Card(
                                        color: const Color(0xFF1E293B),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 18,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const CircularProgressIndicator(
                                                color: AppTheme.primaryColor,
                                              ),
                                              const SizedBox(width: 16),
                                              Text(
                                                isArabic
                                                    ? 'جاري حفظ تعديلات العميل...'
                                                    : 'Updating client info...',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                              );

                              try {
                                await _clientSyncService.updateClient(
                                  clientId: clientId,
                                  name: nameController.text.trim(),
                                  phone: phoneController.text.trim(),
                                  address: addressController.text.trim(),
                                );

                                if (!context.mounted) return;
                                // Pop loading overlay & dialog
                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pop();
                                if (dialogContext.mounted)
                                  Navigator.pop(dialogContext);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isArabic
                                          ? 'تم تحديث بيانات العميل بنجاح'
                                          : 'Client updated successfully',
                                    ),
                                    backgroundColor: AppTheme.successColor,
                                  ),
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop();
                                }
                                setDialogState(() => isLoading = false);
                                if (!dialogContext.mounted) return;
                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                    child:
                        isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(isArabic ? 'حفظ التعديلات' : 'Update'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteClient(
    BuildContext context,
    Map<String, dynamic> client,
    bool isArabic,
  ) {
    final clientId = client['id'] ?? '';
    final clientName = client['name'] ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.delete_forever_rounded, color: Colors.red),
                const SizedBox(width: 8),
                Text(isArabic ? 'تأكيد حذف العميل' : 'Delete Client'),
              ],
            ),
            content: Text(
              isArabic
                  ? 'هل أنت تأكد من حذف العميل ($clientName)؟\n(سيتم حذف بيانات العميل وسجل الحسابات الخاصة به)'
                  : 'Are you sure you want to delete client ($clientName)?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(dialogContext);

                  // Show Loading Overlay
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (loadingCtx) => Center(
                          child: Card(
                            color: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 18,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    isArabic
                                        ? 'جاري حذف العميل وسجل المعاملات...'
                                        : 'Deleting client records...',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  );

                  try {
                    await _clientSyncService.deleteClient(clientId);
                    if (!context.mounted) return;
                    Navigator.of(context, rootNavigator: true).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isArabic
                              ? 'تم حذف العميل بنجاح'
                              : 'Client deleted successfully',
                        ),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    Navigator.of(context, rootNavigator: true).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text(isArabic ? 'حذف العميل' : 'Delete'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBalanceHistoryDialog(
    BuildContext context,
    Map<String, dynamic> clientData,
    bool isArabic,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _ClientBalanceHistoryDialogContent(
          clientData: clientData,
          isArabic: isArabic,
          clientSyncService: _clientSyncService,
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
                          onChanged:
                              (val) =>
                                  setState(() => _searchQuery = val.trim()),
                          decoration: InputDecoration(
                            hintText:
                                isArabic
                                    ? 'بحث بالاسم أو رقم الهاتف...'
                                    : 'Search by name or phone...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon:
                                _searchQuery.isNotEmpty
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
                            onPressed:
                                () => _showAddClientDialog(context, isArabic),
                            icon: const Icon(Icons.add),
                            label: Text(isArabic ? 'إضافة عميل' : 'Add Client'),
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
                          onChanged:
                              (val) =>
                                  setState(() => _searchQuery = val.trim()),
                          decoration: InputDecoration(
                            hintText:
                                isArabic
                                    ? 'بحث بالاسم أو رقم الهاتف...'
                                    : 'Search by name or phone...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon:
                                _searchQuery.isNotEmpty
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
                        onPressed:
                            () => _showAddClientDialog(context, isArabic),
                        icon: const Icon(Icons.add),
                        label: Text(isArabic ? 'إضافة عميل' : 'Add Client'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(140, 48),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // Main List & KPI Summary
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _clientSyncService.getClientsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final clients = snapshot.data ?? [];
                    final filteredClients =
                        clients.where((c) {
                          final name =
                              (c['name'] ?? '').toString().toLowerCase();
                          final phone =
                              (c['phone'] ?? '').toString().toLowerCase();
                          final q = _searchQuery.toLowerCase();
                          return name.contains(q) || phone.contains(q);
                        }).toList();

                    final totalDebt = filteredClients.fold<double>(
                      0.0,
                      (acc, item) =>
                          acc + ((item['balance'] ?? 0.0) as num).toDouble(),
                    );

                    final clientCountLabel =
                        isArabic
                            ? '${filteredClients.length} عملاء'
                            : '${filteredClients.length} Clients';

                    return Column(
                      children: [
                        // KPI Summary Card
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet,
                                  color: AppTheme.primaryColor,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isArabic
                                          ? 'إجمالي مستحقات الديون (العملاء)'
                                          : 'Total Outstanding Client Debts',
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                    ),
                                    Text(
                                      '\$${totalDebt.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.dangerColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Chip(label: Text(clientCountLabel)),
                              ],
                            ),
                          ),
                        ),

                        // Clients List
                        Expanded(
                          child:
                              filteredClients.isEmpty
                                  ? Center(
                                    child: Text(
                                      isArabic
                                          ? 'لا يوجد عملاء مطبقين للبحث'
                                          : 'No clients found',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                  : ListView.builder(
                                    itemCount: filteredClients.length,
                                    itemBuilder: (context, index) {
                                      final client = filteredClients[index];
                                      final balance =
                                          (client['balance'] ?? 0.0).toDouble();

                                      return Card(
                                        margin: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: ListTile(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) =>
                                                        ClientDetailsPage(
                                                          clientData: client,
                                                        ),
                                              ),
                                            );
                                          },
                                          leading: CircleAvatar(
                                            backgroundColor: AppTheme
                                                .primaryColor
                                                .withValues(alpha: 0.15),
                                            child: Text(
                                              (client['name'] ?? 'C')
                                                  .toString()
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                color: AppTheme.primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            client['name'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${client['phone'] ?? ''} ${client['address'] != null && client['address'].isNotEmpty ? "• ${client['address']}" : ""}',
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    isArabic
                                                        ? 'الرصيد المستحق'
                                                        : 'Due Balance',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                  Text(
                                                    '\$${balance.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          balance > 0
                                                              ? AppTheme
                                                                  .dangerColor
                                                              : AppTheme
                                                                  .successColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 8),
                                              /*IconButton(
                                              icon: const Icon(Icons.history_rounded, color: AppTheme.primaryColor),
                                              tooltip: isArabic ? 'كشف حساب وتاريخ الرصيد' : 'Balance History & Statement',
                                              onPressed: () => _showBalanceHistoryDialog(context, client, isArabic),
                                            ),*/
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit_rounded,
                                                  color: AppTheme.primaryColor,
                                                ),
                                                tooltip:
                                                    isArabic
                                                        ? 'تعديل بيانات العميل'
                                                        : 'Edit Client Info',
                                                onPressed:
                                                    () => _showEditClientDialog(
                                                      context,
                                                      client,
                                                      isArabic,
                                                    ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_forever_rounded,
                                                  color: Colors.red,
                                                ),
                                                tooltip:
                                                    isArabic
                                                        ? 'حذف العميل'
                                                        : 'Delete Client',
                                                onPressed:
                                                    () => _confirmDeleteClient(
                                                      context,
                                                      client,
                                                      isArabic,
                                                    ),
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

class _ClientBalanceHistoryDialogContent extends StatefulWidget {
  final Map<String, dynamic> clientData;
  final bool isArabic;
  final ClientInvoiceBalanceSyncService clientSyncService;

  const _ClientBalanceHistoryDialogContent({
    required this.clientData,
    required this.isArabic,
    required this.clientSyncService,
  });

  @override
  State<_ClientBalanceHistoryDialogContent> createState() =>
      _ClientBalanceHistoryDialogContentState();
}

class _ClientBalanceHistoryDialogContentState
    extends State<_ClientBalanceHistoryDialogContent> {
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
        case 'sales_invoice':
          return 'فاتورة مبيعات';
        case 'sales_return':
          return 'مرتجع مبيعات';
        case 'payment':
          return 'سداد';
        default:
          return 'حركة رصيد';
      }
    } else {
      switch (type) {
        case 'opening':
          return 'Opening Balance';
        case 'sales_invoice':
          return 'Sales Invoice';
        case 'sales_return':
          return 'Sales Return';
        case 'payment':
          return 'Payment';
        default:
          return 'Transaction';
      }
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'opening':
        return Colors.blue;
      case 'sales_invoice':
        return Colors.amber;
      case 'sales_return':
        return Colors.green;
      case 'payment':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientId = widget.clientData['id'] ?? '';
    final clientName = widget.clientData['name'] ?? '';
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
                      const Icon(
                        Icons.history_rounded,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${isArabic ? "تاريخ الرصيد -" : "Balance History -"} $clientName',
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
                    label: Text(
                      isArabic
                          ? 'طباعة كشف حساب (PDF)'
                          : 'Print Statement (PDF)',
                    ),
                    onPressed: () async {
                      final records =
                          await widget.clientSyncService
                              .getClientBalanceHistoryStream(clientId)
                              .first;
                      if (!context.mounted) return;
                      await ClientStatementPdfService.printOrShareClientStatement(
                        clientData: widget.clientData,
                        records: records,
                        locale: isArabic ? 'ar' : 'en',
                      );
                    },
                  ),
                  const Spacer(),
                  Text(
                    '${isArabic ? "الرصيد المستحق: " : "Due Balance: "}\$${(widget.clientData['balance'] ?? 0.0).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // History Table with BOTH Vertical & Horizontal Visible Scrollbars
              Expanded(
                child: StreamBuilder<List<ClientBalanceRecord>>(
                  stream: widget.clientSyncService
                      .getClientBalanceHistoryStream(clientId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final records = snapshot.data ?? [];
                    if (records.isEmpty) {
                      return Center(
                        child: Text(
                          isArabic
                              ? 'لا توجد حركات رصيد سابقة'
                              : 'No balance history recorded',
                        ),
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
                              constraints: const BoxConstraints(minWidth: 800),
                              child: DataTable(
                                columns: [
                                  DataColumn(
                                    label: Text(isArabic ? 'التاريخ' : 'Date'),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      isArabic ? 'نوع الحركة' : 'Type',
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      isArabic ? 'رقم الفاتورة' : 'Invoice #',
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      isArabic ? 'الملاحظات' : 'Notes',
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(isArabic ? 'المبلغ' : 'Amount'),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      isArabic
                                          ? 'الرصيد المتبقي'
                                          : 'Balance After',
                                    ),
                                  ),
                                ],
                                rows:
                                    records.map((rec) {
                                      final isOpening = rec.type == 'opening';
                                      final noteText =
                                          rec.notes.isNotEmpty &&
                                                  rec.notes !=
                                                      'تحصيل دفعة نقداً' &&
                                                  rec.notes !=
                                                      'إضافة مديونية' &&
                                                  !rec.notes.startsWith(
                                                    'تحصيل من فاتورة #',
                                                  )
                                              ? rec.notes
                                              : (rec.description.isNotEmpty &&
                                                      rec.description !=
                                                          'تحصيل دفعة نقداً' &&
                                                      rec.description !=
                                                          'إضافة مديونية' &&
                                                      !rec.description
                                                          .startsWith(
                                                            'تحصيل من فاتورة #',
                                                          )
                                                  ? rec.description
                                                  : '-');
                                      return DataRow(
                                        color:
                                            isOpening
                                                ? WidgetStateProperty.all(
                                                  AppTheme.primaryColor
                                                      .withValues(alpha: 0.08),
                                                )
                                                : null,
                                        cells: [
                                          DataCell(
                                            Text(
                                              DateFormat(
                                                'yyyy/MM/dd HH:mm',
                                              ).format(rec.timestamp),
                                            ),
                                          ),
                                          DataCell(
                                            Chip(
                                              label: Text(
                                                _getTypeLabel(
                                                  rec.type,
                                                  isArabic,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                              backgroundColor: _getTypeColor(
                                                rec.type,
                                              ).withValues(alpha: 0.2),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              rec.invoiceNumber.isEmpty
                                                  ? '-'
                                                  : rec.invoiceNumber,
                                            ),
                                          ),
                                          DataCell(Text(noteText)),
                                          DataCell(
                                            Text(
                                              '\$${rec.amount.toStringAsFixed(2)}',
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '\$${rec.balanceAfter.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
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
