import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/off_payroll_service.dart';

/// دفعات خارج الراتب — مطابقة 100% لـ HR/Payroll/OffPayrollPaymentsPage.razor
/// هيرو + خطوات 1-4 + 6 إحصائيات + فورم + جدول معتمد/قيد/مدفوع
class OffPayrollScreen extends StatefulWidget {
  final int userId; final String username;
  const OffPayrollScreen({super.key, required this.userId, required this.username});
  @override
  State<OffPayrollScreen> createState() => _OffPayrollScreenState();
}

class _OffPayrollScreenState extends State<OffPayrollScreen> {
  final OffPayrollService _service = OffPayrollService();
  List<dynamic> _items = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  bool _formExpanded = false;
  String _filterStatus = 'all';
  String _month = DateFormat('yyyy-MM').format(DateTime.now());

  final _empCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _paymentType = 'BonusSeparate';
  int? _selectedEmpId;

  String _money(dynamic v) => NumberFormat('#,##0').format(v is num ? v : num.tryParse('$v')??0);

  @override void initState(){ super.initState(); _load(); }
  @override void dispose(){ _empCtrl.dispose(); _amountCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(()=>_loading=true);
    final data = await _service.getAll(month: _month, status: _filterStatus=='all'?null:_filterStatus);
    if(!mounted) return;
    setState((){ _items = (data['items']??[]) as List; _stats = (data['stats']??{}) as Map<String,dynamic>; _loading=false; });
  }

