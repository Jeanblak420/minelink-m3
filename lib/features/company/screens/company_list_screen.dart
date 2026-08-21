import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/mcp/models/company_model.dart';
import 'package:flutter_application_1/core/mcp/repository_providers.dart';
import 'package:flutter_application_1/core/widgets/infinite_list.dart';
import 'package:flutter_application_1/core/utils/image_provider_utils.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

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
    // NO `Scaffold(appBar:)` — `/companies/:orgType` is a leaf of the portal
    // `ShellRoute`, whose top bar already carries this same title.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: MlPageHeader(
            title: title,
            description: 'Every company of this type registered on the '
                'platform.',
          ),
        ),
        Expanded(child: _buildCompanyList(context, ref)),
      ],
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
        title: 'No ${orgType.label} companies found',
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
                    style: context.mlText.titleMedium.copyWith(
                      color: semantic.textStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    company.whatsappNumber,
                    style: context.mlText.code(
                      color: semantic.textMuted,
                      size: 13,
                      weight: FontWeight.w400,
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
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return MlEmptyState(
            icon: Icons.domain_disabled_outlined,
            title: 'Company',
            message: snapshot.hasError
                ? 'Failed to load company: ${snapshot.error}'
                : 'Company not found',
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
    // NO SCAFFOLD AND NO APP BAR — this screen is a leaf of the portal
    // `ShellRoute` (`/portal/{org}/company` and `/companies/…/details` both
    // are), so the shell has already drawn a top bar carrying the company's
    // name. Its own `AppBar` put that name on the screen a second time,
    // directly underneath. Photographed 2026-08-21, the same fault the
    // tons-out register had.
    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NO `MlPageHeader` — the identity row below IS the header.
          //
          // The shell's top bar already carries the company's name (see the
          // note above about the removed AppBar), so a page header, an
          // identity row and a "Company Name" row would have printed it four
          // times on one screen. The org TYPE it used to carry moved into the
          // identity row's sub-line, beside the MineLink reference.
          //
          // The logo BESIDE the identity, and the details inside a card.
          //
          // This was a 120px `Center`ed avatar floating alone in the middle of
          // a 1,000px column, with a left-aligned label/value list under it and
          // no card around anything. On a desktop it read as a circle in a
          // no-man's-land: photographed 2026-08-21 on
          // `screen-company-details-desktop-dark`, and it is the one screen in
          // the set that never got the redesign's card vocabulary.
          //
          // An identity row is what every other detail screen in this product
          // uses — the organization detail page, the company mirror, the
          // employee profile.
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: MlTone.accent.well(
                  Theme.of(context).brightness,
                ),
                backgroundImage: imageProviderFromString(company.logoUrl),
                child: company.logoUrl == null
                    ? const Icon(Icons.business,
                        size: 32, color: MlTokens.accent)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      company.companyName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.titleLarge.copyWith(
                        color: MlSemantic.of(context).textStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      company.regRef == null
                          ? company.orgType.label
                          : '${company.orgType.label}  ·  ${company.regRef}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.bodyMedium.copyWith(
                        color: MlSemantic.of(context).textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Company information
          MlSectionTitle(
            'Company Information',
            icon: Icons.business_outlined,
          ),
          MlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoItem(context, 'Company Name', company.companyName),
          // S8-11. The permanent, system-issued reference. Shown first
          // because it is the thing to quote in a support call — and shown
          // read-only because it is issued and immutable in the database
          // (company_reg_ref_guard), not typed by anyone. Renders nothing
          // for a company that predates the column rather than an empty row.
          if (company.regRef != null)
            _buildInfoItem(context, 'MineLink Reference', company.regRef!),
          _buildInfoItem(context, 'WhatsApp Number', company.whatsappNumber),
          // `OrgType.label`, not a fourth private switch. This file carried
          // its own `_getOrgTypeLabel`, the organisation detail screen carried
          // another, and the two did not even agree on the spacing around the
          // slash.
          _buildInfoItem(context, 'Organization Type', company.orgType.label),
          if (company.ceoFirstName != null || company.ceoLastName != null)
            _buildInfoItem(
              context,
              'CEO',
              '${company.ceoFirstName ?? ''} ${company.ceoLastName ?? ''}'
                  .trim(),
            ),
          // `MlTime.stamp`, not a hand-rolled `d/M/yyyy H:mm`. The old one was
          // an eighth spelling of a moment in time, it printed the RAW
          // instant with no conversion to the mine's clock, and it did not pad
          // the hour — so a company created at 09:05 SAST read "7:5".
                _buildInfoItem(
                    context, 'Created At', MlTime.stamp(company.createdAt)),
                if (company.updatedAt != null)
                  _buildInfoItem(
                      context, 'Last Updated', MlTime.stamp(company.updatedAt!)),
              ],
            ),
          ),
          const SizedBox(height: 60),
        ],
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
          // Rides the text scaler. A flat 130px label column under a
          // per-user type size squeezes the VALUE, which is the half a reader
          // is here for — the same fault `MlColumn.minWidth` exists for.
          SizedBox(
            width: MediaQuery.textScalerOf(context).scale(130),
            // A gutter, because a label that exactly fills its column touches
            // the value: "WhatsApp Number+27000000000" with no space between
            // them.
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                label,
                style: context.mlText.titleSmall.copyWith(
                  color: semantic.textMuted,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.mlText.titleMedium.copyWith(
                color: semantic.textStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
