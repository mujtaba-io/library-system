module store;

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.file;
import std.json;
import std.path;
import std.string;
import std.uni : toLower;

/// Supported entities in the library system.
enum EntityType : string {
    book = "book",
    member = "member",
    issue = "issue"
}

/// Field data types supported by the dynamic schema.
enum FieldType : string {
    text = "text",
    number = "number",
    date = "date",
    role = "role"
}

/// Definition of a single field (column) in an entity's schema.
struct FieldDef {
    string key;        /// Internal key, e.g. "title", "isbn"
    string label;      /// Display column header / form label
    FieldType type = FieldType.text;
    bool core = false; /// Protected field required by system logic
    bool required = false;
    int width = 140;   /// Default column width in pixels
}

/// A generic entity record backed by a string map.
/// Missing or empty values represent NULL/empty fields.
struct Record {
    string[string] data;

    string get(string key, string fallback = "") const {
        if (auto p = key in data)
            return *p;
        return fallback;
    }

    void set(string key, string value) {
        data[key] = value.strip();
    }
}

/// Normalize CNIC by stripping dashes, spaces, and non-digits.
string normalizeCnic(string raw) {
    char[] buf;
    buf.reserve(raw.length);
    foreach (char c; raw) {
        if (c >= '0' && c <= '9')
            buf ~= c;
    }
    return cast(string) buf;
}

/// Return today's date as YYYY-MM-DD.
string todayIso() {
    auto now = Clock.currTime();
    return Date(now.year, now.month, now.day).toISOExtString();
}

/// Return date offset by `days` from today as YYYY-MM-DD.
string datePlusDaysIso(int days) {
    auto now = Clock.currTime();
    auto target = Date(now.year, now.month, now.day) + dur!"days"(days);
    return target.toISOExtString();
}

/// Single-workstation persistent store with dynamic schemas for Books, Members, and Issuance.
class LibraryStore {
    string filePath;

    FieldDef[][EntityType] schemas;
    Record[] books;
    Record[] members;
    Record[] issues;

    private int nextBookSeq = 1;
    private int nextIssueSeq = 5001;

    this(string path = "data/library_data.json") {
        this.filePath = path;
        if (exists(filePath)) {
            try {
                load();
                bool modified = ensureCoreSchemasAndDefaults();
                if (modified) {
                    save();
                }
                return;
            } catch (Exception) {
                // Fall through to seed defaults if file is corrupted
            }
        }
        initDefaultSchemas();
        seedSampleData();
        save();
    }

    /// Initialize default schemas combining legacy fields and full library fields.
    void initDefaultSchemas() {
        schemas[EntityType.book] = [
            FieldDef("id",          "ID",           FieldType.text,   true,  true,  70),
            FieldDef("accessionNo", "Accession No", FieldType.text,   false, false, 105),
            FieldDef("title",       "Title",        FieldType.text,   true,  true,  250),
            FieldDef("author",      "Author",       FieldType.text,   false, false, 170),
            FieldDef("category",    "Category",     FieldType.text,   false, false, 130),
            FieldDef("publisher",   "Publisher",    FieldType.text,   false, false, 140),
            FieldDef("status",      "Status",       FieldType.text,   true,  false, 95),
            FieldDef("copies",      "Copies",       FieldType.number, true,  true,  75),
            FieldDef("isbn",        "ISBN",         FieldType.text,   false, false, 130),
            FieldDef("year",        "Year",         FieldType.number, false, false, 75),
            FieldDef("edition",     "Edition",      FieldType.text,   false, false, 85),
            FieldDef("shelf",       "Shelf",        FieldType.text,   false, false, 85),
            FieldDef("language",    "Language",     FieldType.text,   false, false, 95),
            FieldDef("dateAdded",   "Date Added",   FieldType.date,   false, false, 105),
            FieldDef("notes",       "Notes",        FieldType.text,   false, false, 160)
        ];

        schemas[EntityType.member] = [
            FieldDef("cnic",       "CNIC",         FieldType.text,   true,  true,  135),
            FieldDef("name",       "Name",         FieldType.text,   true,  true,  190),
            FieldDef("role",       "Role",         FieldType.role,   true,  true,  100),
            FieldDef("department", "Department",   FieldType.text,   false, false, 150),
            FieldDef("roll_no",    "Roll / Emp #", FieldType.text,   false, false, 120),
            FieldDef("phone",      "Phone",        FieldType.text,   false, false, 130),
            FieldDef("semester",   "Semester",     FieldType.text,   false, false, 90)
        ];

        schemas[EntityType.issue] = [
            FieldDef("id",          "Issue ID",    FieldType.text, true,  true,  90),
            FieldDef("book_id",     "Book ID",     FieldType.text, true,  true,  90),
            FieldDef("member_cnic", "Member CNIC", FieldType.text, true,  true,  135),
            FieldDef("issued_at",   "Issued",      FieldType.date, true,  true,  105),
            FieldDef("due_at",      "Due",         FieldType.date, true,  true,  105),
            FieldDef("returned_at", "Returned",    FieldType.date, true,  false, 105),
            FieldDef("condition",   "Condition",   FieldType.text, false, false, 120),
            FieldDef("remarks",     "Remarks",     FieldType.text, false, false, 160)
        ];
    }

