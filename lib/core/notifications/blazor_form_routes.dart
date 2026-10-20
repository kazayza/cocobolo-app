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
  static const crmLostRecovery = 'crm/lost-recovery';
  static const crmLostRecoveryReport = 'crm/lost-recovery/report';
  static const frmLostRecovery = 'frm_LostRecovery';
  static const crmPipeline = 'crm/pipeline';

  // ── Inventory / Stock (مطابقة بلازور) ─────────────────
  static const inventoryTransactions = 'inventory/transactions';
  static const frmStockTransactions = 'frm_StockTransactions';
  static const inventoryWarehouses = 'inventory/warehouses';
  static const frmWarehouses = 'frm_Warehouses';
  static const inventoryStockEntry = 'inventory/stock-entry';
  static const frmStockEntry = 'frm_StockEntry';
  static const inventoryStockTransfer = 'inventory/stock-transfer';
  static const frmStockTransfer = 'frm_StockTransfer';

  // ── Sales / Invoices (جديدة من بلازور) ───────────────────
  static const salesInvoices = 'sales/invoices';
  static const frmPartiesInvoices = 'frm_PartiesInvoices';
  static const frmSupplierInvoices = 'frm_SupplierInvoices';
  static const salesDeliveryStatus = 'sales-delivery-status';
  static const productionJobOrders = 'production/job-orders';
  static const quotations = 'quotations';
  static const salesQuotations = 'sales/quotations';
  static const frmQuotationsList = 'frmQuotationsList';
  static const frmNewQuotation = 'frmNewQuotation';
  static const frmJobOrders = 'frm_JobOrders';
  static const factoryJobOrders = 'factory/job-orders';
  static const purchaseReceiptStatus = 'purchase-receipt-status';

  // ── Classic ERP form keys ───────────────────────────────────
  static const frmExpenses = 'frm_Expenses';
  static const frmExpensesList = 'frm_ExpensesList';
  static const frmProducts = 'frm_Products';
  static const frmProductPricing = 'frm_ProductPricing';
  static const frmProductList = 'frm_ProductList';
  static const frmPriceRequests = 'frm_PriceRequests';
  static const frmPriceList = 'frm_PriceList';
  static const productsPriceList = 'products/price-list';
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
  closureRequests,
  generalTasks,
  lostRecovery,
  lostRecoveryReport,
  expensesAdd,
  expensesList,
  products,
  productDetail,
  priceRequests,
  priceList,
  quotationsList,
  quotationDetail,
  jobOrders,
  jobOrderDetail,
  pricingMargins,
  complaintsList,
  complaintDetail,
  delivery,
  deliveryDetail,
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
  invoiceDetail,
  stockTransactions,
  warehouses,
  stockTransfer,
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
    final formLower = form.toLowerCase().replaceFirst(RegExp(r'^/+'), '');
    final invoicePathMatch = RegExp(
      r'(?:sales/invoices|sales-delivery-status|factory/purchases)/(\d+)',
      caseSensitive: false,
    ).firstMatch(formLower);
    final invoiceId = id ??
        (invoicePathMatch == null
            ? null
            : int.tryParse(invoicePathMatch.group(1)!));

    // المسارات المتخصصة أولاً؛ FormName يحدد سياق الـID أحياناً أدق من RelatedTable.
    if (formLower.contains('closure-requests') ||
        table == 'opportunityclosureapprovalrequests') {
      return NotifRouteDecision(
        target: MobileNotifTarget.closureRequests,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    if (formLower.contains('sales/price-requests') ||
        formLower == BlazorFormNames.frmPriceRequests.toLowerCase()) {
      return NotifRouteDecision(
        target: MobileNotifTarget.priceRequests,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    if (formLower.contains('products/price-list') ||
        formLower.contains('sales/price-list') ||
        formLower == BlazorFormNames.frmPriceList.toLowerCase()) {
      return NotifRouteDecision(
        target: MobileNotifTarget.priceList,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    if (formLower == BlazorFormNames.quotations ||
        formLower.contains('sales/quotations') ||
        formLower == BlazorFormNames.frmQuotationsList.toLowerCase() ||
        formLower == BlazorFormNames.frmNewQuotation.toLowerCase()) {
      return NotifRouteDecision(
        target: id != null && id > 0
            ? MobileNotifTarget.quotationDetail
            : MobileNotifTarget.quotationsList,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    if (formLower == BlazorFormNames.productionJobOrders ||
        formLower == BlazorFormNames.factoryJobOrders ||
        formLower == BlazorFormNames.frmJobOrders.toLowerCase()) {
      return NotifRouteDecision(
        target: id != null && id > 0
            ? MobileNotifTarget.jobOrderDetail
            : MobileNotifTarget.jobOrders,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    if (formLower.contains('lost-recovery/report')) {
      return NotifRouteDecision(
        target: MobileNotifTarget.lostRecoveryReport,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }
    if (formLower.contains('lost-recovery') ||
        formLower == BlazorFormNames.frmLostRecovery.toLowerCase()) {
      return NotifRouteDecision(
        target: MobileNotifTarget.lostRecovery,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    if (formLower.contains('sales-delivery-status')) {
      return NotifRouteDecision(
        target: invoiceId != null
            ? MobileNotifTarget.deliveryDetail
            : MobileNotifTarget.delivery,
        relatedId: invoiceId,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    if (formLower.contains('sales/invoices') ||
        formLower.contains('factory/purchases')) {
      return NotifRouteDecision(
        target: invoiceId != null
            ? MobileNotifTarget.invoiceDetail
            : MobileNotifTarget.invoices,
        relatedId: invoiceId,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    // 1) RelatedTable بعد المسارات المتخصصة
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

    if (table == 'transactions') {
      return NotifRouteDecision(
        target: invoiceId != null
            ? MobileNotifTarget.invoiceDetail
            : MobileNotifTarget.invoices,
        relatedId: invoiceId,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    if (table == 'quotations') {
      return NotifRouteDecision(
        target: id != null && id > 0
            ? MobileNotifTarget.quotationDetail
            : MobileNotifTarget.quotationsList,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    if (table == 'products') {
      return NotifRouteDecision(
        target: id != null
            ? MobileNotifTarget.productDetail
            : MobileNotifTarget.products,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    if (table == 'parties' || table == 'customers') {
      return NotifRouteDecision(
        target: id != null
            ? MobileNotifTarget.clientCard
            : MobileNotifTarget.clients,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    if (table == 'stocktransactions') {
      return NotifRouteDecision(
        target: MobileNotifTarget.stockTransactions,
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
        target: id != null
            ? MobileNotifTarget.productDetail
            : MobileNotifTarget.products,
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
        target: id != null
            ? MobileNotifTarget.deliveryDetail
            : MobileNotifTarget.delivery,
        relatedId: id,
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
        target: id != null
            ? MobileNotifTarget.invoiceDetail
            : MobileNotifTarget.invoices,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    // Job order (أمر شغل فاتورة) — يفتح الفاتورة المرتبطة
    final jobOrderPath = RegExp(r'sales/invoices/\d+/job-order', caseSensitive: false)
        .firstMatch(form);
    if (jobOrderPath != null) {
      return NotifRouteDecision(
        target: id != null
            ? MobileNotifTarget.invoiceDetail
            : MobileNotifTarget.invoices,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    // General tasks (المهام العامة — جديدة من بلازور)
    if (_match(formLower, [BlazorFormNames.crmGeneralTasks, 'general-tasks', 'general_tasks'])) {
      return NotifRouteDecision(
        target: MobileNotifTarget.generalTasks,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    // Closure requests (طلبات إغلاق الفرص — جديدة من بلازور)
    if (_match(formLower, [BlazorFormNames.crmClosureRequests, 'closure-requests', 'closureapproval', 'closure-approval', 'opportunityclosure'])) {
      // لو Table هو طلبات الإغلاق → افتح شاشة طلبات الإغلاق للمدير
      if (table == 'opportunityclosureapprovalrequests' || formLower.contains('closure-requests')) {
        return NotifRouteDecision(
          target: MobileNotifTarget.closureRequests,
          relatedId: id,
          relatedTable: relatedTable,
          rawFormName: formName,
        );
      }
      return NotifRouteDecision(
        target: MobileNotifTarget.opportunityDetail,
        relatedId: id,
        relatedTable: 'SalesOpportunities',
        rawFormName: formName,
      );
    }

    // Lost Recovery (استرداد الفرص الخاسرة — جديد من بلازور 98a5746)
    if (_match(formLower, [BlazorFormNames.crmLostRecovery, BlazorFormNames.frmLostRecovery, 'lost-recovery', 'lostrecovery', 'recovery'])) {
      if (formLower.contains('report')) {
        return NotifRouteDecision(
          target: MobileNotifTarget.lostRecoveryReport,
          relatedId: id,
          relatedTable: relatedTable,
          rawFormName: formName,
        );
      }
      if (id != null && id > 0 && (table == 'salesopportunities' || formLower.contains('opportunities'))) {
        return NotifRouteDecision(
          target: MobileNotifTarget.opportunityDetail,
          relatedId: id,
          relatedTable: 'SalesOpportunities',
          rawFormName: formName,
        );
      }
      return NotifRouteDecision(
        target: MobileNotifTarget.lostRecovery,
        relatedId: id,
        relatedTable: relatedTable,
        rawFormName: formName,
      );
    }

    // Inventory / Stock
    if (_match(formLower, [BlazorFormNames.inventoryTransactions, BlazorFormNames.frmStockTransactions, 'stocktransactions', 'stock-transactions'])) {
      return NotifRouteDecision(target: MobileNotifTarget.stockTransactions, relatedId: id, relatedTable: relatedTable, rawFormName: formName);
    }
    if (_match(formLower, [BlazorFormNames.inventoryWarehouses, BlazorFormNames.frmWarehouses, 'warehouses'])) {
      return NotifRouteDecision(target: MobileNotifTarget.warehouses, relatedId: id, relatedTable: relatedTable, rawFormName: formName);
    }
    if (_match(formLower, [BlazorFormNames.inventoryStockTransfer, BlazorFormNames.frmStockTransfer, 'inventory/transfer', 'stock-transfer'])) {
      return NotifRouteDecision(target: MobileNotifTarget.stockTransfer, relatedId: id, relatedTable: relatedTable, rawFormName: formName);
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
