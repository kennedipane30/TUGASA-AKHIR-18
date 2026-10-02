import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/auth/auth_provider.dart';

class RoleHomeScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const RoleHomeScaffold({
    super.key,
    required this.title,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Halo, ${user?['nama'] ?? ''}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Role: ${user?['role'] ?? '-'}'),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}