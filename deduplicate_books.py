import json
from collections import defaultdict, Counter

def norm(s):
    if not s:
        return ""
    s = s.replace("’", "'").replace("‘", "'").replace("–", "-").replace("—", "-").replace("…", "...")
    return " ".join(s.strip().lower().split())

def norm_author(s):
    t = norm(s)
    if t in ("", "na", "n/a", "-"):
        return ""
    return t

def main():
    with open("data/library_data.json", "r", encoding="utf-8") as f:
        data = json.load(f)

    books = data.get("books", [])
    print(f"Initial book records in data/library_data.json: {len(books)}")

    # Group books by normalized title and compatible author
    # Wait: what if the same book has author "Dr. Badar-ud-Din" in one row and "NA" in another?
    # Let's group by normalized title first, then merge records whose authors match (or one is empty/"NA").
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
            if cand_a == a_key or cand_a == "" or a_key == "":
                matched = cand
                break

        if matched is not None:
            merged_count += 1
            # Increment copies count
            try:
                c1 = int(matched.get("copies", "1") or "1")
            except ValueError:
                c1 = 1
            try:
                c2 = int(b.get("copies", "1") or "1")
            except ValueError:
                c2 = 1
            matched["copies"] = str(c1 + c2)

            # Prefer non-NA, clean fields
            for fk, fv in b.items():
                if fk in ("id", "copies", "accessionNo"):
                    continue
                if fv and fv != "NA" and (not matched.get(fk) or matched.get(fk) == "NA" or ("?" in matched.get(fk, "") and "?" not in fv)):
                    matched[fk] = fv

            # Keep first valid accessionNo if matched had "NA"
            if (not matched.get("accessionNo") or matched.get("accessionNo") == "NA") and b.get("accessionNo") and b.get("accessionNo") != "NA":
                matched["accessionNo"] = b["accessionNo"]
        else:
            if not b.get("copies"):
                b["copies"] = "1"
            unique_books.append(b)
            by_title[t_key].append(b)

    # Re-assign sequential IDs 1..N
    if not data.get("issuance"):
        for idx, b in enumerate(unique_books, start=1):
            b["id"] = str(idx)
        data["nextBookSeq"] = len(unique_books) + 1

    data["books"] = unique_books
    with open("data/library_data.json", "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)

    total_copies = sum(int(b.get("copies", "1")) for b in unique_books)
    print(f"Deduplication complete:")
    print(f"  - Merged {merged_count} repeating book rows into their primary book entry")
    print(f"  - Final unique books in data/library_data.json: {len(unique_books)} (representing {total_copies} total copies)")
    print("  - Breakdown by category:", dict(Counter(b["category"] for b in unique_books)))
    print("  - Sample multi-copy books:")
    for b in unique_books[:8]:
        print(f"      ID={b['id']:>2s} | Acc={b['accessionNo']:>2s} | Copies={b['copies']} | Title={b['title']!r} | Author={b['author']!r}")

if __name__ == "__main__":
    main()