    /// Ensure schemas exist and integrate any missing fields into records with default/empty values.
    private bool ensureCoreSchemasAndDefaults() {
        bool modified = false;
        if (EntityType.book !in schemas || schemas[EntityType.book].length == 0 ||
            EntityType.member !in schemas || schemas[EntityType.member].length == 0 ||
            EntityType.issue !in schemas || schemas[EntityType.issue].length == 0) {
            initDefaultSchemas();
            modified = true;
        }

        // Compute nextBookSeq from existing book IDs
        int maxBookId = 0;
        foreach (ref b; books) {
            string rawId = b.get("id");
            if (rawId.startsWith("B-"))
                rawId = rawId[2 .. $];
            try {
                int n = to!int(rawId);
                if (n > maxBookId) maxBookId = n;
            } catch (Exception) {}

            // Integrate missing book schema fields with default values
            if (b.get("copies").length == 0) {
                b.set("copies", "1");
                modified = true;
            }
            if (b.get("status").length == 0) {
                b.set("status", "Available");
                modified = true;
            }
            foreach (f; schemas[EntityType.book]) {
                if (f.key !in b.data) {
                    b.data[f.key] = "";
                    modified = true;
                }
            }
        }
        if (maxBookId >= nextBookSeq) {
            nextBookSeq = maxBookId + 1;
            modified = true;
        }

        // Integrate missing member schema fields
        foreach (ref m; members) {
            foreach (f; schemas[EntityType.member]) {
                if (f.key !in m.data) {
                    m.data[f.key] = "";
                    modified = true;
                }
            }
        }

        // Compute nextIssueSeq and integrate missing issue schema fields
        int maxIssueId = 5000;
        foreach (ref iss; issues) {
            string rawId = iss.get("id");
            if (rawId.startsWith("I-") || rawId.startsWith("L-"))
                rawId = rawId[2 .. $];
            try {
                int n = to!int(rawId);
                if (n > maxIssueId) maxIssueId = n;
            } catch (Exception) {}

            foreach (f; schemas[EntityType.issue]) {
                if (f.key !in iss.data) {
                    iss.data[f.key] = "";
                    modified = true;
                }
            }
        }
        if (maxIssueId >= nextIssueSeq) {
            nextIssueSeq = maxIssueId + 1;
            modified = true;
        }

        return modified;
    }

