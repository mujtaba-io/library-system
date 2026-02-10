
import os
import csv
import json
import shutil
import time
from datetime import datetime
import re

# Configuration
TMP_DIR = 'tmp'
DB_FILE = 'library.json'
BACKUP_FILE = 'library.json.bak'

# Category Mapping Rules (Filename -> Category)
FILENAME_CATEGORY_MAP = {
    'FGPG-College-Cupboard-28': 'Physics',
    'FGPG-College-Cupboard-29': 'Physics',
    'FGPG-College-Register-2': 'Economics',
    'FGPG-College-Economics': 'Economics',
    'FGPG-College-Register-3': 'Botany',
    'PSYCHOLOGY': 'Psychology',
    'BOTANY': 'Botany',
    'CS': 'Computer Science',
    'Chemistry': 'Chemistry'
}

def backup_database():
    if os.path.exists(DB_FILE):
        shutil.copy(DB_FILE, BACKUP_FILE)
        print(f"Backup created: {BACKUP_FILE}")
    else:
        print(f"Warning: {DB_FILE} not found. A new one will be created.")

def load_database():
    if os.path.exists(DB_FILE):
        with open(DB_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {"books": [], "issuance": [], "members": []}

def save_database(data):
    with open(DB_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=4)
    print(f"Database saved to {DB_FILE}")

def clean_text(text):
    if not text:
        return "NA"
    text = text.strip()
    return text if text else "NA"

def get_category_from_filename(filename):
    base_name = os.path.splitext(filename)[0]
    
    # Check specific mappings first
    for key, category in FILENAME_CATEGORY_MAP.items():
        if key in base_name:
            return category
    
    # Generic fallback: clean up filename
    # Remove numbers and special chars to guess category
    clean_name = re.sub(r'[^a-zA-Z\s]', '', base_name).strip()
    return clean_name if clean_name else "General"

def detect_header_row(lines):
    # Potential header keywords
    title_keywords = ['TITLE', 'BOOK TITLE', 'NAME', 'BOOK NAME']
    author_keywords = ['AUTHOR', 'AUTHOR NAME']
    
    for i, line in enumerate(lines[:10]): # Check first 10 lines
        # simple CSV split (not robust for quoted commas but good for detection)
        row = [c.strip().upper() for c in line.split(',')]
        
        has_title = any(k in row for k in title_keywords)
        has_author = any(k in row for k in author_keywords)
        
        if has_title and has_author:
            return i, row
            
    return -1, []

def parse_csv(filepath):
    filename = os.path.basename(filepath)
    print(f"\nProcessing: {filename}")
    
    books = []
    
    try:
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error reading file {filename}: {e}")
        return []

    # 1. Determine Category
    category = get_category_from_filename(filename)
    
    # Override logic: Check inside file for "Subject:" line?
    # (User mentioned checking file content for subject, mostly relevant if filename is generic)
    # For now, relying on the robust filename mapping we defined.
    
    # 2. Find Header
    header_idx, header_row = detect_header_row(lines)
    
    if header_idx == -1:
        print(f"  Skipping: Copuld not detect header row in {filename}")
        return []
        
    print(f"  Category: {category}")
    print(f"  Header found at line {header_idx + 1}: {header_row}")

    # 3. Map Columns
    # We look for indices of key fields
    try:
        title_idx = -1
        author_idx = -1
        acc_idx = -1
        
        for idx, col in enumerate(header_row):
            col = col.upper().replace('.', '').strip() # Clean column name
            if col in ['TITLE', 'BOOK TITLE', 'NAME', 'BOOK NAME']:
                title_idx = idx
            elif col in ['AUTHOR', 'AUTHOR NAME']:
                author_idx = idx
            elif col in ['ACC#', 'SRNO', 'S#', 'SR#', 'SR NO']:
                acc_idx = idx
        
        if title_idx == -1:
             print("  Skipping: Title column not identified.")
             return []

    except Exception as e:
        print(f"  Error mapping columns: {e}")
        return []

    # 4. Extract Data
    # Use python's csv module to handle quoted fields correctly starting from header_idx
    # We parse the whole file content string to ensure CSV reader handles newlines within quotes etc.
    content = "".join(lines[header_idx+1:])
    reader = csv.reader(content.splitlines())
    
    for row in reader:
        if not row: continue
        
        # Check bounds
        if len(row) <= title_idx: continue
        
        title = clean_text(row[title_idx])
        
        # specific check: if title is empty or just "Title" (repeated header), skip
        if title == "NA" or title.upper() in ['TITLE', 'BOOK TITLE', 'NAME']:
            continue
            
        author = "NA"
        if author_idx != -1 and len(row) > author_idx:
            author = clean_text(row[author_idx])
            
        acc_no = "NA"
        if acc_idx != -1 and len(row) > acc_idx:
            acc_no = clean_text(row[acc_idx])
            
        book = {
            "title": title,
            "author": author,
            "category": category,
            "accessionNo": acc_no,
            "publisher": "NA", # Default as mostly missing
            "status": "Available",
            "dateAdded": datetime.now().strftime("%Y-%m-%d"),
            "id": f"{int(time.time()*1000)}-{len(books)}" # Simple unique ID
        }
        books.append(book)
        
    print(f"  Extracted {len(books)} books.")
    return books

def main():
    backup_database()
    db = load_database()
    
    all_new_books = []
    
    # Scan tmp folder
    if not os.path.exists(TMP_DIR):
        print(f"Error: {TMP_DIR} directory not found.")
        return

    files = [f for f in os.listdir(TMP_DIR) if f.endswith('.csv')]
    
    for f in files:
        file_path = os.path.join(TMP_DIR, f)
        new_books = parse_csv(file_path)
        all_new_books.extend(new_books)
        
    # Add to database
    # Generate truly unique numeric IDs if needed, or stick to the timestamp based one
    # To correspond with existing `id` format (INT), let's ensure we use integers.
    # We'll find the max existing ID and increment.
    
    existing_ids = [int(b['id']) for b in db['books'] if str(b['id']).isdigit()]
    next_id = max(existing_ids) + 1 if existing_ids else 1
    
    print(f"\nAdding {len(all_new_books)} total books to database...")
    
    for book in all_new_books:
        book['id'] = next_id
        db['books'].append(book)
        next_id += 1
        
    save_database(db)
    print("Import completed successfully.")

if __name__ == "__main__":
    main()
