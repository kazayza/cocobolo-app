/// Blazor = Source of Truth for FormName values stored in Notifications.FormName
/// Flutter only maps those keys to mobile screens.
///
/// Prefer RelatedTable + RelatedID when present.
class BlazorFormNames {
  BlazorFormNames._();

  // ── CRM / Leads (as used in Blazor services & menu) ─────────
  static const frmLeadsCrm = 'frm_LeadsCRM';
  static const crmLeads = 'crm/leads';
  static const crmLeadsMy = 'crm/leads/my';
  static const crmOpportunities = 'crm/opportunities';
  static const crmTasks = 'crm/tasks';
  static const crmGeneralTasks = 'crm/general-tasks';
  static const crmClosureRequests = 'crm/opportunities/closure-requests';
  static const crmPipeline = 'crm/pipeline';

  // ── Sales / Invoices (جديدة من بلازور) ───────────────────
  static const salesInvoices = 'sales/invoices';
  static const frmPartiesInvoices = 'frm_PartiesInvoices';
  static const frmSupplierInvoices = 'frm_SupplierInvoices';

  // ── Classic ERP form keys ───────────────────────────────────
  static const frmExpenses = 'frm_Expenses';
  static const frmExpensesList = 'frm_ExpensesList';
  static const frmProducts = 'frm_Products';
  static const frmProductPricing = 'frm_ProductPricing';
  static const frmProductList = 'frm_ProductList';
  static const frmPriceRequests = 'frm_PriceRequests';
  static const frmPricingMargins = 'frm_PricingMargins';
  static const frmComplaintsMain = 'frm_Complaints_Main';
  static const frmInvoiceDelivery = 'frmInvoiceDeliveryStatus';
  static const frmEmpAttendance = 'frm_empAttendance';
  static const frmAttendance = 'frm_Attendance';
  static const frmDailyTasks = 'frmDailyTasks';
  static const frmSalesPipeline = 'frmSalesPipeline';
  static const frmManamgerSales = 'frmManamgerSales';
  static const frmClientCard = 'frmClientCard';
  static const frmCashBoxManual = 'frm_CashBoxManual';
  static const frmCashBoxDashboard = 'frm_CashBoxDashboard';
  static const frmCashBoxTransaction = 'frm_CashBoxTransaction';
  static const frmPermissionsList = 'frm_PermissionsList';
  static const frmMySchedule = 'frm_MySchedule';

  // ── Mobile-era aliases (accept for backward compatibility) ──
  static const aliasLeadDetail = 'lead_detail_screen';
  static const aliasLeadReject = 'lead_reject_approval';
  static const aliasOppDetail = 'opportunity_detail_screen';
  static const aliasAttendance = 'attendance_screen';
}

/// What mobile screen to open
enum MobileNotifTarget {
  leadDetail,
  leadsList,
  opportunityDetail,
  opportunitiesList,
  expensesAdd,
  expensesList,
  products,
  priceRequests,
  pricingMargins,
  complaintsList,
  complaintDetail,
  delivery,
  attendance,
  tasks,
  pipeline,
  clients,
  clientCard,
  cashboxDashboard,
  cashboxManual,
  cashboxTransactions,
  permissions,
  mySchedule,
  invoices,
  notifications,
  home,
}

class NotifRouteDecision {
  final MobileNotifTarget target;
  final int? relatedId;
  final String? relatedTable;
  final String? rawFormName;

  const NotifRouteDecision({
    required this.target,
    this.relatedId,
    this.relatedTable,
    this.rawFormName,
  });
}

/// Resolve Blazor FormName (+ table/id) → mobile target
class BlazorNotificationRouter {
  BlazorNotificationRouter._();

