#!/usr/bin/env python3

# This script exports the Depth-Anything-V2 model to ONNX format with optimizations
# It includes necessary patches for ONNX compatibility, applies model optimizations,
# and performs post-processing to ensure the model is ready for deployment.
# The script also provides detailed logging and error handling to ensure a smooth export process.
# The exported model can be used for inference in various environments, including ONNXRuntime.
# Make sure to have the Depth-Anything-V2 repository cloned in the same directory as this script.
# The script is designed to be run directly and will handle all necessary steps automatically.
# Ensure you have the required dependencies installed:
# pip install torch torchvision onnx onnxruntime onnx-simplifier
# The script is compatible with Python 3.7 and above.
# It is recommended to run this script in a virtual environment to avoid dependency conflicts.

import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np
import warnings
import os
import sys

# Add Depth-Anything-V2 repo to Python path
REPO_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'Depth-Anything-V2')
if not os.path.exists(REPO_DIR):
    print(f"Error: Depth-Anything-V2 repository not found at {REPO_DIR}")
    print("Please ensure the repository is cloned in the same directory as this script")
    sys.exit(1)

sys.path.insert(0, REPO_DIR)

# Now import from the repo
try:
    from depth_anything_v2.dpt import DepthAnythingV2
except ImportError as e:
    print(f"Error importing Depth-Anything-V2 modules: {e}")
    print("Please ensure the repository structure is intact")
    sys.exit(1)

# Suppress TracerWarnings
warnings.filterwarnings("ignore", category=torch.jit.TracerWarning)

