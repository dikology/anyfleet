import Testing
@testable import anyfleet

@Suite("Charter components render")
struct CharterComponentsTests {
    
    @Test("DateRangeSection builds")
    func dateRange_builds() {
        let view = DateRangeSection(
            startDate: .constant(Date()),
            endDate: .constant(Date().addingTimeInterval(86_400)),
            nights: 1
        )
        _ = view.body
    }
    
    @Test("RegionPickerSection builds")
    func regionPicker_builds() {
        let view = RegionPickerSection(
            selectedRegion: .constant(CharterFormState.regionOptions.first?.name ?? ""),
            regions: CharterFormState.regionOptions
        )
        _ = view.body
    }
    
    @Test("CharterSummaryCard builds")
    func summaryCard_builds() {
        let view = CharterSummaryCard(form: .mock, progress: 0.5, onCreate: {})
        _ = view.body
    }
}

