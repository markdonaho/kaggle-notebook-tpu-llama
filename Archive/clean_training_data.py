import json
import re
import sys
from pathlib import Path

def clean_point_text(point_text: str) -> str:
    """
    Standardizes the formatting of a summary point.
    - Removes leading list markers (like '1.', '*', '-')
    - Removes leading/trailing whitespace.
    - Ensures the point starts with '- '.
    """
    # Remove common list markers and surrounding whitespace/formatting
    cleaned = re.sub(r'^\s*(\d+\.\s*|\*\s*|-\s*|\*\*|)\s*', '', point_text).strip()
    
    # Remove bold markdown from the start of the string
    cleaned = re.sub(r'^\*\*(.*?)\*\*', r'\1', cleaned)

    # Ensure it starts with a standard bullet
    if not cleaned.startswith('- '):
        cleaned = f'- {cleaned}'
        
    return cleaned

def main():
    """
    Validates and cleans the training data.
    - Ensures `output_text` is valid JSON.
    - Standardizes the formatting of bullet points in the `points` array.
    """
    if len(sys.argv) != 3:
        print("Usage: python clean_training_data.py <input_json_path> <output_json_path>")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    if not input_path.exists():
        print(f"Error: Input file not found at {input_path}")
        sys.exit(1)

    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    cleaned_data = []
    error_count = 0
    
    for i, entry in enumerate(data):
        try:
            # 1. Validate and parse the JSON string in `output_text`
            output_data = json.loads(entry['output_text'])

            # 2. Standardize point formatting
            if 'points' in output_data and isinstance(output_data['points'], list):
                cleaned_points = [clean_point_text(p) for p in output_data['points']]
                output_data['points'] = cleaned_points
            
            # 3. Re-serialize the cleaned object back to a string
            entry['output_text'] = json.dumps(output_data)
            cleaned_data.append(entry)

        except json.JSONDecodeError:
            print(f"Warning: JSON parsing failed for entry at index {i}. Skipping.")
            error_count += 1
            continue
        except Exception as e:
            print(f"An unexpected error occurred at index {i}: {e}. Skipping.")
            error_count += 1
            continue

    # 4. Write the cleaned data to the output file
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(cleaned_data, f, indent=2)

    print(f"Processing complete.")
    print(f"Total entries processed: {len(data)}")
    print(f"Entries with errors (skipped): {error_count}")
    print(f"Cleaned data written to: {output_path}")

if __name__ == "__main__":
    main()