    private void seedSampleData() {
        books = [];
        members = [];
        issues = [];

        void addSampleBook(string title, string author, string isbn, string cat,
                           string pub, string year, string ed, string shelf, string copies, string lang = "English") {
            Record r;
            string idStr = to!string(nextBookSeq++);
            r.set("id", idStr);
            r.set("accessionNo", idStr);
            r.set("title", title);
            r.set("author", author);
            r.set("isbn", isbn);
            r.set("category", cat);
            r.set("publisher", pub);
            r.set("status", "Available");
            r.set("year", year);
            r.set("edition", ed);
            r.set("shelf", shelf);
            r.set("copies", copies);
            r.set("language", lang);
            r.set("dateAdded", todayIso());
            r.set("notes", "");
            books ~= r;
        }

        addSampleBook("The D Programming Language", "Andrei Alexandrescu", "9780321635365", "Computer Science", "Addison-Wesley", "2010", "1st", "CS-A1", "4");
        addSampleBook("Structure and Interpretation of Computer Programs", "Harold Abelson, Gerald Jay Sussman", "9780262510875", "Computer Science", "MIT Press", "1996", "2nd", "CS-A2", "3");
        addSampleBook("Introduction to Algorithms", "Cormen, Leiserson, Rivest, Stein", "9780262046305", "Computer Science", "MIT Press", "2022", "4th", "CS-A3", "6");
        addSampleBook("Designing Data-Intensive Applications", "Martin Kleppmann", "9781449373320", "Systems", "O'Reilly", "2017", "1st", "CS-B1", "2");
        addSampleBook("Operating System Concepts", "Abraham Silberschatz", "9781119800361", "Systems", "Wiley", "2021", "10th", "CS-B2", "5");
        addSampleBook("Linear Algebra Done Right", "Sheldon Axler", "9783319110790", "Mathematics", "Springer", "2015", "3rd", "MTH-1", "4");
        addSampleBook("Calculus", "Michael Spivak", "9780914098911", "Mathematics", "Publish or Perish", "2008", "4th", "MTH-2", "3");
        addSampleBook("The Feynman Lectures on Physics, Vol. I", "Richard P. Feynman", "9780465024933", "Physics", "Basic Books", "", "", "PHY-1", "2");
        addSampleBook("Organic Chemistry", "Jonathan Clayden", "9780199270293", "Chemistry", "Oxford", "2012", "2nd", "CHM-1", "3");
        addSampleBook("Kulliyat-e-Iqbal", "Allama Muhammad Iqbal", "", "Literature", "Sheikh Ghulam Ali", "", "", "LIT-4", "5", "Urdu");

        void addSampleMember(string cnic, string name, string role, string dept, string roll, string phone, string sem = "") {
            Record m;
            m.set("cnic", normalizeCnic(cnic));
            m.set("name", name);
            m.set("role", role);
            m.set("department", dept);
            m.set("roll_no", roll);
            m.set("phone", phone);
            m.set("semester", sem);
            members ~= m;
        }

        addSampleMember("3520211223341", "Dr. Tariq Mahmood", "Teacher", "Computer Science", "EMP-104", "03001122334");
        addSampleMember("3520299887765", "Prof. Nadia Kamal", "Teacher", "Mathematics", "EMP-219", "03219988776");
        addSampleMember("3520244556677", "Hamza Ali", "Student", "Computer Science", "BSCS-23-014", "03334455667", "5th");
        addSampleMember("3520277665543", "Ayesha Siddiqui", "Student", "Physics", "BSPH-24-008", "03457766554", "3rd");

        // Sample active issue
        Record issue1;
        issue1.set("id", "I-" ~ to!string(nextIssueSeq++));
        issue1.set("book_id", "1");
        issue1.set("member_cnic", "3520244556677");
        issue1.set("issued_at", todayIso());
        issue1.set("due_at", datePlusDaysIso(14));
        issue1.set("returned_at", "");
        issue1.set("condition", "Good");
        issue1.set("remarks", "");
        issues ~= issue1;
    }

    FieldDef[] schemaFor(EntityType type) {
        if (auto p = type in schemas)
            return *p;
        return [];
    }

