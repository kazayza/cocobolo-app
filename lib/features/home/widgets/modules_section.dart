import 'package:flutter/material.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../../providers/auth_provider.dart';
import '../../../screens/clients_screen.dart';
import '../../../screens/employees_screen.dart';
import '../../../screens/expenses/expense_dashboard_screen.dart';
import '../../../screens/leads_screen.dart';
import '../../../screens/opportunities_screen.dart';
import '../../../screens/pipeline_screen.dart';
import '../../../screens/price_requests_screen.dart';
import '../../../screens/products_screen.dart';
import '../../../screens/reports/crm_dashboard_screen.dart';
import '../../../screens/tasks_screen.dart';
import '../models/home_dashboard_config.dart';
import 'home_accent.dart';
import 'section_header.dart';

/// شبكة الوحدات — كل وحدة بلونها المميز + توجيه حقيقي للشاشة
class ModulesSection extends StatelessWidget {
  final HomeDashboardConfig config;

  const ModulesSection({super.key, required this.config});

  void _openModule(BuildContext context, HomeDashboardCard card) {
    final auth = AuthProvider();
    final userId = auth.userId;
    final username = auth.username ?? '';
    if (userId == null) return;

    final Widget screen = switch (card.type) {
      HomeDashboardCardType.clients => ClientsScreen(
        userId: userId,
        username: username,
      ),
      HomeDashboardCardType.leads => LeadsScreen(
        userId: userId,
        username: username,
      ),
      HomeDashboardCardType.opportunities => OpportunitiesScreen(
        userId: userId,
        username: username,
      ),
      HomeDashboardCardType.crm => CrmDashboardScreen(
        userId: userId,
        username: username,
      ),
      HomeDashboardCardType.pipeline => PipelineScreen(
        userId: userId,
        username: username,
      ),
      HomeDashboardCardType.inventory => ProductsScreen(
        userId: userId,
        username: username,
      ),
      HomeDashboardCardType.priceRequests => PriceRequestsScreen(
        username: username,
      ),
      HomeDashboardCardType.expenses => ExpenseDashboardScreen(
        userId: userId,
        username: username,
      ),
      HomeDashboardCardType.employees => EmployeesScreen(
        userId: userId,
        username: username,
      ),
      HomeDashboardCardType.tasks => TasksScreen(
        userId: userId,
        username: username,
      ),
    };

    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    if (config.cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'الوحدات',
          subtitle: 'دخول سريع لكل الأقسام المتاحة لك',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final columns = width >= 1400
                ? 5
                : width >= 1000
                ? 4
                : width >= 650
                ? 3
                : 2;

            return GridView.builder(
              itemCount: config.cards.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemBuilder: (context, index) {
                final card = config.cards[index];
                return _ModuleCard(
                  card: card,
                  onTap: () => _openModule(context, card),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final HomeDashboardCard card;
  final VoidCallback onTap;

  const _ModuleCard({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = HomeAccent.of(card.type);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: HomeAccent.tintedSurface(context, accent),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: HomeAccent.border(context, accent)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: HomeAccent.gradient(accent),
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(card.icon, color: Colors.white, size: 23),
              ),
              const Spacer(),
              Text(
                card.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                card.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
