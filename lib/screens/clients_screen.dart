import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<dynamic> clients = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchClients();
  }

  Future<void> fetchClients() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/clients'));
      if (res.statusCode == 200) {
        setState(() {
          clients = jsonDecode(res.body);
          loading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تحميل العملاء')),
        );
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد اتصال بالإنترنت')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('العملاء', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFE8B923),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : clients.isEmpty
              ? const Center(child: Text('لا يوجد عملاء', style: TextStyle(color: Colors.white70, fontSize: 20)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: clients.length,
                  itemBuilder: (ctx, i) {
                    final client = clients[i];
                    return Card(
                      color: Colors.white.withOpacity(0.1),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE8B923),
                          child: Text(
                            client['PartyName'][0].toUpperCase(),
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          client['PartyName'] ?? 'بدون اسم',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          client['Phone'] ?? 'لا يوجد هاتف',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFFFFD700)),
                        onTap: () {
                          // بعدين هنفتح تفاصيل العميل
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('العميل: ${client['PartyName']}')),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE8B923),
        child: const Icon(Icons.refresh, color: Colors.black),
        onPressed: () {
          setState(() => loading = true);
          fetchClients();
        },
      ),
    );
  }
}