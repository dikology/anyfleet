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
    
    @Test func localization_returnsEnglishStrings() {
        let service = LocalizationService()
        service.setLanguage(.english)
        #expect(service.localized("home.createCharter.title") == "Ready to sail?")
        #expect(service.localized("home.createCharter.subtitle").isEmpty == false)
        #expect(service.localized("home.createCharter.action") == "Start a charter")
    }
    
    @Test func localization_returnsRussianStrings() {
        let service = LocalizationService()
        service.setLanguage(.russian)
        #expect(service.localized("home.createCharter.title") == "Готовы выйти в море?")
        #expect(service.localized("home.createCharter.subtitle").isEmpty == false)
        #expect(service.localized("home.createCharter.action") == "Начать чартер")
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
