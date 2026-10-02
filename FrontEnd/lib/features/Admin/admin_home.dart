import 'package:flutter/material.dart';
import '../../core/role_home_scaffold.dart';
import 'create_staff_page.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleHomeScaffold(
      title: 'Beranda Admin',
      children: [
        ListTile(
          leading: const Icon(Icons.person_add),
          title: const Text('Buat akun kader / bidan'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateStaffPage()),
          ),
        ),
      ],
    );
  }
}