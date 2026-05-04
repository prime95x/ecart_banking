import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('contacts')
          .select()
          .eq('owner_id', supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);

      setState(() {
        _contacts = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar contactos: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addContact() async {
    final aliasController = TextEditingController();
    final accountController = TextEditingController();
    final bankController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Contacto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: aliasController,
              decoration: const InputDecoration(labelText: 'Alias / Nombre'),
            ),
            TextField(
              controller: accountController,
              decoration: const InputDecoration(labelText: 'Número de Cuenta'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: bankController,
              decoration: const InputDecoration(labelText: 'Banco'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (aliasController.text.isNotEmpty && accountController.text.isNotEmpty) {
                try {
                  await supabase.from('contacts').insert({
                    'owner_id': supabase.auth.currentUser!.id,
                    'alias': aliasController.text,
                    'account_number': accountController.text,
                    'bank_name': bankController.text.isEmpty ? 'N/A' : bankController.text,
                  });
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _fetchContacts();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _transferTo(Map<String, dynamic> contact) async {
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Transferir a ${contact['alias']}'),
        content: TextField(
          controller: amountController,
          decoration: const InputDecoration(labelText: 'Monto (\$)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                try {
                  // Check balance
                  final accountData = await supabase
                      .from('accounts')
                      .select('id, balance')
                      .eq('user_id', supabase.auth.currentUser!.id)
                      .limit(1)
                      .maybeSingle();

                  if (accountData == null || (accountData['balance'] as num).toDouble() < amount) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Saldo insuficiente')),
                      );
                    }
                    return;
                  }

                  // Insert negative transaction
                  await supabase.from('transactions').insert({
                    'user_id': supabase.auth.currentUser!.id,
                    'amount': -amount,
                    'description': 'Transferencia a ${contact['alias']}',
                    'status': 'completed',
                  });

                  // Deduct balance
                  await supabase.from('accounts').update({
                    'balance': (accountData['balance'] as num).toDouble() - amount,
                  }).eq('id', accountData['id']);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transferencia exitosa')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Transferir'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteContact(String id) async {
    try {
      await supabase.from('contacts').delete().eq('id', id);
      _fetchContacts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar contacto: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transferencias', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? const Center(child: Text('No tienes contactos guardados'))
              : ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final c = _contacts[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(c['alias'] ?? 'Sin nombre'),
                      subtitle: Text('${c['bank_name'] ?? ''} - ${c['account_number'] ?? ''}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteContact(c['id']),
                      ),
                      onTap: () => _transferTo(c),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addContact,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Contacto'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
    );
  }
}
