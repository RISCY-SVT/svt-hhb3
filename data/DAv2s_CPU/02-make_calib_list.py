#!/usr/bin/env python3
"""Generate calibration dataset for INT8 quantization of deep learning models.

This script prepares a set of images for model calibration by:
1. Collecting images from a source directory
2. Randomly sampling a specified number of images
3. Resizing them to target dimensions
4. Saving them in a format suitable for calibration
"""

import argparse
import logging
import random
import sys
from pathlib import Path
from typing import List, Optional, Tuple

# Check required dependencies
def check_dependencies():
   """Check if all required dependencies are installed."""
   missing_deps = []
   install_instructions = []
   
   try:
       import cv2
   except ImportError:
       missing_deps.append('opencv-python')
       install_instructions.append('opencv-python')
   
   try:
       import numpy as np
   except ImportError:
       missing_deps.append('numpy')
       install_instructions.append('numpy')
   
   try:
       from tqdm import tqdm
   except ImportError:
       missing_deps.append('tqdm')
       install_instructions.append('tqdm')
   
   if missing_deps:
       print("\nError: Missing required dependencies!\n")
       print(f"The following packages are not installed: {', '.join(missing_deps)}\n")
       print("Please install them using one of the following methods:\n")
       print("1. Using pip:")
       print(f"   pip install {' '.join(install_instructions)}\n")
       print("2. Using conda:")
       print(f"   conda install -c conda-forge {' '.join(install_instructions)}\n")
       print("3. If you're using a virtual environment, make sure it's activated:")
       print("   - For venv: source /path/to/venv/bin/activate")
       print("   - For conda: conda activate your_env_name\n")
       print("4. For a complete installation:")
       print("   pip install opencv-python numpy tqdm\n")
       sys.exit(1)

# Check dependencies before importing
check_dependencies()

# Now import the modules
import cv2
import numpy as np
from tqdm import tqdm


def setup_logging(verbose: bool = False) -> None:
   """Configure logging with appropriate level and format.
   
   Args:
       verbose: If True, set logging level to DEBUG, otherwise INFO.
   """
   level = logging.DEBUG if verbose else logging.INFO
   logging.basicConfig(
       level=level,
       format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
       datefmt='%Y-%m-%d %H:%M:%S'
   )


def parse_arguments() -> argparse.Namespace:
   """Parse command-line arguments.
   
   Returns:
       Parsed arguments namespace.
   """
   parser = argparse.ArgumentParser(
       description='Generate calibration image dataset for INT8 quantization',
       formatter_class=argparse.ArgumentDefaultsHelpFormatter
   )
   
   parser.add_argument(
       '--source-dir',
       type=str,
       required=True,
       help='Source directory containing input images'
   )
   
   parser.add_argument(
       '--output-dir',
       type=str,
       default='./calibration_images',
       help='Output directory for calibration images'
   )
   
   parser.add_argument(
       '--num-images',
       type=int,
       default=300,
       help='Number of images to sample for calibration'
   )
   
   parser.add_argument(
       '--width',
       type=int,
       default=644,
       help='Target image width'
   )
   
   parser.add_argument(
       '--height',
       type=int,
       default=392,
       help='Target image height'
   )
   
   parser.add_argument(
       '--seed',
       type=int,
       default=42,
       help='Random seed for reproducible sampling'
   )
   
   parser.add_argument(
       '--quality',
       type=int,
       default=95,
       choices=range(1, 101),
       metavar='[1-100]',
       help='JPEG compression quality'
   )
   
   parser.add_argument(
       '--verbose',
       action='store_true',
       help='Enable verbose logging'
   )
   
   return parser.parse_args()


def collect_image_paths(source_dir: Path, extensions: Tuple[str, ...] = ('.jpg', '.jpeg', '.png')) -> List[Path]:
   """Recursively collect all image paths from source directory.
   
   Args:
       source_dir: Root directory to search for images.
       extensions: Tuple of valid image file extensions (case-insensitive).
       
   Returns:
       Sorted list of image file paths.
       
   Raises:
       ValueError: If source directory doesn't exist or contains no images.
   """
   logger = logging.getLogger(__name__)
   
   if not source_dir.exists():
       raise ValueError(f"Source directory not found: {source_dir}")
   
   if not source_dir.is_dir():
       raise ValueError(f"Source path is not a directory: {source_dir}")
   
   # Collect all image files
   image_paths = []
   for ext in extensions:
       # Case-insensitive search
       image_paths.extend(source_dir.rglob(f"*{ext}"))
       image_paths.extend(source_dir.rglob(f"*{ext.upper()}"))
   
   # Remove duplicates and sort
   image_paths = sorted(set(image_paths))
   
   if not image_paths:
       raise ValueError(f"No images found in {source_dir} with extensions {extensions}")
   
   logger.info(f"Found {len(image_paths)} images in {source_dir}")
   return image_paths


def sample_images(image_paths: List[Path], num_samples: int, seed: int) -> List[Path]:
   """Sample a subset of images with fixed random seed.
   
   Args:
       image_paths: List of all available image paths.
       num_samples: Number of images to sample.
       seed: Random seed for reproducible sampling.
       
   Returns:
       Sorted list of sampled image paths.
   """
   logger = logging.getLogger(__name__)
   random.seed(seed)
   
   if len(image_paths) <= num_samples:
       logger.info(f"Requested {num_samples} images, but only {len(image_paths)} available. Using all.")
       return image_paths
   
   sampled = random.sample(image_paths, num_samples)
   logger.info(f"Sampled {len(sampled)} images from {len(image_paths)} total")
   
   return sorted(sampled)


