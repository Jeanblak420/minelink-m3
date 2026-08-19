// Script to execute the SQL migration for adding status column to employees table
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Supabase configuration
const supabaseUrl = 'https://kkcseqmpgzzrogatdoqi.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtrY3NlcW1wZ3p6cm9nYXRkb3FpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYzODM4ODcsImV4cCI6MjA2MTk1OTg4N30.G126pc4J8Xi4S5cVAgAtSrboaZyJ-1p7x5fYiN6VRII';

// Initialize Supabase client
const supabase = createClient(supabaseUrl, supabaseKey);

async function executeMigration() {
  try {
    // Read the SQL file
    const sqlFilePath = path.join(__dirname, 'add_status_column_to_employees.sql');
    const sqlContent = fs.readFileSync(sqlFilePath, 'utf8');

    console.log('Executing SQL migration...');
    
    // Execute the SQL query
    const { data, error } = await supabase.rpc('exec_sql', { sql: sqlContent });
    
    if (error) {
      console.error('Error executing migration:', error);
      return;
    }
    
    console.log('Migration executed successfully!');
    console.log('Result:', data);
  } catch (err) {
    console.error('Error:', err);
  }
}

executeMigration();
