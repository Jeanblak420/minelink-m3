-- Update storage policies to allow document uploads

-- Create policy for employee document uploads
DROP POLICY IF EXISTS "Employees can upload their own documents" ON storage.objects;
CREATE POLICY "Employees can upload their own documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'employee_assets' AND
  (
    (storage.foldername(name))[1] = 'profile_photos' OR
    (storage.foldername(name))[1] = 'id_documents' OR
    (storage.foldername(name))[1] = 'passport_documents' OR
    (storage.foldername(name))[1] = 'work_visa_documents' OR
    (storage.foldername(name))[1] = 'license_documents'
  ) AND
  EXISTS (
    SELECT 1 FROM employees
    WHERE user_id = auth.uid() AND id::text = (storage.foldername(name))[2]
  )
);

-- Update existing policy for employee profile photos
DROP POLICY IF EXISTS "Employees can upload their own assets" ON storage.objects;