def load_image(image_path: Path) -> Optional[np.ndarray]:
   """Load image from disk with error handling.
   
   Args:
       image_path: Path to image file.
       
   Returns:
       Image array in BGR format, or None if loading failed.
   """
   logger = logging.getLogger(__name__)
   
   try:
       img = cv2.imread(str(image_path))
       if img is None:
           logger.warning(f"Failed to decode image: {image_path}")
           return None
       return img
   except Exception as e:
       logger.error(f"Error loading image {image_path}: {e}")
       return None


def resize_if_needed(image: np.ndarray, target_width: int, target_height: int) -> np.ndarray:
   """Resize image only if dimensions don't match target size.
   
   Args:
       image: Input image array.
       target_width: Desired width.
       target_height: Desired height.
       
   Returns:
       Original image if already correct size, otherwise resized image.
   """
   height, width = image.shape[:2]
   
   if width == target_width and height == target_height:
       return image
   
   return cv2.resize(image, (target_width, target_height), interpolation=cv2.INTER_LINEAR)


def save_image(image: np.ndarray, output_path: Path, quality: int) -> bool:
   """Save image to disk with specified JPEG quality.
   
   Args:
       image: Image array to save (BGR format).
       output_path: Destination file path.
       quality: JPEG compression quality (1-100).
       
   Returns:
       True if save succeeded, False otherwise.
   """
   logger = logging.getLogger(__name__)
   
   try:
       success = cv2.imwrite(
           str(output_path),
           image,
           [cv2.IMWRITE_JPEG_QUALITY, quality]
       )
       if not success:
           logger.error(f"cv2.imwrite returned False for {output_path}")
           return False
       return True
   except Exception as e:
       logger.error(f"Error saving image to {output_path}: {e}")
       return False


def process_images(
   image_paths: List[Path],
   output_dir: Path,
   target_width: int,
   target_height: int,
   quality: int
) -> int:
   """Process and save calibration images.
   
   Args:
       image_paths: List of source image paths.
       output_dir: Directory to save processed images.
       target_width: Target image width.
       target_height: Target image height.
       quality: JPEG compression quality.
       
   Returns:
       Number of successfully processed images.
   """
   logger = logging.getLogger(__name__)
   
   # Create output directory
   try:
       output_dir.mkdir(parents=True, exist_ok=True)
   except Exception as e:
       logger.error(f"Failed to create output directory {output_dir}: {e}")
       return 0
   
   # Clear existing calibration images
   for old_file in output_dir.glob("calib_*.jpg"):
       try:
           old_file.unlink()
       except Exception as e:
           logger.warning(f"Failed to remove old file {old_file}: {e}")
   
   # Process images
   successful = 0
   logger.info(f"Processing {len(image_paths)} images...")
   
   for idx, img_path in enumerate(tqdm(image_paths, desc="Processing images")):
       # Load image
       img = load_image(img_path)
       if img is None:
           continue
       
       # Resize if needed
       img_resized = resize_if_needed(img, target_width, target_height)
       
       # Save processed image
       output_path = output_dir / f"calib_{idx:06d}.jpg"
       if save_image(img_resized, output_path, quality):
           successful += 1
           logger.debug(f"Saved {output_path}")
       else:
           logger.warning(f"Failed to save {output_path}")
   
   logger.info(f"Successfully processed {successful}/{len(image_paths)} images")
   return successful


def generate_image_list(output_dir: Path) -> bool:
   """Generate text file listing all calibration images.
   
   Args:
       output_dir: Directory containing calibration images.
       
   Returns:
       True if list file was created successfully, False otherwise.
   """
   logger = logging.getLogger(__name__)
   
   # Find all calibration images
   image_files = sorted(output_dir.glob("calib_*.jpg"))
   
   if not image_files:
       logger.error("No calibration images found to list")
       return False
   
   # Write list file
   list_file = output_dir / "calibration_list.txt"
   try:
       with open(list_file, 'w') as f:
           for img_file in image_files:
               f.write(f"{img_file.absolute()}\n")
       
       logger.info(f"Generated image list with {len(image_files)} entries: {list_file}")
       return True
   except Exception as e:
       logger.error(f"Failed to write image list file: {e}")
       return False


def main() -> int:
   """Main entry point.
   
   Returns:
       Exit code: 0 for success, non-zero for failure.
   """
   # Parse arguments
   args = parse_arguments()
   
   # Setup logging
   setup_logging(args.verbose)
   logger = logging.getLogger(__name__)
   
   # Convert paths
   source_dir = Path(args.source_dir)
   output_dir = Path(args.output_dir)
   
   try:
       # Collect all image paths
       all_images = collect_image_paths(source_dir)
       
       # Sample images
       selected_images = sample_images(all_images, args.num_images, args.seed)
       
       # Process and save images
       num_processed = process_images(
           selected_images,
           output_dir,
           args.width,
           args.height,
           args.quality
       )
       
       if num_processed == 0:
           logger.error("No images were successfully processed")
           return 1
       
       # Generate image list file
       if not generate_image_list(output_dir):
           logger.error("Failed to generate image list file")
           return 1
       
       logger.info("Calibration dataset generation completed successfully!")
       return 0
       
   except ValueError as e:
       logger.error(f"Validation error: {e}")
       return 1
   except Exception as e:
       logger.error(f"Unexpected error: {e}", exc_info=True)
       return 1


if __name__ == "__main__":
   sys.exit(main())