    /// Add a new custom field to the given entity schema.
    bool addSchemaField(EntityType type, string rawKey, string label, FieldType fieldType, bool required, out string err) {
        string cleanLabel = label.strip();
        if (cleanLabel.length == 0) {
            err = "Field label is required.";
            return false;
        }
        string key = sanitizeKey(rawKey.strip().length ? rawKey : cleanLabel);
        if (key.length == 0) {
            err = "Invalid field key.";
            return false;
        }
        foreach (f; schemas[type]) {
            if (f.key == key) {
                err = "Field '" ~ key ~ "' already exists.";
                return false;
            }
        }
        int width = 130;
        if (fieldType == FieldType.number) width = 85;
        else if (fieldType == FieldType.date) width = 105;

        schemas[type] ~= FieldDef(key, cleanLabel, fieldType, false, required, width);

        // Populate default empty value in existing records of this entity
        if (type == EntityType.book) {
            foreach (ref r; books) if (key !in r.data) r.data[key] = "";
        } else if (type == EntityType.member) {
            foreach (ref r; members) if (key !in r.data) r.data[key] = "";
        } else if (type == EntityType.issue) {
            foreach (ref r; issues) if (key !in r.data) r.data[key] = "";
        }

        save();
        return true;
    }

    /// Update an existing schema field's label, type, or required status.
    bool updateSchemaField(EntityType type, string key, string newLabel, FieldType newType, bool newRequired, out string err) {
        auto list = schemas[type];
        foreach (ref f; list) {
            if (f.key == key) {
                if (newLabel.strip().length == 0) {
                    err = "Label cannot be empty.";
                    return false;
                }
                f.label = newLabel.strip();
                if (!f.core) {
                    f.type = newType;
                    f.required = newRequired;
                }
                schemas[type] = list;
                save();
                return true;
            }
        }
        err = "Field not found.";
        return false;
    }

    /// Remove a non-core field from the schema.
    bool removeSchemaField(EntityType type, string key, out string err) {
        auto list = schemas[type];
        ptrdiff_t idx = -1;
        foreach (i, f; list) {
            if (f.key == key) {
                if (f.core) {
                    err = "Core system fields cannot be removed.";
                    return false;
                }
                idx = i;
                break;
            }
        }
        if (idx < 0) {
            err = "Field not found.";
            return false;
        }
        schemas[type] = list[0 .. idx] ~ list[idx + 1 .. $];
        save();
        return true;
    }

    /// Reorder a field up (-1) or down (+1).
    bool moveSchemaField(EntityType type, string key, int delta) {
        auto list = schemas[type];
        ptrdiff_t idx = -1;
        foreach (i, f; list) {
            if (f.key == key) {
                idx = i;
                break;
            }
        }
        if (idx < 0) return false;
        ptrdiff_t target = idx + delta;
        if (target < 0 || target >= cast(ptrdiff_t) list.length)
            return false;
        swap(list[idx], list[target]);
        schemas[type] = list;
        save();
        return true;
    }

