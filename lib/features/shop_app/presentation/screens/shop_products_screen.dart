import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';

class ShopProductsScreen extends StatelessWidget {
  const ShopProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final products = snapshot.data!.docs;
        if (products.isEmpty) {
          return const Center(child: Text('No products available'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final data = products[index].data() as Map<String, dynamic>;
            final name = data['name'] ?? '';
            final size = data['size'] ?? '';
            final price = (data['price'] ?? 0).toDouble();
            final stock = (data['stockQuantity'] ?? 0).toInt();
            final isLow = stock < 10;

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: const Icon(Icons.inventory_2, color: Colors.white),
                ),
                title: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Size: $size'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price.toStringAsFixed(1),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Stock: $stock',
                      style: TextStyle(
                        fontSize: 12,
                        color: isLow ? AppTheme.dangerColor : AppTheme.textSecondary,
                        fontWeight: isLow ? FontWeight.bold : FontWeight.normal,
                      ),
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
}
