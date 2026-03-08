//
//  anyfleetTests.swift
//  anyfleetTests
//
//  Created by Денис on 12/11/25.
//

import Foundation
import Testing
@testable import anyfleet

struct anyfleetTests {
    
    @Test func localization_persistsOverrideAcrossInstances() {
        let key = "app_language"
        UserDefaults.standard.removeObject(forKey: key)
        
        let service = LocalizationService()
        service.setLanguage(.english)
        #expect(service.effectiveLanguage == .english)
        
        let serviceReloaded = LocalizationService()
        #expect(serviceReloaded.effectiveLanguage == .english)
        
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    @Test func actionCard_onTap_callsHandler() {
        var tapped = false
        let sut = ActionCard(
            icon: "sailboat.fill",
            title: "Title",
            subtitle: "Subtitle",
            buttonTitle: "CTA",
            onTap: { tapped = true },
            onButtonTap: {}
        )
        
        sut.onTap()
        #expect(tapped)
    }
    
    @Test func actionCard_cta_callsHandler() {
        var ctaTapped = false
        let sut = ActionCard(
            icon: "sailboat.fill",
            title: "Title",
            subtitle: "Subtitle",
            buttonTitle: "CTA",
            onTap: {},
            onButtonTap: { ctaTapped = true }
        )
        
        sut.onButtonTap()
        #expect(ctaTapped)
    }
}
