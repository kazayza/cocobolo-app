# HR Module Update Plan for Flutter App

## Summary
The Flutter app has fully implemented HR screens but the routing still uses placeholders. The user mentions 3 projects (Blazor as base), but Blazor project files are not accessible from this workspace.

## Current State

### HR Screens (Implemented)
| Screen | File | Status |
|--------|------|--------|
| HR Dashboard | `lib/screens/hr/hr_dashboard_screen.dart` | ✓ Implemented |
| Payroll List | `lib/screens/hr/payroll_list_screen.dart` | ✓ Implemented |
| Payslip | `lib/screens/hr/payslip_screen.dart` | ✓ Implemented |
| Loans | `lib/screens/hr/loans_screen.dart` | ✓ Implemented |
| Off Payroll | `lib/screens/hr/off_payroll_screen.dart` | ✓ Implemented |

### Routing Issue
`app_routes.dart:140-143` uses **placeholders** instead of actual screens:
```dart
hrPayroll: (_) => const HrPayrollScreenPlaceholder(),
hrPayslip: (_) => const HrPayslipScreenPlaceholder(),
hrLoans: (_) => const HrLoansScreenPlaceholder(),
hrDashboard: (_) => const HrDashboardScreenPlaceholder(),
```

### Services (Implemented)
- `payroll_service.dart` - API calls for payroll data
- `loan_service.dart` - API calls for loans
- `off_payroll_service.dart` - API calls for off-payroll payments
- `employee_service.dart` - API calls for employees

### Missing/Partially Implemented
1. **HR Dashboard** - Uses hardcoded mock data instead of real API data
2. **Attendance Service** - `attendance_screen.dart` calls API directly instead of using a service
3. **Employee Service** - Referenced but needs verification

## Key Findings

### Filters Currently Available
| Screen | Filters |
|--------|---------|
| Payroll List | Search, Status Dropdown, Month Chips |
| Loans | Status Dropdown, Mode Switcher (loans/installments/statement) |
| Employees | Search, Department Filter, Status Tabs |

### Potential Missing Filters (Needs Blazor Comparison)
- Payroll: Department filter
- Payroll: Employee ID/Number filter
- Loans: Loan type filter
- Off-Payroll: Status filter on table

## Action Items

### High Priority - Fix Routing
1. Update `app_routes.dart:140-143` to use actual screens instead of placeholders

### Medium Priority - Live Data
2. Add `HrDashboardService` for API integration
3. Update `hr_dashboard_screen.dart` to fetch real data

### Low Priority - Missing Filters (NEEDS CLARIFICATION)
4. [PENDING USER INPUT] Add department/employee filters to Payroll List
5. [PENDING USER INPUT] Add loan type filters to Loans screen
6. [PENDING USER INPUT] Add status filters to Off-Payroll table

## Questions for User
1. Where are the Blazor project files located? (Need to compare for missing filters)
2. What specific filter functionality is missing/needed?
3. Should HR Dashboard show real-time data from the API?

## Files to Modify
1. `lib/core/navigation/app_routes.dart` (lines 140-143)
2. `lib/screens/hr/hr_dashboard_screen.dart` (add API service call)
3. Create new service file if needed: `lib/services/hr_dashboard_service.dart`