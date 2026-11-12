import json
import csv
import os
from collections import Counter

def norm_text(s):
    if not s:
        return ""
    s = s.replace("’", "'").replace("‘", "'").replace("–", "-").replace("—", "-").replace("…", "...")
    return " ".join(s.strip().lower().split())

def norm_author(s):
    t = norm_text(s)
    if t in ("", "na", "n/a", "-"):
        return ""
    return t

def norm_acc(s):
    t = norm_text(s)
    if t in ("", "na", "n/a", "-"):
        return ""
    return t

def is_mojibake_match(corrupted, clean):
    """Check if `corrupted` (containing '?' for non-ASCII chars) is the exact ASCII-stripped version of `clean`."""
    if "?" not in corrupted:
        return False
    c1 = norm_text(corrupted)
    c2 = norm_text(clean)
    # Replace non-ascii chars in clean with '?'
    c2_q = "".join((ch if ord(ch) < 128 else "?") for ch in c2)
    c2_q = " ".join(c2_q.split())
    return c1 == c2_q

def classify_register_book(title, author):
    t = (title + " " + author).lower()
    if any(k in t for k in ["linear algebra", "discrete mathematics", "calculus", "probability", "statistics"]):
        return "Mathematics"
    if any(k in t for k in ["islam", "islamiyat", "muslim", "quran"]):
        return "Islamic Studies"
    if any(k in t for k in ["pakistan"]):
        return "Pakistan Studies"
    if any(k in t for k in ["english", "grammar", "punctuation", "communication"]):
        return "English"
    if any(k in t for k in ["management"]):
        return "Management"
    return "Computer Science"

