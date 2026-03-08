// SupabaseContentAdapter.swift
// Kzu — Live JSON curriculum fetching from Supabase

import Foundation

/// Fetches curriculum units live from Kzu's Supabase backend.
/// The backend serves dynamic JSON which allows bypassing App Store updates
/// for modifying or adding new lessons.
final class SupabaseContentAdapter {
    
    private let supabaseUrl = "https://mwzrqiooiboptswoezfi.supabase.co"
    // Use the anonymous public key for read-only access (RLS protected)
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13enJxaW9vaWJvcHRzd29lemZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3MTM2MDIsImV4cCI6MjA4ODI4OTYwMn0.z5yOOT5P2a8K1M7gN6s5e656A8x9M7fN5fV2oW8JtQs"
    
    /// Fetches a unit matching the grade and subject from the `curriculum_units` table
    func fetchUnit(for grade: Int, subject: Subject) async -> CurriculumUnit? {
        let endpoint = "\(supabaseUrl)/rest/v1/curriculum_units?subject=eq.\(subject.rawValue)&grade_min=lte.\(grade)&grade_max=gte.\(grade)&select=unit_data&limit=1"
        
        guard let url = URL(string: endpoint) else {
            print("SupabaseContentAdapter: Invalid URL format")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("SupabaseContentAdapter: Invalid response type")
                return nil
            }
            
            guard httpResponse.statusCode == 200 else {
                print("SupabaseContentAdapter: HTTP Error \(httpResponse.statusCode)")
                return nil
            }
            
            // Supabase returns an array of rows. We want the `unit_data` from the first row.
            // Shape: [ { "unit_data": { "unitId": "...", "lessons": [...] } } ]
            struct SupabaseRow: Decodable {
                let unitData: CurriculumUnit
                
                enum CodingKeys: String, CodingKey {
                    case unitData = "unit_data"
                }
            }
            
            let decoder = JSONDecoder()
            let rows = try decoder.decode([SupabaseRow].self, from: data)
            
            if let unit = rows.first?.unitData {
                print("SupabaseContentAdapter: Successfully pulled \(!unit.lessons.isEmpty ? String(unit.lessons.count) : "0") lessons from Supabase for \(subject.rawValue) Grade \(grade).")
                return unit
            } else {
                print("SupabaseContentAdapter: No curriculum units found in Supabase for \(subject.rawValue) Grade \(grade).")
                return nil
            }
            
        } catch {
            print("SupabaseContentAdapter: Network request failed: \(error)")
            return nil
        }
    }
}
