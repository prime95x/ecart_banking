import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _transactions = [];
  double _balance = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch balance
      final accountsData = await supabase
          .from('accounts')
          .select('balance')
          .eq('user_id', supabase.auth.currentUser!.id)
          .limit(1)
          .maybeSingle();

      double balance = 0.0;
      if (accountsData != null && accountsData['balance'] != null) {
        balance = (accountsData['balance'] as num).toDouble();
      }

      // Fetch transactions
      final txData = await supabase
          .from('transactions')
          .select()
          .order('created_at', ascending: false);
          
      setState(() {
        _balance = balance;
        _transactions = List<Map<String, dynamic>>.from(txData);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addFunding() async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Fondeo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Monto (\$)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Descripción'),
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
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                try {
                  // Add transaction
                  await supabase.from('transactions').insert({
                    'amount': amount,
                    'description': descriptionController.text.isEmpty ? 'Fondeo' : descriptionController.text,
                    'status': 'completed',
                    'user_id': supabase.auth.currentUser!.id,
                  });

                  // Update balance
                  final accountsData = await supabase
                      .from('accounts')
                      .select('id, balance')
                      .eq('user_id', supabase.auth.currentUser!.id)
                      .limit(1)
                      .maybeSingle();
                  
                  if (accountsData != null) {
                    await supabase.from('accounts').update({
                      'balance': (accountsData['balance'] as num).toDouble() + amount,
                    }).eq('id', accountsData['id']);
                  } else {
                    // Create account if not exists
                    await supabase.from('accounts').insert({
                      'user_id': supabase.auth.currentUser!.id,
                      'account_type': 'checking',
                      'balance': amount,
                    });
                  }

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _fetchData();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelTransaction(String id) async {
    try {
      await supabase.from('transactions').delete().eq('id', id);
      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pago cancelado exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar: $e')),
        );
      }
    }
  }

  Future<void> _completeTransaction(Map<String, dynamic> t) async {
    try {
      await supabase.from('transactions').update({'status': 'completed'}).eq('id', t['id']);
      
      // Also sum to balance
      final amount = ((t['amount'] ?? 0) as num).toDouble();
      final accountsData = await supabase
          .from('accounts')
          .select('id, balance')
          .eq('user_id', supabase.auth.currentUser!.id)
          .limit(1)
          .maybeSingle();
      
      if (accountsData != null) {
        await supabase.from('accounts').update({
          'balance': (accountsData['balance'] as num).toDouble() + amount,
        }).eq('id', accountsData['id']);
      } else {
        await supabase.from('accounts').insert({
          'user_id': supabase.auth.currentUser!.id,
          'account_type': 'checking',
          'balance': amount,
        });
      }

      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pago completado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mi Cuenta', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: Column(
                children: [
                  _buildBalanceCard(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Movimientos Recientes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _transactions.isEmpty
                        ? const Center(child: Text('No hay transacciones aún.'))
                        : ListView.builder(
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final t = _transactions[index];
                              return _buildTransactionItem(t);
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFunding,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Fondeo'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blueAccent, Colors.lightBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldo Disponible',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${_balance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> t) {
    final bool isCompleted = t['status'] == 'completed';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCompleted ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
          child: Icon(
            Icons.monetization_on,
            color: isCompleted ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(t['description'] ?? 'Transacción', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Estado: ${t['status'] ?? 'pending'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${((t['amount'] ?? 0) as num).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'complete') _completeTransaction(t);
                if (value == 'cancel') _cancelTransaction(t['id']);
              },
              itemBuilder: (BuildContext context) => [
                if (!isCompleted)
                  const PopupMenuItem(
                    value: 'complete',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text('Marcar Completado'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Cancelar Pago'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
