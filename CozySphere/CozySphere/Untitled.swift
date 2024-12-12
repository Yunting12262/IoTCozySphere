//
//  Untitled.swift
//  CozySphere
//
//  Created by 少爷只做白日梦 on 2024/11/22.
//
import SwiftUI

struct NavigationTestView: View {
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink(destination: Text("Destination View")) {
                    Text("Go to Destination")
                        .font(.title)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .navigationTitle("Navigation Test")
        }
    }
}

// 预览
struct NavigationTestView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationTestView()
    }
}

