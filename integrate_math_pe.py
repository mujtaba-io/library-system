import json
import csv
import os
import re
from collections import defaultdict, Counter

def norm(s):
    if not s:
        return ""
    s = s.replace("’", "'").replace("‘", "'").replace("–", "-").replace("—", "-").replace("…", "...")
    return " ".join(s.strip().lower().split())

def norm_author(s):
    t = norm(s)
    if t in ("", "na", "n/a", "-", "(blank)", "blank", "(none)"):
        return ""
    return t

def clean_author_display(s):
    if not s:
        return "NA"
    t = s.strip()
    if t.lower() in ("", "na", "n/a", "-", "—", "(blank)", "blank", "(none)"):
        return "NA"
    return t

def clean_sr(s):
    if not s:
        return "NA"
    t = s.strip()
    # e.g. "(1)" -> "1"
    m = re.match(r"^\((\d+)\)$", t)
    if m:
        return m.group(1)
    return t if t else "NA"

def load_math_and_pe_csvs():
    records = []

    # 1. tmp/math-books.csv: SR #,Book Title,Author
    math_path = "tmp/math-books.csv"
    if os.path.exists(math_path):
        with open(math_path, "r", encoding="utf-8", errors="replace") as f:
            for row in csv.DictReader(f):
                sr = clean_sr(row.get("SR #", ""))
                title = (row.get("Book Title") or "").strip()
                author = clean_author_display(row.get("Author", ""))
                if title:
                    records.append({
                        "source": "math-books.csv",
                        "accessionNo": sr,
                        "title": title,
                        "author": author,
                        "category": "Mathematics",
                        "edition": ""
                    })

    # 2. tmp/physical-education-books.csv: S. No.,Author,Title
    pe_path = "tmp/physical-education-books.csv"
    if os.path.exists(pe_path):
        with open(pe_path, "r", encoding="utf-8", errors="replace") as f:
            for row in csv.DictReader(f):
                sr = clean_sr(row.get("S. No.", ""))
                title = (row.get("Title") or "").strip()
                author = clean_author_display(row.get("Author", ""))
                if title:
                    records.append({
                        "source": "physical-education-books.csv",
                        "accessionNo": sr,
                        "title": title,
                        "author": author,
                        "category": "Physical Education",
                        "edition": ""
                    })

    return records

def main():
    with open("data/library_data.json", "r", encoding="utf-8") as f:
        data = json.load(f)

    books = data.get("books", [])
    print(f"Existing unique books in data/library_data.json: {len(books)}")

    schema_keys = [f["key"] for f in data.get("schemas", {}).get("book", [])]
    if not schema_keys:
        schema_keys = [
            "id", "accessionNo", "title", "author", "category", "publisher",
            "status", "copies", "isbn", "year", "edition", "shelf",
            "language", "dateAdded", "notes"
        ]

    new_csv_rows = load_math_and_pe_csvs()
    print(f"Loaded {len(new_csv_rows)} rows from math-books.csv & physical-education-books.csv")

    # Convert new CSV rows into full book objects with copies="1"
    for r in new_csv_rows:
        b = {k: "" for k in schema_keys}
        b["id"] = ""
        b["accessionNo"] = r["accessionNo"]
        b["title"] = r["title"]
        b["author"] = r["author"]
        b["category"] = r["category"]
        b["edition"] = r.get("edition", "")
        b["publisher"] = "NA"
        b["status"] = "Available"
        b["copies"] = "1"
        b["dateAdded"] = "2026-11-12"
        books.append(b)

    # Now run full deduplication across all books in library_data.json
    by_title = defaultdict(list)
    unique_books = []
    merged_count = 0

    for b in books:
        t_key = norm(b.get("title", ""))
        a_key = norm_author(b.get("author", ""))

        candidates = by_title[t_key]
        matched = None
        for cand in candidates:
            cand_a = norm_author(cand.get("author", ""))
            # Match if authors are identical, or one of the authors is empty/"NA",
            # or one is "Dr. X" and the other is "X" (e.g. "Dr. A. W. Musher" vs "A. W. Musher")
            cand_a_nodr = re.sub(r"^dr\.?\s+", "", cand_a)
            a_key_nodr = re.sub(r"^dr\.?\s+", "", a_key)
            if cand_a == a_key or cand_a_nodr == a_key_nodr or cand_a == "" or a_key == "":
                matched = cand
                break

        if matched is not None:
            merged_count += 1
            try:
                c1 = int(matched.get("copies", "1") or "1")
            except ValueError:
                c1 = 1
            try:
                c2 = int(b.get("copies", "1") or "1")
            except ValueError:
                c2 = 1
            matched["copies"] = str(c1 + c2)

            for fk, fv in b.items():
                if fk in ("id", "copies", "accessionNo"):
                    continue
                if fv and fv != "NA" and (not matched.get(fk) or matched.get(fk) == "NA"):
                    matched[fk] = fv

            if (not matched.get("accessionNo") or matched.get("accessionNo") == "NA") and b.get("accessionNo") and b.get("accessionNo") != "NA":
                matched["accessionNo"] = b["accessionNo"]
        else:
            if not b.get("copies"):
                b["copies"] = "1"
            unique_books.append(b)
            by_title[t_key].append(b)

    if not data.get("issuance"):
        for idx, b in enumerate(unique_books, start=1):
            b["id"] = str(idx)
        data["nextBookSeq"] = len(unique_books) + 1

    data["books"] = unique_books
    with open("data/library_data.json", "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)

    total_copies = sum(int(b.get("copies", "1")) for b in unique_books)
    print(f"Integration & Deduplication complete:")
    print(f"  - Merged {merged_count} duplicate/repeating rows")
    print(f"  - Final unique books in data/library_data.json: {len(unique_books)} (representing {total_copies} total copies)")
    print("  - Breakdown by category:", dict(Counter(b["category"] for b in unique_books)))

if __name__ == "__main__":
    main()
