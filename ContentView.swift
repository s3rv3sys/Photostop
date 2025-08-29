//
//  ContentView.swift
//  PhotoStop
//
//  Created by Esh on 2025-08-29.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main camera view
                CameraView(viewModel: cameraViewModel)
                    .ignoresSafeArea()
                
                // Top navigation bar
                VStack {
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                        .padding(.trailing)
                    }
                    .padding(.top)
                    
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $cameraViewModel.showingResult) {
            if let enhancedImage = cameraViewModel.enhancedImage {
                ResultView(image: enhancedImage, originalImage: cameraViewModel.originalImage)
            }
        }
    }
}

#Preview {
    ContentView()
}

