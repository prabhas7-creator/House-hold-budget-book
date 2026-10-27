import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const HouseholdBudgetApp());

class HouseholdBudgetApp extends StatelessWidget {
  const HouseholdBudgetApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Household Budget Book',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087F8C)),
          scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        ),
        home: const BudgetHomePage(),
      );
}

enum TransactionType { income, expense }

class BudgetTransaction {
  final String id, title, category;
  final double amount;
  final TransactionType type;
  final DateTime date;

  const BudgetTransaction({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.type,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'type': type.name,
        'date': date.toIso8601String(),
      };

  factory BudgetTransaction.fromJson(Map<String, dynamic> json) =>
      BudgetTransaction(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        amount: (json['amount'] as num).toDouble(),
        type: json['type'] == 'income'
            ? TransactionType.income
            : TransactionType.expense,
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      );
}

class BudgetHomePage extends StatefulWidget {
  const BudgetHomePage({super.key});

  @override
  State<BudgetHomePage> createState() => _BudgetHomePageState();
}

class _BudgetHomePageState extends State<BudgetHomePage> {
  static const storageKey = 'household_budget_transactions';
  final List<BudgetTransaction> transactions = [];
  bool loading = true;
  int tab = 0;
  String filter = 'All';

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        transactions.addAll(list.map((item) => BudgetTransaction.fromJson(
            Map<String, dynamic>.from(item as Map))));
      }
    } catch (_) {
      // If saved data is unavailable, the app starts with an empty budget.
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(transactions.map((item) => item.toJson()).toList()),
    );
  }

  double get income => transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get expenses => transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get balance => income - expenses;
  String money(double value) => '₹' + value.toStringAsFixed(2);

  List<BudgetTransaction> get visibleTransactions {
    final result = transactions.where((t) {
      if (filter == 'Income') return t.type == TransactionType.income;
      if (filter == 'Expenses') return t.type == TransactionType.expense;
      return true;
    }).toList();
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  Future<void> addTransaction(String title, String category, double amount,
      TransactionType type) async {
    setState(() {
      transactions.add(BudgetTransaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        category: category,
        amount: amount,
        type: type,
        date: DateTime.now(),
      ));
    });
    await saveTransactions();
  }

  Future<void> deleteTransaction(BudgetTransaction transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text('Remove "' + transaction.title + '" from your budget?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => transactions.removeWhere((t) => t.id == transaction.id));
      await saveTransactions();
    }
  }

  Future<void> showAddDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    TransactionType type = TransactionType.expense;
    String category = 'Groceries';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add transaction'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Expense'),
                      icon: Icon(Icons.shopping_cart_outlined),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Income'),
                      icon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) => setDialogState(() {
                    type = value.first;
                    category = type == TransactionType.income ? 'Salary' : 'Groceries';
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Monthly groceries',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a title'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value ?? '');
                    return amount == null || amount <= 0
                        ? 'Enter an amount greater than zero'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: (type == TransactionType.income
                          ? ['Salary', 'Business', 'Gift', 'Other income']
                          : ['Groceries', 'Rent', 'Bills', 'Transport', 'Education',
                              'Healthcare', 'Shopping', 'Other'])
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => category = value);
                  },
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      await addTransaction(
        titleController.text.trim(),
        category,
        double.parse(amountController.text.trim()),
        type,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction saved')),
        );
      }
    }
    titleController.dispose();
    amountController.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Row(children: [
            Icon(Icons.account_balance_wallet_rounded),
            SizedBox(width: 10),
            Text('Budget Book', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          actions: [
            IconButton(
              tooltip: 'Add transaction',
              onPressed: showAddDialog,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(index: tab, children: [
                dashboard(),
                transactionPage(),
                summaryPage(),
              ]),
        floatingActionButton: tab == 0
            ? FloatingActionButton.extended(
                onPressed: showAddDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add transaction'),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) => setState(() => tab = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Transactions'),
            NavigationDestination(icon: Icon(Icons.pie_chart_outline), label: 'Summary'),
          ],
        ),
      );

  Widget dashboard() {
    final recent = transactions.toList()..sort((a, b) => b.date.compareTo(a.date));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF087F8C), Color(0xFF16A085)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Available balance', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(money(balance), style: const TextStyle(
            color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          const Text('Track your household money in one place.',
              style: TextStyle(color: Colors.white)),
        ]),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: summaryCard('Income', money(income), Icons.south_west, const Color(0xFF178A57))),
        const SizedBox(width: 12),
        Expanded(child: summaryCard('Expenses', money(expenses), Icons.north_east, const Color(0xFFD94F45))),
      ]),
      const SizedBox(height: 24),
      const Text('Recent transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (recent.isEmpty)
        const Padding(
          padding: EdgeInsets.all(28),
          child: Column(children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.blueGrey),
            SizedBox(height: 8),
            Text('No transactions yet'),
            Text('Add your first income or expense.', style: TextStyle(color: Colors.black54)),
          ]),
        )
      else
        ...recent.take(4).map(transactionTile),
    ]);
  }

  Widget summaryCard(String title, String amount, IconData icon, Color color) =>
      Card(color: Colors.white, child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.12),
              foregroundColor: color, child: Icon(icon)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 5),
          FittedBox(child: Text(amount, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ]),
      ));

  Widget transactionPage() => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Transactions', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: ['All', 'Income', 'Expenses'].map((value) =>
          ChoiceChip(label: Text(value), selected: filter == value,
            onSelected: (_) => setState(() => filter = value))).toList()),
        const SizedBox(height: 10),
        if (visibleTransactions.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No matching transactions')))
        else
          ...visibleTransactions.map(transactionTile),
      ]);

  Widget summaryPage() {
    final totalMovement = income + expenses;
    final fraction = totalMovement == 0 ? 0.0 : expenses / totalMovement;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Budget summary', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      summaryLine('Total income', money(income), const Color(0xFF178A57), Icons.trending_up),
      summaryLine('Total expenses', money(expenses), const Color(0xFFD94F45), Icons.trending_down),
      summaryLine('Remaining balance', money(balance), const Color(0xFF087F8C), Icons.account_balance_wallet_outlined),
      const SizedBox(height: 20),
      Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Expense overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0), minHeight: 12,
            backgroundColor: const Color(0xFFE7EDF1), color: const Color(0xFFD94F45))),
          const SizedBox(height: 10),
          Text(totalMovement == 0 ? 'Add transactions to see your overview.' :
            (fraction * 100).toStringAsFixed(1) + '% of recorded money movement is expenses.'),
          const SizedBox(height: 8),
          const Text('This is a simple summary of recorded entries, not a bank statement.',
              style: TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ))),
    ]);
  }

  Widget summaryLine(String title, String amount, Color color, IconData icon) =>
      Card(color: Colors.white, child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.12),
          foregroundColor: color, child: Icon(icon)),
        title: Text(title),
        trailing: Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ));

  Widget transactionTile(BudgetTransaction transaction) {
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? const Color(0xFF178A57) : const Color(0xFFD94F45);
    final date = transaction.date;
    final dateText = date.day.toString().padLeft(2, '0') + '/' +
        date.month.toString().padLeft(2, '0') + '/' + date.year.toString();
    return Card(color: Colors.white, margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.12),
          foregroundColor: color, child: Icon(isIncome ? Icons.south_west : Icons.north_east)),
        title: Text(transaction.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(transaction.category + ' • ' + dateText),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text((isIncome ? '+' : '-') + money(transaction.amount),
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          PopupMenuButton<String>(
            onSelected: (value) { if (value == 'delete') deleteTransaction(transaction); },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ]),
      ),
    );
  }
}