  Future<void> _create() async {
    if(_selectedEmpId==null || _amountCtrl.text.isEmpty) return;
    final ok = await _service.create(employeeId: _selectedEmpId!, amount: double.tryParse(_amountCtrl.text)??0, paymentType: _paymentType, paymentMonth: _month, description: _descCtrl.text);
    if(ok && mounted){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إنشاء الطلب وسيتم مراجعته', style: GoogleFonts.cairo()), backgroundColor: Colors.green)); _load(); setState(()=>_formExpanded=false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, title: Text('حوافز ومكافآت خارج الراتب', style: GoogleFonts.cairo(fontWeight: FontWeight.w800))),
      body: _loading ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))) : SingleChildScrollView(
        child: Column(children: [
          _hero(),
          _steps(),
          _statsBar(),
          _form(),
          _table(),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _hero(){
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)]), borderRadius: BorderRadius.circular(16)),
      child: Row(children:[
        Container(width:44,height:44,decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFF0D060)]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF0F172A))),
        const SizedBox(width:12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Text('حوافز ومكافآت خارج الراتب', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w900)),
          Text('طلب واعتماد وصرف أي مكافأة في منتصف الشهر بعيداً عن كشف الراتب', style: GoogleFonts.cairo(color: Colors.white70, fontSize:10)),
        ])),
        FilledButton.icon(onPressed: ()=>setState(()=>_formExpanded=!_formExpanded), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: const Color(0xFF0F172A)), icon: const Icon(Icons.post_add_rounded, size:16), label: Text('طلب دفعة', style: GoogleFonts.cairo(fontSize:11, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget _steps(){
    return Container(
      margin: const EdgeInsets.symmetric(horizontal:12),
      padding: const EdgeInsets.symmetric(horizontal:10, vertical:8),
      decoration: BoxDecoration(color: const Color(0xFF13273F), borderRadius: BorderRadius.circular(12)),
      child: Row(children:[
        _step('1','تسجيل'), _arrow(), _step('2','مراجعة'), _arrow(), _step('3','اعتماد'), _arrow(), _step('4','صرف'),
        const Spacer(), const Icon(Icons.info_rounded, size:12, color: Color(0xFFD4AF37)), const SizedBox(width:4),
        Flexible(child: Text('لمكافأة لا تدخل في صافي الراتب', style: GoogleFonts.cairo(color: Colors.white70, fontSize:8))),
      ]),
    );
  }
  Widget _step(String n,String l)=> Row(mainAxisSize: MainAxisSize.min, children:[Container(width:18,height:18,alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text(n, style: GoogleFonts.cairo(color: const Color(0xFFD4AF37), fontSize:10, fontWeight: FontWeight.bold))), const SizedBox(width:4), Text(l, style: GoogleFonts.cairo(color: Colors.white70, fontSize:9))]);
  Widget _arrow()=> const Padding(padding: EdgeInsets.symmetric(horizontal:4), child: Icon(Icons.arrow_back_rounded, size:10, color: Colors.white38));

  Widget _statsBar(){
    if(_stats.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12,10,12,0),
      child: GridView.count(
        crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 2.4, mainAxisSpacing:6, crossAxisSpacing:6,
        children:[
          _stat('إجمالي الطلبات','${_money(_stats['TotalAmount']??0)} ج', const Color(0xFF1A2842)),
          _stat('قيد المراجعة','${_stats['ReviewCount']??0}', const Color(0xFFFB923C)),
          _stat('معتمد','${_stats['ApprovedCount']??0}', const Color(0xFF2563EB)),
          _stat('مدفوع','${_stats['PaidCount']??0}', const Color(0xFF10B981)),
          _stat('مرفوض','${_stats['RejectedCount']??0}', const Color(0xFFEF4444)),
          _stat('ملغي','${_stats['CancelledCount']??0}', const Color(0xFF64748B)),
        ],
      ),
    );
  }
  Widget _stat(String label,String value, Color c)=> Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))), child: Column(children:[Text(label, style: GoogleFonts.cairo(color: const Color(0xFF64748B), fontSize:8)), Text(value, style: GoogleFonts.cairo(color: c, fontSize:11, fontWeight: FontWeight.w900))]));

  Widget _form(){
    return Container(
      margin: const EdgeInsets.fromLTRB(12,10,12,0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: ExpansionTile(
        initiallyExpanded: _formExpanded,
        onExpansionChanged: (v)=>setState(()=>_formExpanded=v),
        title: Text('طلب دفعة جديدة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize:12)),
        subtitle: Text('مكافأة منفصلة أو عمولة منفصلة — تُصرف من الخزينة مباشرة', style: GoogleFonts.cairo(fontSize:9, color: Colors.grey)),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children:[
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(value: _paymentType, decoration: InputDecoration(labelText: 'نوع الدفعة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), items: const [DropdownMenuItem(value:'BonusSeparate', child: Text('مكافأة منفصلة')), DropdownMenuItem(value:'CommissionSeparate', child: Text('عمولة منفصلة'))], onChanged: (v)=>setState(()=>_paymentType=v!))),
                const SizedBox(width:8),
                Expanded(child: TextField(controller: _amountCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
              ]),
              const SizedBox(height:8),
              TextField(controller: _descCtrl, decoration: InputDecoration(labelText: 'الوصف/السبب', hintText: 'مثال: مكافأة تحقيق هدف المبيعات', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height:10),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _create, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F172A)), icon: const Icon(Icons.send_rounded, size:14), label: Text('إرسال للمراجعة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _table(){
    if(_items.isEmpty) return Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('لا توجد دفعات', style: GoogleFonts.cairo(color: Colors.grey))));
    return Container(
      margin: const EdgeInsets.fromLTRB(12,10,12,0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(children:[
        Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:8), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(12))), child: Row(children:[Expanded(child: Text('الموظف', style: GoogleFonts.cairo(fontSize:9, color: Colors.grey))), Expanded(child: Text('المبلغ', style: GoogleFonts.cairo(fontSize:9, color: Colors.grey))), Expanded(child: Text('الحالة', style: GoogleFonts.cairo(fontSize:9, color: Colors.grey)))])),
        ..._items.map((r){
          final status = '${r['PaymentStatus']??''}';
          Color c; if(status.contains('مدفوع')) c=const Color(0xFF10B981); else if(status.contains('معتمد')) c=const Color(0xFF2563EB); else if(status.contains('مراجعة')) c=const Color(0xFFFB923C); else c=Colors.grey;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal:12, vertical:10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.08)))),
            child: Row(children:[
              Expanded(child: Text('${r['EmployeeName']??''}', style: GoogleFonts.cairo(fontSize:10, fontWeight: FontWeight.bold))),
              Expanded(child: Text('${_money(r['NetSalary']??r['Amount']??r['OffAmount']??0)} ج', style: GoogleFonts.cairo(fontSize:10, fontWeight: FontWeight.bold, color: const Color(0xFFD4AF37)))),
              Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(status, style: GoogleFonts.cairo(fontSize:8, color: c), textAlign: TextAlign.center))),
            ]),
          );
        }),
      ]),
    );
  }
}
