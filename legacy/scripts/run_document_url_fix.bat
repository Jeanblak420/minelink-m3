@echo off
echo Running document URL fix migration...
supabase db push --db-url postgresql://postgres:postgres@localhost:54322/postgres
echo Migration completed!
pause
