# Frame Scoring ML Model Training Specification

## Overview
This document describes the training process for the PhotoStop frame scoring model, which evaluates image quality to select the best frame from burst captures.

## Model Architecture
- **Base Model**: MobileNetV3-Small (ImageNet pretrained)
- **Task**: Image Quality Assessment (IQA) regression
- **Output**: Single quality score (0.0 to 1.0, higher is better)
- **Input Size**: 224x224 RGB images
- **Target Platform**: iOS Core ML

## Dataset Requirements

### Primary Datasets
1. **KonIQ-10k**: 10,073 images with Mean Opinion Scores (MOS)
2. **TID2013**: 3,000 distorted images with quality ratings
3. **LIVE IQA**: 982 images with subjective quality scores
4. **SPAQ**: 11,125 smartphone photos with quality annotations

### Synthetic Data Augmentation
Generate additional training data by applying controlled distortions:
- **Blur**: Gaussian blur with σ ∈ [0.5, 3.0]
- **Noise**: Gaussian noise with σ ∈ [5, 50]
- **Compression**: JPEG compression with quality ∈ [10, 95]
- **Exposure**: Brightness adjustment ∈ [-0.5, 0.5]
- **Motion Blur**: Simulated camera shake

### Data Preprocessing
1. Resize images to 224x224 pixels
2. Normalize using ImageNet statistics:
   - Mean: [0.485, 0.456, 0.406]
   - Std: [0.229, 0.224, 0.225]
3. Normalize quality scores to [0, 1] range
4. Apply data augmentation during training

## Training Configuration

### Hyperparameters
- **Learning Rate**: 1e-4 with cosine annealing
- **Batch Size**: 32
- **Epochs**: 50
- **Optimizer**: Adam with weight decay 1e-4
- **Loss Function**: Mean Squared Error (MSE)
- **Validation Split**: 20%

### Training Strategy
1. **Phase 1**: Freeze backbone, train only regression head (10 epochs)
2. **Phase 2**: Fine-tune entire network with lower learning rate (40 epochs)
3. **Early Stopping**: Monitor validation loss with patience=10

## PyTorch Training Script

