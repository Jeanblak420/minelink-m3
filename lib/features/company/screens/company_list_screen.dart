import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/mcp/models/company_model.dart';
import 'package:flutter_application_1/core/mcp/repositories/company_repository.dart';
import 'package:flutter_application_1/core/widgets/infinite_list.dart';
import 'package:flutter_application_1/core/utils/image_provider_utils.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

/// Provider for the company repository
final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepository();
});

/// Provider for the list of companies by organization type
final companiesByOrgTypeProvider =
    FutureProvider.family<List<CompanyMCP>, String>((ref, orgType) async {
      final repository = ref.watch(companyRepositoryProvider);
      return repository.getByOrgType(orgType);
    });

/// A screen that displays a list of companies by organization type
class CompanyListScreen extends ConsumerWidget {
  final OrgType orgType;
  final String title;

  const CompanyListScreen({
    super.key,
    required this.orgType,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _buildCompanyList(context, ref),
    );
  }

  Widget _buildCompanyList(BuildContext context, WidgetRef ref) {
    return InfiniteList<CompanyMCP>(
      fetchItems: (pageKey, pageSize) async {
        final repository = ref.read(companyRepositoryProvider);
        return repository.getByOrgType(
          orgType.name,
          orderBy: 'company_name',
          ascending: true,
          limit: pageSize,
          offset: pageKey * pageSize,
        );
      },
      itemBuilder: (context, company, index) {
        return _buildCompanyItem(context, company);
      },
      emptyWidget: MlEmptyState(
        icon: Icons.business_outlined,
        title: 'No ${orgType.name} companies found',
        message: 'No companies of this type are registered yet.',
      ),
      showDivider: false,
      padding: const EdgeInsets.all(24),
    );
  }

  Widget _buildCompanyItem(BuildContext context, CompanyMCP company) {
    final semantic = MlSemantic.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MlCard(
        padding: const EdgeInsets.all(14),
        onTap: () => context.push(
          '/companies/${company.orgType.name}/${company.id}/details',
          extra: company,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: MlTone.accent.well(Theme.of(context).brightness),
              backgroundImage: imageProviderFromString(company.logoUrl),
              child: company.logoUrl == null
                  ? const Icon(Icons.business, color: MlTokens.accent)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company.companyName,
                    style: TextStyle(
                      fontFamily: MlTokens.fontSans,
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                      color: semantic.textStrong,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    company.whatsappNumber,
                    style: TextStyle(
                      fontFamily: MlTokens.fontMono,
                      fontSize: 12.5,
                      color: semantic.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: semantic.textFaint),
          ],
        ),
      ),
    );
  }
}

/// Loader screen used when the company details route is opened via a deep
/// link (no `extra`). Fetches the company by id, then renders
/// [CompanyDetailsScreen]. Shown briefly during navigation; tapping from the
/// list passes the model directly and skips the fetch.
class CompanyDetailsLoaderScreen extends ConsumerWidget {
  final String companyId;

  const CompanyDetailsLoaderScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(companyRepositoryProvider);
    return FutureBuilder<CompanyMCP>(
      future: repository.getById(companyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Company')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.hasError
                      ? 'Failed to load company:\n${snapshot.error}'
                      : 'Company not found',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return CompanyDetailsScreen(company: snapshot.data!);
      },
    );
  }
}

/// A screen that displays the details of a company
class CompanyDetailsScreen extends StatelessWidget {
  final CompanyMCP company;

  const CompanyDetailsScreen({super.key, required this.company});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(company.companyName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company logo
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: MlTone.accent.well(
                  Theme.of(context).brightness,
                ),
                backgroundImage: imageProviderFromString(company.logoUrl),
                child: company.logoUrl == null
                    ? const Icon(Icons.business, size: 60, color: MlTokens.accent)
                    : null,
              ),
            ),
            const SizedBox(height: 24),

            // Company information
            MlSectionTitle(
              'Company Information',
              icon: Icons.business_outlined,
              // Not a count: this section is one company's record. Its org
              // type is the fact that changes what every field below means,
              // and it is the one thing not repeated as a labelled row.
              meta: company.orgType.name,
            ),
            _buildInfoItem(context, 'Company Name', company.companyName),
            // S8-11. The permanent, system-issued reference. Shown first
            // because it is the thing to quote in a support call — and shown
            // read-only because it is issued and immutable in the database
            // (company_reg_ref_guard), not typed by anyone. Renders nothing
            // for a company that predates the column rather than an empty row.
            if (company.regRef != null)
              _buildInfoItem(context, 'MineLink Reference', company.regRef!),
            _buildInfoItem(context, 'WhatsApp Number', company.whatsappNumber),
            _buildInfoItem(
              context,
              'Organization Type',
              _getOrgTypeLabel(company.orgType),
            ),
            if (company.ceoFirstName != null || company.ceoLastName != null)
              _buildInfoItem(
                context,
                'CEO',
                '${company.ceoFirstName ?? ''} ${company.ceoLastName ?? ''}'
                    .trim(),
              ),
            _buildInfoItem(
              context,
              'Created At',
              _formatDate(company.createdAt),
            ),
            if (company.updatedAt != null)
              _buildInfoItem(
                context,
                'Last Updated',
                _formatDate(company.updatedAt!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String label, String value) {
    final semantic = MlSemantic.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontWeight: FontWeight.w600,
                fontSize: MlTokens.fsBodySm,
                color: semantic.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontWeight: FontWeight.w600,
                fontSize: MlTokens.fsBody,
                color: semantic.textStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getOrgTypeLabel(OrgType orgType) {
    switch (orgType) {
      case OrgType.mineSupplier:
        return 'Mine/Supplier';
      case OrgType.buyer:
        return 'Buyer';
      case OrgType.transporter:
        return 'Transporter';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
