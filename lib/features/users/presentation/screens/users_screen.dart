import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../data/models/user_model.dart';
import '../../bloc/user_bloc.dart';
import '../../bloc/user_event.dart';
import '../../bloc/user_state.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  void initState() {
    super.initState();
    context.read<UserManagementBloc>().add(UserManagementLoadRequested());
  }

  String _localizedRole(AppLocalizations l10n, UserRole role) {
    switch (role) {
      case UserRole.admin:
        return l10n.roleAdmin;
      case UserRole.employee:
        return l10n.roleEmployee;
      case UserRole.viewer:
        return l10n.roleViewer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<UserManagementBloc, UserManagementState>(
      listener: (context, state) {
        if (state is UserManagementOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.successColor),
          );
          context.read<UserManagementBloc>().add(UserManagementLoadRequested());
        } else if (state is UserManagementError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.dangerColor),
          );
        }
      },
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Text(l10n.userManagement,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateUserDialog(context),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: Text(l10n.addUser),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(child: _buildContent(state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(UserManagementState state) {
    final l10n = AppLocalizations.of(context)!;
    if (state is UserManagementLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is UserManagementLoaded) {
      if (state.users.isEmpty) {
        return EmptyStateWidget(
          icon: Icons.people_outline,
          title: l10n.noUsersFound,
        );
      }
      return Card(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(label: Text(l10n.name)),
                DataColumn(label: Text(l10n.email)),
                DataColumn(label: Text(l10n.role)),
                DataColumn(label: Text(l10n.shop)),
                DataColumn(label: Text(l10n.status)),
                DataColumn(label: Text(l10n.actions)),
              ],
              rows: state.users.map((user) {
                return DataRow(cells: [
                  DataCell(Text(user.name,
                      style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Text(user.email)),
                  DataCell(_buildRoleBadge(user.role)),
                  DataCell(Text(user.shopName ?? '—')),
                  DataCell(StatusBadge(
                    label: user.isActive ? l10n.statusActive : l10n.statusInactive,
                    color: user.isActive
                        ? AppTheme.successColor
                        : AppTheme.textSecondary,
                  )),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<UserRole>(
                        icon: const Icon(Icons.admin_panel_settings,
                            size: 20, color: AppTheme.primaryColor),
                        tooltip: l10n.changeRole,
                        onSelected: (role) {
                          context.read<UserManagementBloc>().add(UserManagementUpdateRoleRequested(
                                userId: user.id,
                                role: role,
                              ));
                        },
                        itemBuilder: (ctx) => UserRole.values
                            .map((role) => PopupMenuItem(
                                  value: role,
                                  child: Row(
                                    children: [
                                      Icon(
                                        role == user.role
                                            ? Icons.check
                                            : Icons.circle_outlined,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(_localizedRole(l10n, role)),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                      IconButton(
                        icon: Icon(
                          user.isActive
                              ? Icons.block
                              : Icons.check_circle_outline,
                          size: 20,
                          color: user.isActive
                              ? AppTheme.dangerColor
                              : AppTheme.successColor,
                        ),
                        tooltip: user.isActive ? l10n.deactivate : l10n.activate,
                        onPressed: () async {
                          final confirmed = await ConfirmationDialog.show(
                            context,
                            title: user.isActive ? l10n.deactivateUser : l10n.activateUser,
                            message: l10n.areYouSureDelete(user.name),
                            confirmLabel: user.isActive
                                ? l10n.deactivate
                                : l10n.activate,
                            confirmColor: user.isActive
                                ? AppTheme.dangerColor
                                : AppTheme.successColor,
                          );
                          if (confirmed == true && mounted) {
                            context.read<UserManagementBloc>().add(
                                  UserManagementToggleActiveRequested(
                                    userId: user.id,
                                    isActive: !user.isActive,
                                  ),
                                );
                          }
                        },
                      ),
                    ],
                  )),
                ]);
              }).toList(),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildRoleBadge(UserRole role) {
    final l10n = AppLocalizations.of(context)!;
    Color color;
    switch (role) {
      case UserRole.admin:
        color = AppTheme.dangerColor;
        break;
      case UserRole.employee:
        color = AppTheme.primaryColor;
        break;
      case UserRole.viewer:
        color = AppTheme.textSecondary;
        break;
    }
    return StatusBadge(label: _localizedRole(l10n, role), color: color);
  }

  void _showCreateUserDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    UserRole selectedRole = UserRole.employee;
    String? selectedShopId;
    String? selectedShopName;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.createUser),
          content: SizedBox(
            width: 450,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: l10n.fullName),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? l10n.required_field : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: InputDecoration(labelText: l10n.email),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v?.trim().isEmpty == true) return l10n.required_field;
                      if (!v!.contains('@')) return l10n.invalidEmail;
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordCtrl,
                    decoration: InputDecoration(labelText: l10n.password),
                    obscureText: true,
                    validator: (v) {
                      if (v?.isEmpty == true) return l10n.required_field;
                      if (v!.length < 6) return l10n.minSixChars;
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UserRole>(
                    value: selectedRole,
                    decoration: InputDecoration(labelText: l10n.role),
                    items: UserRole.values
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(_localizedRole(l10n, r)),
                            ))
                        .toList(),
                    onChanged: (role) {
                      if (role != null) {
                        setDialogState(() {
                          selectedRole = role;
                          if (role == UserRole.admin) {
                            selectedShopId = null;
                            selectedShopName = null;
                          }
                        });
                      }
                    },
                  ),
                  if (selectedRole != UserRole.admin) ...[
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('shops')
                          .where('isActive', isEqualTo: true)
                          .orderBy('name')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final shops = snapshot.data?.docs ?? [];
                        return DropdownButtonFormField<String>(
                          value: selectedShopId,
                          decoration:
                              InputDecoration(labelText: l10n.assignToShop),
                          validator: (v) => selectedRole != UserRole.admin &&
                                  (v == null || v.isEmpty)
                              ? l10n.pleaseSelectShop
                              : null,
                          items: shops
                              .map((doc) {
                                final data =
                                    doc.data() as Map<String, dynamic>;
                                return DropdownMenuItem(
                                  value: doc.id,
                                  child: Text(data['name'] ?? ''),
                                );
                              })
                              .toList(),
                          onChanged: (id) {
                            if (id != null) {
                              final doc =
                                  shops.firstWhere((d) => d.id == id);
                              final data =
                                  doc.data() as Map<String, dynamic>;
                              setDialogState(() {
                                selectedShopId = id;
                                selectedShopName = data['name'] ?? '';
                              });
                            }
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  context.read<UserManagementBloc>().add(UserManagementCreateRequested(
                        email: emailCtrl.text.trim(),
                        password: passwordCtrl.text,
                        name: nameCtrl.text.trim(),
                        role: selectedRole,
                        shopId: selectedShopId,
                        shopName: selectedShopName,
                      ));
                  Navigator.pop(ctx);
                }
              },
              child: Text(l10n.create),
            ),
          ],
        ),
      ),
    );
  }
}
