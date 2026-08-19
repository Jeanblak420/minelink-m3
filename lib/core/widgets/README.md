# Supabase UI Components

This directory contains reusable UI components that integrate with Supabase.

## Components

### InfiniteList

A list with infinite scrolling capabilities.

```dart
InfiniteList<T>(
  fetchItems: (pageKey, pageSize) async {
    // Fetch items from Supabase
    return items;
  },
  itemBuilder: (context, item, index) {
    // Build item widget
    return ListTile(
      title: Text(item.title),
    );
  },
)
```

### InfiniteGrid

A grid with infinite scrolling capabilities.

```dart
InfiniteGrid<T>(
  fetchItems: (pageKey, pageSize) async {
    // Fetch items from Supabase
    return items;
  },
  itemBuilder: (context, item, index) {
    // Build item widget
    return Card(
      child: Column(
        children: [
          Image.network(item.imageUrl),
          Text(item.title),
        ],
      ),
    );
  },
  crossAxisCount: 2,
)
```

### FileUploadWidget

A widget for uploading files to Supabase storage.

```dart
FileUploadWidget(
  bucketName: 'profile_photos',
  folderPath: 'users/$userId',
  onUploadComplete: (fileUrls) {
    // Handle uploaded files
    print('Uploaded files: $fileUrls');
  },
  imagesOnly: true,
)
```

### AvatarStack

A widget for displaying a stack of user avatars with presence indicators.

```dart
AvatarStack(
  users: [
    AvatarUser(
      id: 'user1',
      name: 'John Doe',
      avatarUrl: 'https://example.com/avatar1.jpg',
      isOnline: true,
    ),
    // More users...
  ],
  maxDisplayed: 3,
)
```

### ChatWidget

A complete chat interface with real-time messaging.

```dart
ChatWidget(
  messages: messages,
  currentUserId: currentUserId,
  onSendMessage: (message, {replyToId}) {
    // Send message to Supabase
  },
  participants: participants,
)
```

## Usage with MCP

These components work seamlessly with the Model Context Protocol (MCP) implementation. For example:

```dart
// Get a repository instance
final companyRepository = CompanyRepository();

// Use it with InfiniteList
InfiniteList<CompanyMCP>(
  fetchItems: (pageKey, pageSize) async {
    return companyRepository.getByOrgType(
      'mineSupplier',
      limit: pageSize,
      offset: pageKey * pageSize,
    );
  },
  itemBuilder: (context, company, index) {
    return ListTile(
      title: Text(company.companyName),
      subtitle: Text(company.whatsappNumber),
    );
  },
)
```

## Benefits

- **Consistent UI**: Standardized components across the application
- **Type Safety**: Full type safety with MCP integration
- **Efficient Data Loading**: Only load data as needed
- **Error Handling**: Built-in error states and retry mechanisms
- **Loading States**: Visual feedback during data loading
- **Responsive Design**: Works well on all screen sizes
