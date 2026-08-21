import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/company/models/company_directory_entry.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/core/routing/app_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application_1/core/utils/image_provider_utils.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class CompanySelectionScreen extends ConsumerStatefulWidget {
  const CompanySelectionScreen({super.key});

  @override
  ConsumerState<CompanySelectionScreen> createState() =>
      _CompanySelectionScreenState();
}

class _CompanySelectionScreenState
    extends ConsumerState<CompanySelectionScreen> {
  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to ensure the widget tree is built before updating state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompanies();
    });
  }

  Future<void> _loadCompanies() async {
    await ref.read(employeeProvider.notifier).loadAvailableCompanies();
  }

  Future<void> _selectCompany(String companyId) async {
    try {
      // Link employee to company
      await ref.read(employeeProvider.notifier).linkToCompany(companyId);

      // Show success message with the updated wording
      if (mounted) {
        final companyName =
            ref.read(employeeProvider).company?.companyName ??
            'the selected company';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Your request to be added as an employee under $companyName has been submitted to management for verification.',
            ),
            backgroundColor: MlTokens.green600,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Force refresh the employee state to ensure it's updated. The link has
      // already been made server-side, so leaving early costs nothing — while
      // reading `ref` on a disposed screen throws `StateError`.
      if (!mounted) return;
      final authState = ref.read(authStateProvider);
      if (authState.user != null) {
        await ref
            .read(employeeProvider.notifier)
            .loadEmployeeProfile(authState.user!.id);
      }

      // Navigate to home screen (which will show the waiting screen)
      if (mounted) {
        AppRouter.router.go('/home');
      }
    } catch (e) {
      // Show error if linking fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Could not link to that company. ${friendlyError(e)}'),
            backgroundColor: MlTokens.red600,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select your company'),
        automaticallyImplyLeading: false,
      ),
      body: state.isLoading
          ? Center(
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: MlTokens.accent,
                size: 50,
              ),
            )
          : state.availableCompanies.isEmpty
          ? _buildEmptyState()
          : _buildCompanyList(state.availableCompanies),
    );
  }

  Widget _buildEmptyState() {
    return MlEmptyState(
      icon: Icons.business_outlined,
      title: 'No companies found',
      message: 'Please try again later or contact support.',
      action: MlButton.outline(
        label: 'Refresh',
        icon: Icons.refresh,
        onPressed: _loadCompanies,
      ),
    );
  }

  Widget _buildCompanyList(List<CompanyDirectoryEntry> companies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 6),
          child: Builder(
            builder: (context) => Text(
              'Please select the company you work for:',
              style: context.mlText.titleMedium.copyWith(
                color: MlSemantic.of(context).textMuted,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            itemCount: companies.length,
            itemBuilder: (context, index) {
              final company = companies[index];
              final semantic = MlSemantic.of(context);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: MlCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      company.logoUrl != null
                          ? _buildCompanyLogo(company.logoUrl!)
                          : const MlIconWell(
                              icon: Icons.business,
                              tone: MlTone.accent,
                              size: 50,
                              radius: 14,
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
                              company.orgType.label,
                              style: context.mlText.bodyMedium.copyWith(
                                color: semantic.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      MlButton.primary(
                        label: 'Select',
                        compact: true,
                        onPressed: () => _selectCompany(company.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyLogo(String value) {
    final bytes = decodeDataUriImage(value);
    if (bytes != null) {
      return ClipRRect(
        borderRadius: MlShape.radiusLarge,
        child: Image.memory(bytes, width: 50, height: 50, fit: BoxFit.cover),
      );
    }

    return ClipRRect(
      borderRadius: MlShape.radiusLarge,
      child: CachedNetworkImage(
        imageUrl: value,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        placeholder: (context, url) => const MlIconWell(
          icon: Icons.business,
          tone: MlTone.accent,
          size: 50,
          radius: 14,
        ),
        errorWidget: (context, url, error) => const MlIconWell(
          icon: Icons.error_outline,
          tone: MlTone.error,
          size: 50,
          radius: 14,
        ),
      ),
    );
  }
}
