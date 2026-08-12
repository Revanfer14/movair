//
//  HomeView.swift
//  movair
//
//  Created by Revan Ferdinand on 12/08/26.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack {
            Image(systemName: "map")
                .resizable()
                .frame(width: 70, height: 70)
                .padding()
                .foregroundStyle(.red)
            
            Text("MovAir")
                .font(Font.largeTitle.bold())
                .foregroundColor(.blue)
                .padding()
        }
    }
}

#Preview {
    HomeView()
}
