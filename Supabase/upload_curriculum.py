#!/usr/bin/env python3
import json
import os
import sys
from supabase import create_client, Client

# --- CONFIGURATION ---
# Replace with your actual Supabase credentials if these ever change
SUPABASE_URL = "https://mwzrqiooiboptswoezfi.supabase.co"
# We need the SERVICE_ROLE key to insert data (it bypasses RLS policies)
# The anon key we use in the iOS app can only READ data. 
# Make sure your real SERVICE_ROLE key is here!
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13enJxaW9vaWJvcHRzd29lemZpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjcxMzYwMiwiZXhwIjoyMDg4Mjg5NjAyfQ.-EV_mJHEe4H_pCk6FCZmSA7knrsfaIZZyPlA0iwHfmE"

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def upload_json(file_path: str):
    """
    Reads a local JSON curriculum file and inserts/updates it in the Supabase 
    curriculum_units table.
    """
    if not os.path.exists(file_path):
        print(f"Error: File '{file_path}' not found.")
        sys.exit(1)

    print(f"Reading {file_path}...")
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Failed to parse JSON: {e}")
        sys.exit(1)

    # Some bundled files are arrays of units (like EarlyEdMath_GK_Mod1.json)
    # Some might be a single object. Normalize to a list.
    units = data if isinstance(data, list) else [data]

    print(f"Found {len(units)} unit(s) to upload.")

    for index, unit in enumerate(units):
        unit_id = unit.get("unitId")
        if not unit_id:
            print(f"Skipping unit {index}: Missing 'unitId'")
            continue
            
        subject = unit.get("subject", "unknown")
        
        # Parse grade range
        grade_range = unit.get("gradeRange", [])
        grade_min = min(grade_range) if grade_range else 0
        grade_max = max(grade_range) if grade_range else 0
        
        visionary_theme = unit.get("visionaryTheme") # Optional

        print(f"Uploading '{unit_id}' (Subject: {subject}, Grades: {grade_min}-{grade_max})...")

        # Upsert the row into Supabase
        paylaod = {
            "unit_id": unit_id,
            "subject": subject,
            "grade_min": grade_min,
            "grade_max": grade_max,
            "visionary_theme": visionary_theme,
            "unit_data": unit  # The entire JSON object goes into the jsonb column!
        }
        
        try:
            # on_conflict="unit_id" ensures that if we upload the same module twice, 
            # it updates the existing row instead of crashing.
            response = supabase.table("curriculum_units").upsert(
                paylaod, 
                on_conflict="unit_id"
            ).execute()
            
            print(f"✅ Successfully uploaded '{unit_id}'!")
            
        except Exception as e:
            print(f"❌ Failed to upload '{unit_id}': {e}")

if __name__ == "__main__":
    print("🚀 Kzu Supabase Curriculum Injector 🚀")
    if len(sys.argv) < 2:
        print("Usage: python3 upload_curriculum.py <path_to_json_file>")
        print("Example: python3 upload_curriculum.py Kzu/Resources/EarlyEdMath_GK_Mod1.json")
        sys.exit(1)
        
    target_file = sys.argv[1]
    upload_json(target_file)
