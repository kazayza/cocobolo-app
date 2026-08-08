import 'package:flutter/material.dart';

class CrmSummary extends StatelessWidget {
  final int leads;
  final int followUps;
  final int overdue;
  final VoidCallback? onTap;

  const CrmSummary({
    super.key,
    required this.leads,
    required this.followUps,
    required this.overdue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.hub_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'CRM',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _CrmMetric(
                      label: 'Leads',
                      value: leads,
                    ),
                  ),
                  Expanded(
                    child: _CrmMetric(
                      label: 'متابعات',
                      value: followUps,
                    ),
                  ),
                  Expanded(
                    child: _CrmMetric(
                      label: 'متأخرة',
                      value: overdue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrmMetric extends StatelessWidget {
  final String label;
  final int value;

  const _CrmMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}