  static NotifRouteDecision resolve({
    String? formName,
    String? relatedTable,
    dynamic relatedId,
  }) {
    final id = _toInt(relatedId);
    final table = (relatedTable ?? '').trim().toLowerCase();
    final form = (formName ?? '').trim();
    final formLower = form.toLowerCase();

    // 1) RelatedTable first (most reliable)
    if (table == 'leadscrm' || table == 'leads') {
      if (id != null && id > 0) {
        return NotifRouteDecision(
          target: MobileNotifTarget.leadDetail,
          relatedId: id,
          relatedTable: relatedTable,
          rawFormName: formName,
        );
      }
      return NotifRouteDecision(
        target: MobileNotifTarget.leadsList,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    if (table == 'salesopportunities' || table == 'opportunities') {
      if (id != null && id > 0) {
        return NotifRouteDecision(
          target: MobileNotifTarget.opportunityDetail,
          relatedId: id,
          relatedTable: relatedTable,
          rawFormName: formName,
        );
      }
      return NotifRouteDecision(
        target: MobileNotifTarget.opportunitiesList,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    if (table == 'expenses') {
      return NotifRouteDecision(
        target: id != null ? MobileNotifTarget.expensesAdd : MobileNotifTarget.expensesList,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    if (table == 'complaints') {
      return NotifRouteDecision(
        target: id != null
            ? MobileNotifTarget.complaintDetail
            : MobileNotifTarget.complaintsList,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    if (table == 'attendance' || table == 'employeeshifts') {
      return NotifRouteDecision(
        target: MobileNotifTarget.attendance,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    // 2) FormName (Blazor keys + aliases)
    // Leads
    if (_match(formLower, [
      BlazorFormNames.frmLeadsCrm,
      BlazorFormNames.crmLeads,
      BlazorFormNames.crmLeadsMy,
      BlazorFormNames.aliasLeadDetail,
      BlazorFormNames.aliasLeadReject,
      'leads',
    ])) {
      // list vs detail: id present → detail
      if (id != null && id > 0) {
        return NotifRouteDecision(
          target: MobileNotifTarget.leadDetail,
          relatedId: id,
          rawFormName: formName,
        );
      }
      return NotifRouteDecision(
        target: MobileNotifTarget.leadsList,
        rawFormName: formName,
      );
    }

    // path style /crm/leads/123
    final leadPath = RegExp(r'crm/leads/(\d+)', caseSensitive: false).firstMatch(form);
    if (leadPath != null) {
      return NotifRouteDecision(
        target: MobileNotifTarget.leadDetail,
        relatedId: int.tryParse(leadPath.group(1)!),
        rawFormName: formName,
      );
    }

    // Opportunities
    if (_match(formLower, [
      BlazorFormNames.crmOpportunities,
      BlazorFormNames.frmManamgerSales,
      BlazorFormNames.aliasOppDetail,
      'opportunity',
    ])) {
      if (id != null && id > 0) {
        return NotifRouteDecision(
          target: MobileNotifTarget.opportunityDetail,
          relatedId: id,
          rawFormName: formName,
        );
      }
      return NotifRouteDecision(
        target: MobileNotifTarget.opportunitiesList,
        rawFormName: formName,
      );
    }

    final oppPath =
        RegExp(r'crm/opportunities/(\d+)', caseSensitive: false).firstMatch(form);
    if (oppPath != null) {
      return NotifRouteDecision(
        target: MobileNotifTarget.opportunityDetail,
        relatedId: int.tryParse(oppPath.group(1)!),
        rawFormName: formName,
      );
    }

    // Pipeline / tasks
    if (_match(formLower, [
      BlazorFormNames.frmSalesPipeline,
      BlazorFormNames.crmPipeline,
      'pipeline',
    ])) {
      return NotifRouteDecision(
        target: MobileNotifTarget.pipeline,
        rawFormName: formName,
      );
    }

    if (_match(formLower, [
      BlazorFormNames.frmDailyTasks,
      BlazorFormNames.crmTasks,
      'tasks',
      'followups',
      'follow-ups',
    ])) {
      // Open unified follow-ups hub (Leads + CRM)
      return NotifRouteDecision(
        target: MobileNotifTarget.tasks,
        relatedId: id,
        rawFormName: formName,
      );
    }

    // Expenses
    if (_match(formLower, [
      BlazorFormNames.frmExpenses,
      BlazorFormNames.frmExpensesList,
    ])) {
      final isList = formLower.contains('list');
      return NotifRouteDecision(
        target: isList
            ? MobileNotifTarget.expensesList
            : MobileNotifTarget.expensesAdd,
        relatedId: id,
        rawFormName: formName,
      );
    }

    // Products / pricing
    if (_match(formLower, [
      BlazorFormNames.frmProducts,
      BlazorFormNames.frmProductPricing,
      BlazorFormNames.frmProductList,
      'products/form',
    ])) {
      return NotifRouteDecision(
        target: MobileNotifTarget.products,
        relatedId: id,
        rawFormName: formName,
      );
    }

    if (_match(formLower, [BlazorFormNames.frmPriceRequests])) {
      return NotifRouteDecision(
        target: MobileNotifTarget.priceRequests,
        rawFormName: formName,
      );
    }

    if (_match(formLower, [BlazorFormNames.frmPricingMargins])) {
      return NotifRouteDecision(
        target: MobileNotifTarget.pricingMargins,
        rawFormName: formName,
      );
    }

    // Complaints
    if (_match(formLower, [BlazorFormNames.frmComplaintsMain, 'complaints'])) {
      return NotifRouteDecision(
        target: id != null
            ? MobileNotifTarget.complaintDetail
            : MobileNotifTarget.complaintsList,
        relatedId: id,
        rawFormName: formName,
      );
    }

    // Delivery
    if (_match(formLower, [BlazorFormNames.frmInvoiceDelivery, 'delivery'])) {
      return NotifRouteDecision(
        target: MobileNotifTarget.delivery,
        rawFormName: formName,
      );
    }

    // Attendance
    if (_match(formLower, [
      BlazorFormNames.frmEmpAttendance,
      BlazorFormNames.frmAttendance,
      BlazorFormNames.aliasAttendance,
      'attendance',
    ])) {
      return NotifRouteDecision(
        target: MobileNotifTarget.attendance,
        rawFormName: formName,
      );
    }

    // Client card
    if (_match(formLower, [BlazorFormNames.frmClientCard, 'clients'])) {
      return NotifRouteDecision(
        target: id != null ? MobileNotifTarget.clientCard : MobileNotifTarget.clients,
        relatedId: id,
        rawFormName: formName,
      );
    }

    // Cashbox
    if (_match(formLower, [BlazorFormNames.frmCashBoxDashboard])) {
      return NotifRouteDecision(
        target: MobileNotifTarget.cashboxDashboard,
        rawFormName: formName,
      );
    }
    if (_match(formLower, [BlazorFormNames.frmCashBoxManual])) {
      return NotifRouteDecision(
        target: MobileNotifTarget.cashboxManual,
        rawFormName: formName,
      );
    }
    if (_match(formLower, [BlazorFormNames.frmCashBoxTransaction])) {
      return NotifRouteDecision(
        target: MobileNotifTarget.cashboxTransactions,
        rawFormName: formName,
      );
    }

    if (_match(formLower, [BlazorFormNames.frmPermissionsList])) {
      return NotifRouteDecision(
        target: MobileNotifTarget.permissions,
        rawFormName: formName,
      );
    }

    if (_match(formLower, [BlazorFormNames.frmMySchedule])) {
      return NotifRouteDecision(
        target: MobileNotifTarget.mySchedule,
        rawFormName: formName,
      );
    }

    // Invoices (جديدة من بلازور)
    if (_match(formLower, [
      BlazorFormNames.salesInvoices,
      BlazorFormNames.frmPartiesInvoices,
      BlazorFormNames.frmSupplierInvoices,
      'invoices',
      'sales/invoices',
    ])) {
      return NotifRouteDecision(
        target: MobileNotifTarget.invoices,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    // Job order (أمر شغل فاتورة) — يفتح الفواتير
    final jobOrderPath = RegExp(r'sales/invoices/\d+/job-order', caseSensitive: false)
        .firstMatch(form);
    if (jobOrderPath != null) {
      return NotifRouteDecision(
        target: MobileNotifTarget.invoices,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    // General tasks (المهام العامة — جديدة من بلازور)
    if (_match(formLower, [BlazorFormNames.crmGeneralTasks, 'general-tasks'])) {
      return NotifRouteDecision(
        target: MobileNotifTarget.tasks,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    // Closure requests (طلبات إغلاق الفرص — جديدة من بلازور)
    if (_match(formLower, [BlazorFormNames.crmClosureRequests, 'closure-requests'])) {
      return NotifRouteDecision(
        target: MobileNotifTarget.opportunitiesList,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    // Default
    return NotifRouteDecision(
      target: MobileNotifTarget.notifications,
      relatedId: id,
      relatedTable: relatedTable,
      rawFormName: formName,
    );
  }

  static bool _match(String formLower, List<String> keys) {
    for (final k in keys) {
      final kk = k.toLowerCase();
      if (formLower == kk || formLower.contains(kk)) return true;
    }
    return false;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}
