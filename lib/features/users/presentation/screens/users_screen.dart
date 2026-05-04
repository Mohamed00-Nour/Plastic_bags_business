import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  Widget build(BuildContext context) {
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
                  const Text('User Management',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateUserDialog(context),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Add User'),
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
    if (state is UserManagementLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is UserManagementLoaded) {
      if (state.users.isEmpty) {
        return const EmptyStateWidget(
          icon: Icons.people_outline,
          title: 'No users found',
        );
      }
      return Card(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Shop')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: state.users.map((user) {
                return DataRow(cells: [
                  DataCell(Text(user.name,
                      style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Text(user.email)),
                  DataCell(_buildRoleBadge(user.role)),
                  DataCell(Text(user.shopName ?? '—')),
                  DataCell(StatusBadge(
                    label: user.isActive ? 'Active' : 'Inactive',
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
                        tooltip: 'Change Role',
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
                                      Text(role.label),
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
                        tooltip: user.isActive ? 'Deactivate' : 'Activate',
                        onPressed: () async {
                          final action =
                              user.isActive ? 'deactivate' : 'activate';
                          final confirmed = await ConfirmationDialog.show(
                            context,
                            title: '${user.isActive ? 'Deactivate' : 'Activate'} User',
                            message:
                                'Are you sure you want to $action "${user.name}"?',
                            confirmLabel: user.isActive
                                ? 'Deactivate'
                                : 'Activate',
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
    return StatusBadge(label: role.label, color: color);
  }

  void _showCreateUserDialog(BuildContext context) {
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
          title: const Text('Create User'),
          content: SizedBox(
            width: 450,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v?.trim().isEmpty == true) return 'Required';
                      if (!v!.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordCtrl,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (v) {
                      if (v?.isEmpty == true) return 'Required';
                      if (v!.length < 6) return 'Min 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UserRole>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: UserRole.values
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.label),
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
                              const InputDecoration(labelText: 'Assign to Shop'),
                          validator: (v) => selectedRole != UserRole.admin &&
                                  (v == null || v.isEmpty)
                              ? 'Please select a shop'
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
              child: const Text('Cancel'),
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
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