```python
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset
from torchvision import transforms, models
import pandas as pd
import numpy as np
from PIL import Image
import os
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, pearson_correlation_coefficient
import matplotlib.pyplot as plt

# Set device
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using device: {device}")

# Data transforms
train_transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.RandomHorizontalFlip(p=0.5),
    transforms.RandomRotation(degrees=5),
    transforms.ColorJitter(brightness=0.1, contrast=0.1, saturation=0.1, hue=0.05),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

val_transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

class IQADataset(Dataset):
    """Image Quality Assessment Dataset"""
    
    def __init__(self, csv_file, root_dir, transform=None):
        """
        Args:
            csv_file (str): Path to CSV file with image paths and quality scores
            root_dir (str): Directory with all the images
            transform (callable, optional): Optional transform to be applied on a sample
        """
        self.data = pd.read_csv(csv_file)
        self.root_dir = root_dir
        self.transform = transform
        
    def __len__(self):
        return len(self.data)
    
    def __getitem__(self, idx):
        if torch.is_tensor(idx):
            idx = idx.tolist()
            
        img_path = os.path.join(self.root_dir, self.data.iloc[idx, 0])
        image = Image.open(img_path).convert('RGB')
        quality_score = float(self.data.iloc[idx, 1])
        
        if self.transform:
            image = self.transform(image)
            
        return image, torch.tensor(quality_score, dtype=torch.float32)

class FrameScoringModel(nn.Module):
    """MobileNetV3-Small based frame scoring model"""
    
    def __init__(self, pretrained=True):
        super(FrameScoringModel, self).__init__()
        
        # Load pretrained MobileNetV3-Small
        self.backbone = models.mobilenet_v3_small(pretrained=pretrained)
        
        # Replace classifier with regression head
        in_features = self.backbone.classifier[3].in_features
        self.backbone.classifier = nn.Sequential(
            nn.Linear(in_features, 512),
            nn.ReLU(inplace=True),
            nn.Dropout(0.2),
            nn.Linear(512, 256),
            nn.ReLU(inplace=True),
            nn.Dropout(0.2),
            nn.Linear(256, 1),
            nn.Sigmoid()  # Output between 0 and 1
        )
        
    def forward(self, x):
        return self.backbone(x)

def train_model(model, train_loader, val_loader, num_epochs=50, learning_rate=1e-4):
    """Train the frame scoring model"""
    
    criterion = nn.MSELoss()
    optimizer = optim.Adam(model.parameters(), lr=learning_rate, weight_decay=1e-4)
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=num_epochs)
    
    # Training history
    train_losses = []
    val_losses = []
    val_correlations = []
    
    best_val_loss = float('inf')
    patience = 10
    patience_counter = 0
    
    for epoch in range(num_epochs):
        # Training phase
        model.train()
        train_loss = 0.0
        
        for batch_idx, (images, targets) in enumerate(train_loader):
            images, targets = images.to(device), targets.to(device).unsqueeze(1)
            
            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, targets)
            loss.backward()
            optimizer.step()
            
            train_loss += loss.item()
            
            if batch_idx % 100 == 0:
                print(f'Epoch {epoch+1}/{num_epochs}, Batch {batch_idx}, Loss: {loss.item():.4f}')
        
        # Validation phase
        model.eval()
        val_loss = 0.0
        val_predictions = []
        val_targets = []
        
        with torch.no_grad():
            for images, targets in val_loader:
                images, targets = images.to(device), targets.to(device).unsqueeze(1)
                outputs = model(images)
                loss = criterion(outputs, targets)
                val_loss += loss.item()
                
                val_predictions.extend(outputs.cpu().numpy().flatten())
                val_targets.extend(targets.cpu().numpy().flatten())
        
        # Calculate metrics
        avg_train_loss = train_loss / len(train_loader)
        avg_val_loss = val_loss / len(val_loader)
        val_correlation = np.corrcoef(val_predictions, val_targets)[0, 1]
        
        train_losses.append(avg_train_loss)
        val_losses.append(avg_val_loss)
        val_correlations.append(val_correlation)
        
        print(f'Epoch {epoch+1}/{num_epochs}:')
        print(f'  Train Loss: {avg_train_loss:.4f}')
        print(f'  Val Loss: {avg_val_loss:.4f}')
        print(f'  Val Correlation: {val_correlation:.4f}')
        print(f'  Learning Rate: {scheduler.get_last_lr()[0]:.6f}')
        print('-' * 50)
        
        # Early stopping
        if avg_val_loss < best_val_loss:
            best_val_loss = avg_val_loss
            patience_counter = 0
            # Save best model
            torch.save(model.state_dict(), 'best_frame_scoring_model.pth')
        else:
            patience_counter += 1
            
        if patience_counter >= patience:
            print(f'Early stopping at epoch {epoch+1}')
            break
            
        scheduler.step()
    
    return train_losses, val_losses, val_correlations

def evaluate_model(model, test_loader):
    """Evaluate the trained model"""
    model.eval()
    predictions = []
    targets = []
    
    with torch.no_grad():
        for images, target in test_loader:
            images = images.to(device)
            outputs = model(images)
            predictions.extend(outputs.cpu().numpy().flatten())
            targets.extend(target.numpy().flatten())
    
    # Calculate metrics
    mse = mean_squared_error(targets, predictions)
    correlation = np.corrcoef(predictions, targets)[0, 1]
    
    print(f'Test Results:')
    print(f'  MSE: {mse:.4f}')
    print(f'  RMSE: {np.sqrt(mse):.4f}')
    print(f'  Correlation: {correlation:.4f}')
    
    return predictions, targets

def export_to_onnx(model, output_path='frame_scoring.onnx'):
    """Export trained model to ONNX format"""
    model.eval()
    dummy_input = torch.randn(1, 3, 224, 224).to(device)
    
    torch.onnx.export(
        model,
        dummy_input,
        output_path,
        export_params=True,
        opset_version=11,
        do_constant_folding=True,
        input_names=['image'],
        output_names=['quality_score'],
        dynamic_axes={
            'image': {0: 'batch_size'},
            'quality_score': {0: 'batch_size'}
        }
    )
    print(f'Model exported to {output_path}')

def main():
    """Main training pipeline"""
    
    # Load datasets (assuming CSV format: image_path, quality_score)
    print("Loading datasets...")
    
    # Create datasets
    train_dataset = IQADataset('train.csv', 'train_images', transform=train_transform)
    val_dataset = IQADataset('val.csv', 'val_images', transform=val_transform)
    test_dataset = IQADataset('test.csv', 'test_images', transform=val_transform)
    
    # Create data loaders
    train_loader = DataLoader(train_dataset, batch_size=32, shuffle=True, num_workers=4)
    val_loader = DataLoader(val_dataset, batch_size=32, shuffle=False, num_workers=4)
    test_loader = DataLoader(test_dataset, batch_size=32, shuffle=False, num_workers=4)
    
    print(f"Train samples: {len(train_dataset)}")
    print(f"Validation samples: {len(val_dataset)}")
    print(f"Test samples: {len(test_dataset)}")
    
    # Initialize model
    model = FrameScoringModel(pretrained=True).to(device)
    print(f"Model parameters: {sum(p.numel() for p in model.parameters()):,}")
    
    # Train model
    print("Starting training...")
    train_losses, val_losses, val_correlations = train_model(
        model, train_loader, val_loader, num_epochs=50, learning_rate=1e-4
    )
    
    # Load best model for evaluation
    model.load_state_dict(torch.load('best_frame_scoring_model.pth'))
    
    # Evaluate on test set
    print("Evaluating on test set...")
    predictions, targets = evaluate_model(model, test_loader)
    
    # Export to ONNX
    print("Exporting to ONNX...")
    export_to_onnx(model)
    
    # Plot training curves
    plt.figure(figsize=(15, 5))
    
    plt.subplot(1, 3, 1)
    plt.plot(train_losses, label='Train Loss')
    plt.plot(val_losses, label='Validation Loss')
    plt.xlabel('Epoch')
    plt.ylabel('MSE Loss')
    plt.legend()
    plt.title('Training and Validation Loss')
    
    plt.subplot(1, 3, 2)
    plt.plot(val_correlations)
    plt.xlabel('Epoch')
    plt.ylabel('Correlation')
    plt.title('Validation Correlation')
    
    plt.subplot(1, 3, 3)
    plt.scatter(targets, predictions, alpha=0.5)
    plt.plot([0, 1], [0, 1], 'r--')
    plt.xlabel('True Quality Score')
    plt.ylabel('Predicted Quality Score')
    plt.title('Test Set Predictions')
    
    plt.tight_layout()
    plt.savefig('training_results.png', dpi=300, bbox_inches='tight')
    plt.show()
    
    print("Training completed!")

if __name__ == "__main__":
    main()
```