    static string sanitizeKey(string input) {
        char[] res;
        bool lastUnderscore = false;
        foreach (char c; input.toLower()) {
            if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) {
                res ~= c;
                lastUnderscore = false;
            } else if (!lastUnderscore && res.length > 0) {
                res ~= '_';
                lastUnderscore = true;
            }
        }
        while (res.length > 0 && res[$ - 1] == '_')
            res = res[0 .. $ - 1];
        return cast(string) res;
    }

    // --- Book Operations ---

    string nextBookId() {
        return to!string(nextBookSeq++);
    }

    Record* findBook(string id) {
        foreach (ref b; books) {
            if (b.get("id") == id)
                return &b;
        }
        return null;
    }

    int activeIssueCountForBook(string bookId) {
        int count = 0;
        foreach (ref iss; issues) {
            if (iss.get("book_id") == bookId && iss.get("returned_at").length == 0)
                count++;
        }
        return count;
    }

    int totalCopiesForBook(string bookId) {
        auto b = findBook(bookId);
        if (!b) return 0;
        try {
            string cStr = b.get("copies", "1");
            if (cStr.length == 0) return 1;
            int c = to!int(cStr);
            return c < 0 ? 0 : c;
        } catch (Exception) {
            return 1;
        }
    }

    int availableCopiesForBook(string bookId) {
        int avail = totalCopiesForBook(bookId) - activeIssueCountForBook(bookId);
        return avail < 0 ? 0 : avail;
    }

    private void syncBookStatus(string bookId) {
        auto b = findBook(bookId);
        if (!b) return;
        if (availableCopiesForBook(bookId) <= 0)
            b.set("status", "Issued");
        else
            b.set("status", "Available");
    }

    bool upsertBook(Record rec, out string savedId, out string err) {
        if (rec.get("title").length == 0) {
            err = "Book Title is required.";
            return false;
        }
        if (rec.get("copies").length == 0) {
            rec.set("copies", "1");
        } else {
            try {
                int c = to!int(rec.get("copies"));
                if (c < 0) {
                    err = "Copies cannot be negative.";
                    return false;
                }
            } catch (Exception) {
                err = "Copies must be a number.";
                return false;
            }
        }

        if (rec.get("status").length == 0)
            rec.set("status", "Available");
        if (rec.get("dateAdded").length == 0)
            rec.set("dateAdded", todayIso());

        foreach (f; schemas[EntityType.book]) {
            if (!f.core && f.required && rec.get(f.key).length == 0) {
                err = f.label ~ " is required.";
                return false;
            }
            if (f.key !in rec.data) {
                rec.data[f.key] = "";
            }
        }

        string id = rec.get("id");
        if (id.length == 0) {
            id = nextBookId();
            rec.set("id", id);
            if (rec.get("accessionNo").length == 0)
                rec.set("accessionNo", id);
            books ~= rec;
        } else {
            bool found = false;
            foreach (ref b; books) {
                if (b.get("id") == id) {
                    b = rec;
                    found = true;
                    break;
                }
            }
            if (!found)
                books ~= rec;
        }
        syncBookStatus(id);
        savedId = id;
        save();
        return true;
    }

    bool deleteBook(string bookId, out string err) {
        if (activeIssueCountForBook(bookId) > 0) {
            err = "Cannot delete a book while copies are currently issued.";
            return false;
        }
        ptrdiff_t idx = -1;
        foreach (i, ref b; books) {
            if (b.get("id") == bookId) {
                idx = i;
                break;
            }
        }
        if (idx < 0) {
            err = "Book not found.";
            return false;
        }
        books = books[0 .. idx] ~ books[idx + 1 .. $];
        save();
        return true;
    }

    // --- Member Operations ---

    Record* findMemberByCnic(string rawCnic) {
        string norm = normalizeCnic(rawCnic);
        if (norm.length == 0) return null;
        foreach (ref m; members) {
            if (normalizeCnic(m.get("cnic")) == norm)
                return &m;
        }
        return null;
    }

    int activeIssueCountForMember(string rawCnic) {
        string norm = normalizeCnic(rawCnic);
        int count = 0;
        foreach (ref iss; issues) {
            if (normalizeCnic(iss.get("member_cnic")) == norm && iss.get("returned_at").length == 0)
                count++;
        }
        return count;
    }

    bool upsertMember(Record rec, out string savedCnic, out string err) {
        string cnic = normalizeCnic(rec.get("cnic"));
        if (cnic.length == 0) {
            err = "CNIC is required (digits only, without dashes).";
            return false;
        }
        rec.set("cnic", cnic);

        if (rec.get("name").length == 0) {
            err = "Member Name is required.";
            return false;
        }
        string role = rec.get("role");
        if (role != "Student" && role != "Teacher") {
            role = "Student";
            rec.set("role", role);
        }

        foreach (f; schemas[EntityType.member]) {
            if (!f.core && f.required && rec.get(f.key).length == 0) {
                err = f.label ~ " is required.";
                return false;
            }
            if (f.key !in rec.data) {
                rec.data[f.key] = "";
            }
        }

        bool found = false;
        foreach (ref m; members) {
            if (normalizeCnic(m.get("cnic")) == cnic) {
                m = rec;
                found = true;
                break;
            }
        }
        if (!found) {
            members ~= rec;
        }
        savedCnic = cnic;
        save();
        return true;
    }

    bool deleteMember(string rawCnic, out string err) {
        string cnic = normalizeCnic(rawCnic);
        if (activeIssueCountForMember(cnic) > 0) {
            err = "Cannot delete a member who has unreturned books.";
            return false;
        }
        ptrdiff_t idx = -1;
        foreach (i, ref m; members) {
            if (normalizeCnic(m.get("cnic")) == cnic) {
                idx = i;
                break;
            }
        }
        if (idx < 0) {
            err = "Member not found.";
            return false;
        }
        members = members[0 .. idx] ~ members[idx + 1 .. $];
        save();
        return true;
    }

    // --- Circulation (Issue & Return) ---

    /// Issue a book to an existing member or create the member on the fly if CNIC is not registered.
    bool issueBook(
        string bookId,
        string rawCnic,
        Record newMemberRecordIfMissing,
        string dueDateIso,
        Record extraIssueFields,
        out string issueId,
        out string err
    ) {
        auto book = findBook(bookId);
        if (!book) {
            err = "Select a valid book to issue.";
            return false;
        }
        if (availableCopiesForBook(bookId) <= 0) {
            err = "No available copies left for \"" ~ book.get("title") ~ "\".";
            return false;
        }

        string cnic = normalizeCnic(rawCnic);
        if (cnic.length == 0) {
            err = "Member CNIC is required.";
            return false;
        }

        auto existingMember = findMemberByCnic(cnic);
        if (!existingMember) {
            newMemberRecordIfMissing.set("cnic", cnic);
            string savedCnic;
            if (!upsertMember(newMemberRecordIfMissing, savedCnic, err)) {
                return false;
            }
        }

        Record issue = extraIssueFields;
        issueId = "I-" ~ to!string(nextIssueSeq++);
        issue.set("id", issueId);
        issue.set("book_id", bookId);
        issue.set("member_cnic", cnic);
        issue.set("issued_at", todayIso());
        issue.set("due_at", dueDateIso.strip().length ? dueDateIso.strip() : datePlusDaysIso(14));
        issue.set("returned_at", "");

        foreach (f; schemas[EntityType.issue]) {
            if (!f.core && f.required && issue.get(f.key).length == 0) {
                err = f.label ~ " is required.";
                return false;
            }
            if (f.key !in issue.data) {
                issue.data[f.key] = "";
            }
        }

        issues = [issue] ~ issues;
        syncBookStatus(bookId);
        save();
        return true;
    }

    bool returnIssue(string issueId, out string err) {
        foreach (ref iss; issues) {
            if (iss.get("id") == issueId) {
                if (iss.get("returned_at").length > 0) {
                    err = "This book has already been returned.";
                    return false;
                }
                iss.set("returned_at", todayIso());
                syncBookStatus(iss.get("book_id"));
                save();
                return true;
            }
        }
        err = "Issue record not found.";
        return false;
    }

    // --- Persistence ---

    void save() {
        string dir = dirName(filePath);
        if (dir.length > 0 && dir != "." && !exists(dir)) {
            mkdirRecurse(dir);
        }

        JSONValue root = JSONValue(string[string].init);
        root.object["nextBookSeq"] = JSONValue(nextBookSeq);
        root.object["nextIssueSeq"] = JSONValue(nextIssueSeq);

        JSONValue schemasJson = JSONValue(string[string].init);
        foreach (entityType, fieldList; schemas) {
            JSONValue[] arr;
            foreach (f; fieldList) {
                JSONValue fj = JSONValue(string[string].init);
                fj.object["key"] = JSONValue(f.key);
                fj.object["label"] = JSONValue(f.label);
                fj.object["type"] = JSONValue(cast(string) f.type);
                fj.object["core"] = JSONValue(f.core);
                fj.object["required"] = JSONValue(f.required);
                fj.object["width"] = JSONValue(f.width);
                arr ~= fj;
            }
            schemasJson.object[cast(string) entityType] = JSONValue(arr);
        }
        root.object["schemas"] = schemasJson;

        static JSONValue serializeRecords(Record[] recs, FieldDef[] schemaFields) {
            JSONValue[] arr;
            foreach (r; recs) {
                JSONValue obj = JSONValue(string[string].init);
                // Ensure all schema fields exist in serialized JSON
                foreach (f; schemaFields) {
                    obj.object[f.key] = JSONValue(r.get(f.key, ""));
                }
                // Preserve any extra keys on the record
                foreach (k, v; r.data) {
                    if (k !in obj.object)
                        obj.object[k] = JSONValue(v);
                }
                arr ~= obj;
            }
            return JSONValue(arr);
        }

        root.object["books"] = serializeRecords(books, schemaFor(EntityType.book));
        root.object["members"] = serializeRecords(members, schemaFor(EntityType.member));
        root.object["issuance"] = serializeRecords(issues, schemaFor(EntityType.issue));

        string tmpPath = filePath ~ ".tmp";
        std.file.write(tmpPath, root.toPrettyString());
        if (exists(filePath)) {
            remove(filePath);
        }
        rename(tmpPath, filePath);
    }

    void load() {
        string content = readText(filePath);
        JSONValue root = parseJSON(content);

        if ("nextBookSeq" in root.object)
            nextBookSeq = cast(int) root.object["nextBookSeq"].integer;
        if ("nextIssueSeq" in root.object)
            nextIssueSeq = cast(int) root.object["nextIssueSeq"].integer;
        else if ("nextLoanSeq" in root.object)
            nextIssueSeq = cast(int) root.object["nextLoanSeq"].integer;

        if ("schemas" in root.object) {
            auto sj = root.object["schemas"];
            foreach (EntityType et; [EntityType.book, EntityType.member, EntityType.issue]) {
                string key = cast(string) et;
                if (et == EntityType.issue && key !in sj.object && "loan" in sj.object) {
                    key = "loan";
                }
                if (key in sj.object) {
                    FieldDef[] list;
                    foreach (item; sj.object[key].array) {
                        FieldDef f;
                        f.key = item.object["key"].str;
                        f.label = item.object["label"].str;
                        f.type = cast(FieldType) item.object["type"].str;
                        f.core = item.object["core"].boolean;
                        f.required = item.object["required"].boolean;
                        if ("width" in item.object)
                            f.width = cast(int) item.object["width"].integer;
                        list ~= f;
                    }
                    schemas[et] = list;
                }
            }
        }

        static Record[] deserializeRecords(JSONValue arrVal) {
            Record[] res;
            foreach (item; arrVal.array) {
                Record r;
                foreach (k, v; item.object) {
                    if (v.type == JSONType.string)
                        r.set(k, v.str);
                    else if (v.type == JSONType.integer)
                        r.set(k, to!string(v.integer));
                    else if (v.type == JSONType.uinteger)
                        r.set(k, to!string(v.uinteger));
                    else if (v.type == JSONType.true_)
                        r.set(k, "true");
                    else if (v.type == JSONType.false_)
                        r.set(k, "false");
                }
                res ~= r;
            }
            return res;
        }

        if ("books" in root.object)
            books = deserializeRecords(root.object["books"]);
        if ("members" in root.object)
            members = deserializeRecords(root.object["members"]);
        if ("issuance" in root.object)
            issues = deserializeRecords(root.object["issuance"]);
        else if ("loans" in root.object)
            issues = deserializeRecords(root.object["loans"]);
    }
}
