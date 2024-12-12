//
//  MainTabBarView.swift
//  CozySphere
//
//  Created by 少爷只做白日梦 on 2024/12/1.
//
import SwiftUI

struct MainTabBarView: View {
    var body: some View {
        TabView {
            // Dashboard Tab
            DashboardView()
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Dashboard")
                }

            // Data Tab
            DataView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Data")
                }

            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
        }
    }
}

// Preview
struct MainTabBarView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabBarView()
    }
}

