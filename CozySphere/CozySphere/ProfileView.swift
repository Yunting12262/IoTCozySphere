//
//  ProfileView.swift
//  CozySphere
//
//  Created by 少爷只做白日梦 on 2024/12/1.
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Profile Content")
                    .font(.title)
                    .padding()
                Spacer()
            }
            .navigationTitle("Profile")
        }
    }
}

// Preview
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
