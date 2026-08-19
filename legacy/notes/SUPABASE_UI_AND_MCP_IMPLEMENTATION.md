# Supabase UI Components and MCP Implementation

This document provides an overview of the implementation of Supabase UI components, Model Context Protocol (MCP), and Infinite Query Hook in The Mineral Guide application.

## Table of Contents

1. [Model Context Protocol (MCP)](#model-context-protocol-mcp)
2. [Infinite Query Components](#infinite-query-components)
3. [File Upload Component](#file-upload-component)
4. [Avatar Stack Component](#avatar-stack-component)
5. [Chat Component](#chat-component)
6. [Usage Examples](#usage-examples)
7. [Database Schema](#database-schema)

## Model Context Protocol (MCP)

The Model Context Protocol (MCP) implementation provides a standardized way to interact with Supabase data models. It ensures type safety and consistency across the application.

### Core Components

- **SupabaseModel**: Base class for all models
- **SupabaseRepository**: Base repository class for CRUD operations
- **Model Implementations**: Type-safe model classes for Company, Employee, etc.

### Benefits

- **Type Safety**: Reduces runtime errors with strong typing
- **Consistency**: Standardized approach to data handling
- **Maintainability**: Easier to maintain and extend

## Infinite Query Components

The Infinite Query components provide efficient pagination and infinite scrolling for large datasets.

### Components

- **InfiniteList**: A list with infinite scrolling capabilities
- **InfiniteGrid**: A grid with infinite scrolling capabilities

### Features

- **Efficient Pagination**: Only loads data as needed
- **Pull-to-Refresh**: Easy refreshing of data
- **Error Handling**: Built-in error states and retry mechanisms
- **Loading States**: Visual feedback during data loading
- **Empty States**: Customizable empty state displays

## File Upload Component

The File Upload component simplifies the process of uploading files to Supabase storage.

### Features

- **Multiple File Support**: Upload single or multiple files
- **Progress Tracking**: Visual feedback during uploads
- **File Validation**: Size and type validation
- **Preview**: Preview selected files before upload
- **Error Handling**: Clear error messages and recovery options

## Avatar Stack Component

The Avatar Stack component displays user avatars with presence indicators.

### Components

- **AvatarStack**: Displays overlapping avatars with a count indicator
- **AvatarList**: Displays avatars in a horizontal list

### Features

- **Presence Indicators**: Shows online/offline status
- **Customizable**: Adjustable size, overlap, and appearance
- **Efficient**: Handles large numbers of users gracefully
- **Interactive**: Optional tap callbacks for user interaction

## Chat Component

The Chat component provides a complete chat interface with real-time messaging.

### Features

- **Real-time Messages**: Instant message delivery
- **File Attachments**: Support for sharing files and images
- **Typing Indicators**: Shows when users are typing
- **Read Receipts**: Indicates when messages are read
- **Reply Threading**: Support for replying to specific messages
- **User Presence**: Shows which users are online

## Usage Examples

### MCP Models and Repositories

```dart
// Get a company by user ID
final companyRepository = CompanyRepository();
final company = await companyRepository.getByUserId(userId);

// Get employees for a company
final employeeRepository = EmployeeRepository();
final employees = await employeeRepository.getByCompanyId(companyId);
```

### Infinite List

```dart
InfiniteList<CompanyMCP>(
  fetchItems: (pageKey, pageSize) async {
    return repository.getByOrgType(
      orgType.name,
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

### File Upload

```dart
FileUploadWidget(
  bucketName: 'profile_photos',
  folderPath: 'employees',
  onUploadComplete: (fileUrls) {
    if (fileUrls.isNotEmpty) {
      // Update profile photo URL
      updateProfilePhoto(fileUrls[0]);
    }
  },
  imagesOnly: true,
)
```

### Avatar Stack

```dart
AvatarStack(
  users: [
    AvatarUser(
      id: 'user1',
      name: 'John Doe',
      avatarUrl: 'https://example.com/avatar1.jpg',
      isOnline: true,
    ),
    AvatarUser(
      id: 'user2',
      name: 'Jane Smith',
      avatarUrl: 'https://example.com/avatar2.jpg',
      isOnline: false,
    ),
  ],
  maxDisplayed: 3,
  avatarSize: 40,
)
```

### Chat Widget

```dart
ChatWidget(
  messages: messages,
  currentUserId: currentUserId,
  onSendMessage: (message, {replyToId}) {
    // Send message to backend
    sendMessage(message, replyToId: replyToId);
  },
  participants: participants,
  showTypingIndicator: true,
  typingUsers: ['John Doe'],
)
```

## Database Schema

### Chat Tables

```sql
-- Chat rooms table
CREATE TABLE chat_rooms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  participant_ids UUID[] NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_message_content TEXT,
  last_message_timestamp TIMESTAMPTZ,
  last_message_sender_id UUID
);

-- Chat messages table
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chat_room_id UUID REFERENCES chat_rooms(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  sender_id UUID NOT NULL,
  sender_name TEXT NOT NULL,
  sender_avatar_url TEXT,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  is_read BOOLEAN DEFAULT FALSE,
  reply_to_id UUID,
  file_url TEXT,
  file_type TEXT,
  file_name TEXT
);
```

### Row-Level Security Policies

```sql
-- Chat rooms RLS
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their chat rooms" ON chat_rooms
  FOR SELECT USING (
    auth.uid() = ANY(participant_ids)
  );

CREATE POLICY "Users can create chat rooms" ON chat_rooms
  FOR INSERT WITH CHECK (
    auth.uid() = ANY(participant_ids)
  );

-- Chat messages RLS
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view messages in their chat rooms" ON chat_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM chat_rooms
      WHERE id = chat_messages.chat_room_id
      AND auth.uid() = ANY(participant_ids)
    )
  );

CREATE POLICY "Users can send messages to their chat rooms" ON chat_messages
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM chat_rooms
      WHERE id = chat_messages.chat_room_id
      AND auth.uid() = ANY(participant_ids)
    )
    AND auth.uid() = sender_id
  );
```
