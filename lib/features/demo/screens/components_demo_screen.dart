import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/widgets/avatar_stack.dart';
import 'package:flutter_application_1/core/widgets/file_upload_widget.dart';
import 'package:flutter_application_1/core/widgets/infinite_list.dart';
import 'package:flutter_application_1/core/widgets/infinite_grid.dart';
import 'package:flutter_application_1/core/mcp/models/company_model.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// A screen that demonstrates the new UI components
class ComponentsDemoScreen extends ConsumerWidget {
  const ComponentsDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('UI Components Demo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, 'Avatar Stack'),
            _buildAvatarStackDemo(context),

            const SizedBox(height: 32),
            _buildSectionTitle(context, 'File Upload'),
            _buildFileUploadDemo(context),

            const SizedBox(height: 32),
            _buildSectionTitle(context, 'Infinite List & Grid'),
            _buildInfiniteListDemo(context, ref),

            const SizedBox(height: 32),
            _buildSectionTitle(context, 'MCP Navigation'),
            _buildMCPNavigationDemo(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAvatarStackDemo(BuildContext context) {
    final users = [
      AvatarUser(id: '1', name: 'John Doe', isOnline: true),
      AvatarUser(
        id: '2',
        name: 'Jane Smith',
        isOnline: false,
        avatarUrl: 'https://i.pravatar.cc/150?img=1',
      ),
      AvatarUser(
        id: '3',
        name: 'Bob Johnson',
        isOnline: true,
        avatarUrl: 'https://i.pravatar.cc/150?img=2',
      ),
      AvatarUser(id: '4', name: 'Alice Brown', isOnline: false),
      AvatarUser(
        id: '5',
        name: 'Charlie Wilson',
        isOnline: true,
        avatarUrl: 'https://i.pravatar.cc/150?img=3',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Avatar Stack:'),
        const SizedBox(height: 8),
        AvatarStack(
          users: users,
          maxDisplayed: 3,
          avatarSize: 40,
          onAvatarTap: (user) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Tapped on ${user.name}')));
          },
        ),

        const SizedBox(height: 16),
        const Text('Avatar List:'),
        const SizedBox(height: 8),
        AvatarList(
          users: users,
          avatarSize: 40,
          showName: true,
          onAvatarTap: (user) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Tapped on ${user.name}')));
          },
        ),
      ],
    );
  }

  Widget _buildFileUploadDemo(BuildContext context) {
    return FileUploadWidget(
      bucketName: 'demo_files',
      folderPath: 'uploads',
      onUploadComplete: (fileUrls) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded ${fileUrls.length} files')),
        );
      },
      onError: (error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error. ${friendlyError(error)}')));
      },
      buttonText: 'Upload Files',
      imagesOnly: false,
      allowMultiple: true,
    );
  }

  Widget _buildInfiniteListDemo(BuildContext context, WidgetRef ref) {
    // Remove unused repository reference
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Infinite List Demo:'),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: InfiniteList<CompanyMCP>(
            fetchItems: (pageKey, pageSize) async {
              // Simulate network delay
              await Future.delayed(const Duration(milliseconds: 500));

              // Generate demo data
              return List.generate(
                pageSize,
                (index) => CompanyMCP(
                  id: 'company_${pageKey * pageSize + index}',
                  userId: 'user_${pageKey * pageSize + index}',
                  companyName: 'Company ${pageKey * pageSize + index + 1}',
                  whatsappNumber: '+123456789${pageKey * pageSize + index}',
                  orgType: OrgType.values[index % OrgType.values.length],
                  createdAt: DateTime.now().subtract(Duration(days: index)),
                ),
              );
            },
            itemBuilder: (context, company, index) {
              return ListTile(
                title: Text(company.companyName),
                subtitle: Text(company.whatsappNumber),
                trailing: Text(company.orgType.name),
              );
            },
            showDivider: true,
          ),
        ),

        const SizedBox(height: 16),
        const Text('Infinite Grid Demo:'),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: InfiniteGrid<CompanyMCP>(
            fetchItems: (pageKey, pageSize) async {
              // Simulate network delay
              await Future.delayed(const Duration(milliseconds: 500));

              // Generate demo data
              return List.generate(
                pageSize,
                (index) => CompanyMCP(
                  id: 'company_${pageKey * pageSize + index}',
                  userId: 'user_${pageKey * pageSize + index}',
                  companyName: 'Company ${pageKey * pageSize + index + 1}',
                  whatsappNumber: '+123456789${pageKey * pageSize + index}',
                  orgType: OrgType.values[index % OrgType.values.length],
                  createdAt: DateTime.now().subtract(Duration(days: index)),
                ),
              );
            },
            itemBuilder: (context, company, index) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.business,
                        size: 40,
                        color: _getColorForOrgType(company.orgType),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        company.companyName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        company.orgType.name,
                        style: TextStyle(color: MlTokens.slate600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
            crossAxisCount: 3,
            childAspectRatio: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildMCPNavigationDemo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Navigate to MCP-powered screens:'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.business),
              label: const Text('Mine Suppliers'),
              onPressed: () {
                context.go('/companies/mineSupplier');
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.shopping_cart),
              label: const Text('Buyers'),
              onPressed: () {
                context.go('/companies/buyer');
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.local_shipping),
              label: const Text('Transporters'),
              onPressed: () {
                context.go('/companies/transporter');
              },
            ),
          ],
        ),
      ],
    );
  }

  Color _getColorForOrgType(OrgType orgType) {
    switch (orgType) {
      case OrgType.mineSupplier:
        return MlTokens.blue600;
      case OrgType.buyer:
        return MlTokens.green600;
      case OrgType.transporter:
        return MlTokens.orange500;
    }
  }
}
