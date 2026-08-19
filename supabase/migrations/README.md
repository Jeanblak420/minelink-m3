# Supabase Migrations

This directory contains SQL migrations for the application.

## Important Migrations

### 20240901000000_create_broadcast_messages_table.sql

Creates the `broadcast_messages` table for storing broadcast messages used in the application's realtime features.

### 20240902000000_create_cleanup_function.sql

Creates a PostgreSQL function `cleanup_old_broadcast_messages()` that deletes broadcast messages older than 30 days.

## Cleanup Implementation

Cleanup is handled by the PostgreSQL function
`cleanup_old_broadcast_messages()`. The canonical platform no longer carries a
separate edge-function variant for this work.

## Applying Migrations

To apply these migrations, you can:

1. Use the Supabase Dashboard:
   - Go to the SQL Editor
   - Copy and paste the migration file content
   - Run the SQL

2. Use the Supabase CLI:
   ```bash
   npx supabase migration up
   ```

## Manual Cleanup

If you need to manually clean up old broadcast messages, you can run:

```sql
SELECT cleanup_old_broadcast_messages();
```

This will delete all broadcast messages older than 30 days.