def load_all_csv_records():
    records = []

    # 1. Botany CSVs
    for fname in ["botany xls (1)-Sheet1.csv", "botany xls (1)-sheet.2.csv", "botany xls (1)-sheet 3.csv"]:
        path = os.path.join("tmp/csv", fname)
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for row in csv.DictReader(f):
                title = (row.get("BOOK TITLE") or "").strip()
                author = (row.get("AUTHOR") or "").strip()
                sr = (row.get("SR#") or "").strip()
                if title:
                    records.append({
                        "source": fname,
                        "accessionNo": sr or "NA",
                        "title": title,
                        "author": author or "NA",
                        "category": "Botany",
                        "edition": ""
                    })

    # 2. CS List Lib (1)-Sheet1.csv (has Edition column at index 20)
    path = "tmp/csv/CS List Lib (1)-Sheet1.csv"
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for row in csv.reader(f):
            if len(row) > 3 and row[1].strip().isdigit() and row[3].strip():
                records.append({
                    "source": "CS List Lib (1)-Sheet1.csv",
                    "accessionNo": row[1].strip(),
                    "title": row[3].strip(),
                    "author": row[16].strip() if len(row) > 16 and row[16].strip() else "NA",
                    "category": "Computer Science",
                    "edition": row[20].strip() if len(row) > 20 and row[20].strip() else ""
                })

    # 3. CS List Lib (1)-Sheet4.csv
    path = "tmp/csv/CS List Lib (1)-Sheet4.csv"
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for row in csv.reader(f):
            if len(row) > 1 and row[0].strip().isdigit() and row[1].strip():
                records.append({
                    "source": "CS List Lib (1)-Sheet4.csv",
                    "accessionNo": row[0].strip(),
                    "title": row[1].strip(),
                    "author": row[14].strip() if len(row) > 14 and row[14].strip() else "NA",
                    "category": "Computer Science",
                    "edition": ""
                })

    # 4. FDPG college (2)-Cupboard 28.csv & Cupboard 29.csv -> Physics
    for fname in ["FDPG college (2)-Cupboard 28.csv", "FDPG college (2)-Cupboard 29.csv"]:
        path = os.path.join("tmp/csv", fname)
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for row in csv.reader(f):
                if len(row) >= 3 and row[0].strip().isdigit() and row[2].strip():
                    acc = row[1].strip() if len(row) > 1 and row[1].strip() else "NA"
                    author = row[3].strip() if len(row) > 3 and row[3].strip() else "NA"
                    records.append({
                        "source": fname,
                        "accessionNo": acc,
                        "title": row[2].strip(),
                        "author": author,
                        "category": "Physics",
                        "edition": ""
                    })

    # 5. FDPG college (2)-Register 2.csv -> Economics
    fname = "FDPG college (2)-Register 2.csv"
    with open(os.path.join("tmp/csv", fname), "r", encoding="utf-8", errors="replace") as f:
        for row in csv.reader(f):
            if len(row) >= 3 and row[0].strip().isdigit() and row[2].strip():
                acc = row[1].strip() if len(row) > 1 and row[1].strip() else "NA"
                author = row[3].strip() if len(row) > 3 and row[3].strip() else "NA"
                records.append({
                    "source": fname,
                    "accessionNo": acc,
                    "title": row[2].strip(),
                    "author": author,
                    "category": "Economics",
                    "edition": ""
                })

    # 6. FDPG college Library Catalog (Chemistry Books) (2).csv -> Chemistry
    fname = "FDPG college Library Catalog (Chemistry Books) (2).csv"
    with open(os.path.join("tmp/csv", fname), "r", encoding="utf-8", errors="replace") as f:
        for row in csv.reader(f):
            if len(row) >= 3 and row[0].strip().isdigit() and row[2].strip():
                acc = row[1].strip() if len(row) > 1 and row[1].strip() else "NA"
                author = row[3].strip() if len(row) > 3 and row[3].strip() else "NA"
                records.append({
                    "source": fname,
                    "accessionNo": acc,
                    "title": row[2].strip(),
                    "author": author,
                    "category": "Chemistry",
                    "edition": ""
                })

    # 7. psychology books (1)-Sheet1.csv -> Psychology
    fname = "psychology books (1)-Sheet1.csv"
    with open(os.path.join("tmp/csv", fname), "r", encoding="utf-8", errors="replace") as f:
        for row in csv.reader(f):
            if len(row) >= 4 and row[0].strip().isdigit() and row[2].strip():
                sr = row[0].strip()
                acc = row[1].strip() if row[1].strip() else sr
                author = row[3].strip() if row[3].strip() else "NA"
                records.append({
                    "source": fname,
                    "accessionNo": acc,
                    "title": row[2].strip(),
                    "author": author,
                    "category": "Psychology",
                    "edition": ""
                })

    # 8. Updated_Complete_Books_Accession_Register_4597-4762.csv
    fname = "Updated_Complete_Books_Accession_Register_4597-4762.csv"
    with open(os.path.join("tmp/csv", fname), "r", encoding="utf-8", errors="replace") as f:
        for row in csv.DictReader(f):
            title = (row.get("Particulars") or "").strip()
            acc = (row.get("Accession No.") or "").strip()
            author = (row.get("Author") or "").strip()
            ed = (row.get("Edition") or "").strip()
            if ed == "—": ed = ""
            if author == "—": author = "NA"
            if title:
                records.append({
                    "source": fname,
                    "accessionNo": acc or "NA",
                    "title": title,
                    "author": author or "NA",
                    "category": classify_register_book(title, author),
                    "edition": ed
                })

    return records

def titles_equivalent(t1, t2):
    n1 = norm_text(t1)
    n2 = norm_text(t2)
    if n1 == n2:
        return True
    if is_mojibake_match(t1, t2) or is_mojibake_match(t2, t1):
        return True
    return False

def authors_equivalent(a1, a2):
    n1 = norm_author(a1)
    n2 = norm_author(a2)
    if n1 == n2 or n1 == "" or n2 == "":
        return True
    if is_mojibake_match(a1, a2) or is_mojibake_match(a2, a1):
        return True
    return False