## Core ML Conversion

After training, convert the ONNX model to Core ML format:

```python
import coremltools as ct
import numpy as np

# Load ONNX model
onnx_model = ct.converters.onnx.convert(
    model='frame_scoring.onnx',
    inputs=[ct.ImageType(name='image', shape=(1, 3, 224, 224))],
    outputs=[ct.TensorType(name='quality_score', shape=(1, 1))]
)

# Set model metadata
onnx_model.short_description = "PhotoStop Frame Scoring Model"
onnx_model.author = "PhotoStop Team"
onnx_model.license = "MIT"
onnx_model.version = "1.0"

# Set input/output descriptions
onnx_model.input_description['image'] = "Input image for quality assessment"
onnx_model.output_description['quality_score'] = "Quality score between 0.0 and 1.0"

# Save Core ML model
onnx_model.save('FrameScoring.mlmodel')
print("Core ML model saved as FrameScoring.mlmodel")
```

## Model Performance Targets

### Accuracy Metrics
- **Pearson Correlation**: > 0.85 with human ratings
- **RMSE**: < 0.15 on normalized quality scores
- **Inference Time**: < 50ms on iPhone 12 Pro

### Quality Categories
- **Excellent** (0.8-1.0): Sharp, well-exposed, low noise
- **Good** (0.6-0.8): Minor quality issues
- **Fair** (0.4-0.6): Noticeable quality problems
- **Poor** (0.2-0.4): Significant quality issues
- **Very Poor** (0.0-0.2): Severe quality problems

## Deployment Considerations

### Model Optimization
1. **Quantization**: Use 16-bit weights to reduce model size
2. **Pruning**: Remove less important connections
3. **Neural Engine**: Optimize for Apple's Neural Engine

### Fallback Strategy
If Core ML model fails to load or process:
1. Use Laplacian variance for sharpness assessment
2. Analyze brightness histogram for exposure
3. Estimate noise using texture analysis
4. Combine metrics with weighted average

## Validation Protocol

### Test Scenarios
1. **Burst Capture**: 3-5 frames with varying exposure
2. **Motion Blur**: Handheld vs. tripod shots
3. **Lighting Conditions**: Indoor, outdoor, low light
4. **Subject Types**: Portraits, landscapes, macro
5. **Device Variations**: Different iPhone models

### Success Criteria
- Model selects best frame in >90% of burst captures
- Correlation with human preference >0.8
- Consistent performance across device types
- Robust to various shooting conditions

## Future Improvements

### Model Enhancements
1. **Multi-task Learning**: Predict sharpness, exposure, noise separately
2. **Attention Mechanisms**: Focus on important image regions
3. **Temporal Modeling**: Consider frame sequence information
4. **Domain Adaptation**: Fine-tune for smartphone photography

### Data Augmentation
1. **Synthetic Burst Generation**: Create realistic burst sequences
2. **Device-specific Training**: Train on iPhone camera data
3. **User Feedback Integration**: Learn from user selections
4. **Active Learning**: Identify challenging cases for annotation

This specification provides a complete framework for training and deploying the PhotoStop frame scoring model, ensuring high-quality frame selection for the AI enhancement pipeline.

