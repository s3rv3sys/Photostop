//
//  CameraPreviewView.swift
//  PhotoStop
//
//  Created by Ishwar Prasad Nagulapalle on 2025-08-29.
//

import SwiftUI
import AVFoundation

/// SwiftUI wrapper for AVCaptureVideoPreviewLayer
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect.zero)
        view.backgroundColor = UIColor.black
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Remove existing preview layer
        uiView.layer.sublayers?.removeAll(where: { $0 is AVCaptureVideoPreviewLayer })
        
        guard let session = session else {
            // Show placeholder when no session
            addPlaceholderView(to: uiView)
            return
        }
        
        // Create and configure preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = uiView.bounds
        previewLayer.videoGravity = .resizeAspectFill
        
        uiView.layer.addSublayer(previewLayer)
        
        // Update frame when view bounds change
        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
        }
    }
    
    private func addPlaceholderView(to view: UIView) {
        // Remove existing placeholder
        view.subviews.forEach { $0.removeFromSuperview() }
        
        let placeholderView = UIView()
        placeholderView.backgroundColor = UIColor.systemGray6
        placeholderView.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView(image: UIImage(systemName: "camera.fill"))
        imageView.tintColor = UIColor.systemGray3
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = "Camera Preview"
        label.textColor = UIColor.systemGray3
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        placeholderView.addSubview(imageView)
        placeholderView.addSubview(label)
        view.addSubview(placeholderView)
        
        NSLayoutConstraint.activate([
            // Placeholder view constraints
            placeholderView.topAnchor.constraint(equalTo: view.topAnchor),
            placeholderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Image view constraints
            imageView.centerXAnchor.constraint(equalTo: placeholderView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: placeholderView.centerYAnchor, constant: -20),
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),
            
            // Label constraints
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: placeholderView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: placeholderView.trailingAnchor, constant: -20)
        ])
    }
}

/// Preview layer coordinator for handling session changes
class CameraPreviewCoordinator: NSObject {
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    func updateSession(_ session: AVCaptureSession?) {
        previewLayer?.session = session
    }
}

#Preview {
    CameraPreviewView(session: nil)
        .frame(width: 300, height: 400)
        .cornerRadius(12)
}