def main():
    with open("data/library_data.json", "r", encoding="utf-8") as f:
        data = json.load(f)

    orig_books = data.get("books", [])
    print(f"Loaded {len(orig_books)} books from data/library_data.json")

    schema_keys = [f["key"] for f in data.get("schemas", {}).get("book", [])]
    if not schema_keys:
        schema_keys = [
            "id", "accessionNo", "title", "author", "category", "publisher",
            "status", "copies", "isbn", "year", "edition", "shelf",
            "language", "dateAdded", "notes"
        ]

    deduped = []
    by_cat_acc = {}

    def find_duplicate(cat, acc, raw_title, raw_author):
        for cand in by_cat_acc.get((cat, acc), []):
            if titles_equivalent(cand.get("title", ""), raw_title) and authors_equivalent(cand.get("author", ""), raw_author):
                return cand
        # Also check if same non-empty accessionNo & equivalent title across categories
        if acc != "":
            for (c_cat, c_acc), cands in by_cat_acc.items():
                if c_acc == acc:
                    for cand in cands:
                        if titles_equivalent(cand.get("title", ""), raw_title):
                            return cand
        return None

    def register_book(b):
        cat = norm_text(b.get("category", ""))
        acc = norm_acc(b.get("accessionNo", ""))
        by_cat_acc.setdefault((cat, acc), []).append(b)

    removed_existing = 0
    for b in orig_books:
        cat = norm_text(b.get("category", ""))
        acc = norm_acc(b.get("accessionNo", ""))
        raw_title = b.get("title", "")
        raw_author = b.get("author", "")

        dup = find_duplicate(cat, acc, raw_title, raw_author)
        if dup is not None:
            removed_existing += 1
            # Prefer clean Unicode (without '?') over mojibake ('?')
            if "?" in dup.get("title", "") and "?" not in raw_title and raw_title:
                dup["title"] = raw_title
            if "?" in dup.get("author", "") and "?" not in raw_author and raw_author:
                dup["author"] = raw_author
            for fk, fv in b.items():
                if fk in ("id", "title", "author"):
                    continue
                if fv and fv != "NA" and (not dup.get(fk) or dup.get(fk) == "NA"):
                    dup[fk] = fv
        else:
            deduped.append(b)
            register_book(b)

    print(f"Deduplicated existing records: removed {removed_existing} -> {len(deduped)} unique books")

    csv_records = load_all_csv_records()
    added_from_csv = 0
    updated_from_csv = 0
    skipped_from_csv = 0

    max_id = max((int(b["id"]) for b in deduped if str(b.get("id", "")).isdigit()), default=0)

    for r in csv_records:
        cat = norm_text(r["category"])
        acc = norm_acc(r["accessionNo"])
        raw_title = r["title"]
        raw_author = r["author"]

        dup = find_duplicate(cat, acc, raw_title, raw_author)
        if dup is not None:
            changed = False
            if r.get("edition") and not dup.get("edition"):
                dup["edition"] = r["edition"]
                changed = True
            if "?" in dup.get("title", "") and "?" not in raw_title and raw_title:
                dup["title"] = raw_title
                changed = True
            if raw_author and raw_author != "NA" and (not dup.get("author") or dup.get("author") == "NA" or ("?" in dup.get("author", "") and "?" not in raw_author)):
                dup["author"] = raw_author
                changed = True
            if changed:
                updated_from_csv += 1
            else:
                skipped_from_csv += 1
        else:
            max_id += 1
            new_book = {k: "" for k in schema_keys}
            new_book["id"] = str(max_id)
            new_book["accessionNo"] = r["accessionNo"]
            new_book["title"] = raw_title
            new_book["author"] = raw_author
            new_book["category"] = r["category"]
            new_book["edition"] = r.get("edition", "")
            new_book["publisher"] = "NA"
            new_book["status"] = "Available"
            new_book["copies"] = "1"
            new_book["dateAdded"] = "2026-11-12"
            deduped.append(new_book)
            register_book(new_book)
            added_from_csv += 1

    if not data.get("issuance"):
        for idx, b in enumerate(deduped, start=1):
            b["id"] = str(idx)
        data["nextBookSeq"] = len(deduped) + 1
    else:
        data["nextBookSeq"] = max_id + 1

    data["books"] = deduped
    with open("data/library_data.json", "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)

    print(f"CSV Integration complete:")
    print(f"  - Added new unique books from CSVs: {added_from_csv}")
    print(f"  - Enriched/repaired existing books from CSVs: {updated_from_csv}")
    print(f"  - Skipped duplicate CSV rows already in JSON: {skipped_from_csv}")
    print(f"  - Final total unique books in data/library_data.json: {len(deduped)}")
    print("  - Breakdown by category:", dict(Counter(b["category"] for b in deduped)))

if __name__ == "__main__":
    main()
