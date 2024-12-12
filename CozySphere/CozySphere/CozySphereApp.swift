//
//  CozySphereApp.swift
//  CozySphere
//
//  Created by 少爷只做白日梦 on 2024/11/18.
//
import SwiftUI

@main

struct CozySphereApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView() // Replace ContentView with your main view
            MainTabBarView()
            ProfileView()
            DataView()
        }
    }
}