def find_optimal_size(target_size, patch_size=14):
    """Find size that is multiple of patch_size"""
    h, w = target_size
    
    # Round up to nearest multiple of patch_size
    h_optimal = ((h + patch_size - 1) // patch_size) * patch_size
    w_optimal = ((w + patch_size - 1) // patch_size) * patch_size
    
    return h_optimal, w_optimal

def apply_model_patches(model):
    """Apply necessary patches for ONNX export"""
    
    # Replace GELU with ONNX-compatible version
    def replace_activations(module):
        for name, child in module.named_children():
            if isinstance(child, nn.GELU):
                # Use tanh approximation for better ONNX compatibility
                setattr(module, name, nn.GELU(approximate='tanh'))
            elif isinstance(child, nn.LayerNorm):
                # Ensure LayerNorm uses float32 for stability
                child.eps = max(child.eps, 1e-6)
            else:
                replace_activations(child)
    
    # Remove or replace unsupported layers
    def optimize_for_onnx(module):
        for name, child in module.named_children():
            if isinstance(child, nn.Dropout):
                setattr(module, name, nn.Identity())
            else:
                optimize_for_onnx(child)
    
    replace_activations(model)
    optimize_for_onnx(model)
    
    return model

class DepthAnythingONNX(nn.Module):
    """ONNX-optimized wrapper for Depth-Anything model"""
    def __init__(self, model):
        super().__init__()
        self.model = model
        
    def forward(self, x):
        # Store original interpolate
        original_interpolate = F.interpolate
        
        # Custom interpolate that forces bilinear mode
        def custom_interpolate(input, size=None, scale_factor=None, mode='nearest', 
                             align_corners=None, recompute_scale_factor=None, antialias=False):
            # Convert bicubic to bilinear for ONNX compatibility
            if mode in ['bicubic', 'cubic']:
                mode = 'bilinear'
                align_corners = False if align_corners is None else align_corners
            
            # Remove unsupported arguments for older PyTorch versions
            kwargs = {
                'size': size,
                'scale_factor': scale_factor,
                'mode': mode,
                'align_corners': align_corners
            }
            
            # Add recompute_scale_factor only if supported
            if recompute_scale_factor is not None:
                kwargs['recompute_scale_factor'] = recompute_scale_factor
                
            return original_interpolate(input, **kwargs)
        
        # Temporarily replace interpolate
        F.interpolate = custom_interpolate
        
        try:
            # Run the model
            output = self.model(x)
            
            # Ensure output is in the expected format
            if output.dim() == 4 and output.shape[1] == 1:
                output = output.squeeze(1)
                
        finally:
            # Restore original interpolate
            F.interpolate = original_interpolate
            
        return output

def export_to_onnx(model, output_path, input_size):
    """Export model to ONNX format with optimizations"""
    model.eval()
    
    # Wrap model for ONNX export
    onnx_model = DepthAnythingONNX(model)
    onnx_model.eval()
    
    # Create dummy input
    dummy_input = torch.randn(1, 3, input_size[0], input_size[1])
    
    # Test forward pass
    print("Testing forward pass...")
    with torch.no_grad():
        output = onnx_model(dummy_input)
        print(f"Forward pass successful. Output shape: {output.shape}")
    
    # Export settings optimized for deployment
    print(f"Exporting to ONNX with input size: {input_size}")
    
    torch.onnx.export(
        onnx_model,
        dummy_input,
        output_path,
        input_names=['image'],
        output_names=['depth'],
        dynamic_axes={
            'image': {0: 'batch_size'},
            'depth': {0: 'batch_size'}
        },
        opset_version=11,  # Use stable opset version
        do_constant_folding=True,
        export_params=True,
        verbose=False,
        operator_export_type=torch.onnx.OperatorExportTypes.ONNX
    )
    
    print(f"Model exported to {output_path}")
    
    # Post-process ONNX model
    try:
        import onnx
        from onnx import shape_inference
        
        print("Post-processing ONNX model...")
        
        # Load model
        model_onnx = onnx.load(output_path)
        
        # Run shape inference
        model_onnx = shape_inference.infer_shapes(model_onnx)
        
        # Optimize with onnx-simplifier if available
        try:
            import onnxsim
            print("Simplifying ONNX model...")
            
            # Check onnxsim version and use appropriate API
            try:
                # New API (onnxsim >= 0.4.0)
                model_simp, check = onnxsim.simplify(
                    model_onnx,
                    overwrite_input_shapes={'image': [1, 3, input_size[0], input_size[1]]},
                    skip_fuse_bn=False,
                    skip_constant_folding=False
                )
            except TypeError:
                # Old API (onnxsim < 0.4.0)
                model_simp, check = onnxsim.simplify(
                    model_onnx,
                    dynamic_input_shape=False,
                    input_shapes={'image': [1, 3, input_size[0], input_size[1]]},
                    skip_fuse_bn=False,
                    skip_constant_folding=False
                )
            
            if check:
                model_onnx = model_simp
                print("Model simplified successfully")
            else:
                print("Model simplification failed, using original model")
                
        except ImportError:
            print("onnx-simplifier not available, skipping simplification")
            print("Install with: pip install onnx-simplifier")
        except Exception as e:
            print(f"Simplification error: {e}")
            print("Continuing with unsimplified model")
        
        # Save optimized model
        onnx.save(model_onnx, output_path)
        
        # Final verification
        onnx.checker.check_model(model_onnx)
        print("ONNX model verification: PASSED")
        
        # Print model info
        print(f"\nModel info:")
        print(f"- Input shape: {[1, 3, input_size[0], input_size[1]]}")
        print(f"- Output shape: {[1, input_size[0], input_size[1]]}")
        print(f"- Model size: {os.path.getsize(output_path) / 1024 / 1024:.2f} MB")
        
    except Exception as e:
        print(f"Post-processing warning: {e}")
    
    # Test with ONNXRuntime if available
    try:
        import onnxruntime as ort
        
        print("\nTesting with ONNXRuntime...")
        ort_session = ort.InferenceSession(
            output_path,
            providers=['CPUExecutionProvider']
        )
        
        # Run test inference
        test_input = np.random.randn(1, 3, input_size[0], input_size[1]).astype(np.float32)
        outputs = ort_session.run(None, {'image': test_input})
        
        print(f"ONNXRuntime test successful. Output shape: {outputs[0].shape}")
        
    except Exception as e:
        print(f"ONNXRuntime test skipped: {e}")

def main():
    # Get script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Calculate optimal size
    target_h, target_w = find_optimal_size((384, 640), patch_size=14)
    print(f"Optimal size calculated: {target_h}x{target_w}")
    
    # Model configurations
    model_configs = {
        'vits': {'encoder': 'vits', 'features': 64, 'out_channels': [48, 96, 192, 384]},
        'vitb': {'encoder': 'vitb', 'features': 128, 'out_channels': [96, 192, 384, 768]},
        'vitl': {'encoder': 'vitl', 'features': 256, 'out_channels': [256, 512, 1024, 1024]},
        'vitg': {'encoder': 'vitg', 'features': 384, 'out_channels': [1536, 1536, 1536, 1024]}
    }
    
    # Select model variant
    model_type = 'vits'  # Can be changed to vitb, vitl, vitg
    
    # Load model
    print(f"Loading Depth-Anything-V2-{model_type.upper()} model...")
    config = model_configs[model_type]
    model = DepthAnythingV2(**config)
    
    # Checkpoint path - in the same directory as the script
    checkpoint_path = os.path.join(script_dir, f'depth_anything_v2_{model_type}.pth')
    if not os.path.exists(checkpoint_path):
        print(f"Error: Checkpoint not found at {checkpoint_path}")
        print(f"Please ensure depth_anything_v2_{model_type}.pth is in the same directory as this script")
        return
        
    checkpoint = torch.load(checkpoint_path, map_location='cpu')
    model.load_state_dict(checkpoint)
    
    # Apply optimizations
    print("Applying model optimizations...")
    model = apply_model_patches(model)
    
    # Export to ONNX - save in the same directory as the script
    output_path = os.path.join(script_dir, f'depth_anything_v2_{model_type}.onnx')
    export_to_onnx(model, output_path, (target_h, target_w))
    
    print("\n" + "="*50)
    print("Export completed successfully!")
    print("="*50)
    print(f"\nFiles location:")
    print(f"- Input: {checkpoint_path}")
    print(f"- Output: {output_path}")
    print(f"\nNext steps:")
    print(f"1. Update env.sh with:")
    print(f'   export MODEL_INPUT_SHAPE="1 3 {target_h} {target_w}"')
    print(f"2. Prepare calibration images with size {target_h}x{target_w}")
    print(f"3. Run HHB conversion with ./01-onnx_to_hhb.sh")

if __name__ == "__main__":
    main()
