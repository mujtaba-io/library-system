module report;

import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.format;
import std.math : ceil, round;
import std.path : dirName;
import std.string;
import std.uni : toLower;
import std.utf : toUTF32, toUTF8;
import std.zlib : compress;
import store;

// =============================================================================
// Urdu / Arabic Contextual Shaper & Visual BiDi Helper
// Shared between DLangUI rendering and PDF generation.
// =============================================================================

private struct ArabicForms {
    dchar isolated;
    dchar final_;
    dchar initial;
    dchar medial;
    bool joinsLeft;
}

private ArabicForms getArabicForms(dchar c) pure nothrow @nogc {
    switch (c) {
        case 0x0621: return ArabicForms(0xFE80, 0xFE80, 0xFE80, 0xFE80, false);
        case 0x0622: return ArabicForms(0xFE81, 0xFE82, 0xFE81, 0xFE82, false);
        case 0x0623: return ArabicForms(0xFE83, 0xFE84, 0xFE83, 0xFE84, false);
        case 0x0624: return ArabicForms(0xFE85, 0xFE86, 0xFE85, 0xFE86, false);
        case 0x0625: return ArabicForms(0xFE87, 0xFE88, 0xFE87, 0xFE88, false);
        case 0x0627: return ArabicForms(0xFE8D, 0xFE8E, 0xFE8D, 0xFE8E, false);
        case 0x0629: return ArabicForms(0xFE93, 0xFE94, 0xFE93, 0xFE94, false);
        case 0x062F: return ArabicForms(0xFEA9, 0xFEAA, 0xFEA9, 0xFEAA, false);
        case 0x0630: return ArabicForms(0xFEAB, 0xFEAC, 0xFEAB, 0xFEAC, false);
        case 0x0631: return ArabicForms(0xFEAD, 0xFEAE, 0xFEAD, 0xFEAE, false);
        case 0x0632: return ArabicForms(0xFEAF, 0xFEB0, 0xFEAF, 0xFEB0, false);
        case 0x0648: return ArabicForms(0xFEED, 0xFEEE, 0xFEED, 0xFEEE, false);
        case 0x0649: return ArabicForms(0xFEEF, 0xFEF0, 0xFEEF, 0xFEF0, false);
        case 0x0688: return ArabicForms(0xFB88, 0xFB89, 0xFB88, 0xFB89, false);
        case 0x0691: return ArabicForms(0xFB8C, 0xFB8D, 0xFB8C, 0xFB8D, false);
        case 0x0698: return ArabicForms(0xFB8A, 0xFB8B, 0xFB8A, 0xFB8B, false);
        case 0x06BA: return ArabicForms(0xFB9E, 0xFB9F, 0xFB9E, 0xFB9F, false);
        case 0x06C0: return ArabicForms(0xFBA4, 0xFBA5, 0xFBA4, 0xFBA5, false);
        case 0x06C2: return ArabicForms(0xFBA4, 0xFBA5, 0xFBA4, 0xFBA5, false);
        case 0x06C3: return ArabicForms(0xFE93, 0xFE94, 0xFE93, 0xFE94, false);
        case 0x06D2: return ArabicForms(0xFBAE, 0xFBAF, 0xFBAE, 0xFBAF, false);
        case 0x06D3: return ArabicForms(0xFBB0, 0xFBB1, 0xFBB0, 0xFBB1, false);

        case 0x0626: return ArabicForms(0xFE89, 0xFE8A, 0xFE8B, 0xFE8C, true);
        case 0x0628: return ArabicForms(0xFE8F, 0xFE90, 0xFE91, 0xFE92, true);
        case 0x067E: return ArabicForms(0xFB56, 0xFB57, 0xFB58, 0xFB59, true);
        case 0x062A: return ArabicForms(0xFE95, 0xFE96, 0xFE97, 0xFE98, true);
        case 0x0679: return ArabicForms(0xFB66, 0xFB67, 0xFB68, 0xFB69, true);
        case 0x062B: return ArabicForms(0xFE99, 0xFE9A, 0xFE9B, 0xFE9C, true);
        case 0x062C: return ArabicForms(0xFE9D, 0xFE9E, 0xFE9F, 0xFEA0, true);
        case 0x0686: return ArabicForms(0xFB7A, 0xFB7B, 0xFB7C, 0xFB7D, true);
        case 0x062D: return ArabicForms(0xFEA1, 0xFEA2, 0xFEA3, 0xFEA4, true);
        case 0x062E: return ArabicForms(0xFEA5, 0xFEA6, 0xFEA7, 0xFEA8, true);
        case 0x0633: return ArabicForms(0xFEB1, 0xFEB2, 0xFEB3, 0xFEB4, true);
        case 0x0634: return ArabicForms(0xFEB5, 0xFEB6, 0xFEB7, 0xFEB8, true);
        case 0x0635: return ArabicForms(0xFEB9, 0xFEBA, 0xFEBB, 0xFEBC, true);
        case 0x0636: return ArabicForms(0xFEBD, 0xFEBE, 0xFEBF, 0xFEC0, true);
        case 0x0637: return ArabicForms(0xFEC1, 0xFEC2, 0xFEC3, 0xFEC4, true);
        case 0x0638: return ArabicForms(0xFEC5, 0xFEC6, 0xFEC7, 0xFEC8, true);
        case 0x0639: return ArabicForms(0xFEC9, 0xFECA, 0xFECB, 0xFECC, true);
        case 0x063A: return ArabicForms(0xFECD, 0xFECE, 0xFECF, 0xFED0, true);
        case 0x0640: return ArabicForms(0x0640, 0x0640, 0x0640, 0x0640, true);
        case 0x0641: return ArabicForms(0xFED1, 0xFED2, 0xFED3, 0xFED4, true);
        case 0x0642: return ArabicForms(0xFED5, 0xFED6, 0xFED7, 0xFED8, true);
        case 0x0643: return ArabicForms(0xFED9, 0xFEDA, 0xFEDB, 0xFEDC, true);
        case 0x06A9: return ArabicForms(0xFB8E, 0xFB8F, 0xFB90, 0xFB91, true);
        case 0x06AF: return ArabicForms(0xFB92, 0xFB93, 0xFB94, 0xFB95, true);
        case 0x0644: return ArabicForms(0xFEDD, 0xFEDE, 0xFEDF, 0xFEE0, true);
        case 0x0645: return ArabicForms(0xFEE1, 0xFEE2, 0xFEE3, 0xFEE4, true);
        case 0x0646: return ArabicForms(0xFEE5, 0xFEE6, 0xFEE7, 0xFEE8, true);
        case 0x0647: return ArabicForms(0xFEE9, 0xFEEA, 0xFEEB, 0xFEEC, true);
        case 0x06C1: return ArabicForms(0xFBA6, 0xFBA7, 0xFBA8, 0xFBA9, true);
        case 0x06BE: return ArabicForms(0xFBAA, 0xFBAB, 0xFBAC, 0xFBAD, true);
        case 0x064A: return ArabicForms(0xFEF1, 0xFEF2, 0xFEF3, 0xFEF4, true);
        case 0x06CC: return ArabicForms(0xFBFC, 0xFBFD, 0xFBFE, 0xFBFF, true);
        default:     return ArabicForms(0, 0, 0, 0, false);
    }
}

private bool isArabicChar(dchar c) pure nothrow @nogc {
    return (c >= 0x0600 && c <= 0x06FF) || (c >= 0x0750 && c <= 0x077F) ||
           (c >= 0xFB50 && c <= 0xFDFF) || (c >= 0xFE70 && c <= 0xFEFF);
}

private dchar mirrorBracket(dchar c) pure nothrow @nogc {
    switch (c) {
        case '(': return ')';
        case ')': return '(';
        case '[': return ']';
        case ']': return '[';
        case '{': return '}';
        case '}': return '{';
        default:  return c;
    }
}

/// Shape Urdu/Arabic text into connected Presentation Forms and reorder RTL segments
/// for left-to-right glyph renderers (both DLangUI and PDF).
dstring shapeForDisplay(dstring input) {
    bool hasRtl = false;
    foreach (dchar c; input) {
        if (isArabicChar(c)) {
            hasRtl = true;
            break;
        }
    }
    if (!hasRtl)
        return input;

    dchar[] shaped;
    shaped.reserve(input.length);

    size_t n = input.length;
    for (size_t i = 0; i < n; i++) {
        dchar curr = input[i];
        auto currF = getArabicForms(curr);
        if (currF.isolated == 0) {
            shaped ~= curr;
            continue;
        }

        bool prevJoins = false;
        if (i > 0) {
            auto prevF = getArabicForms(input[i - 1]);
            if (prevF.isolated != 0 && prevF.joinsLeft)
                prevJoins = true;
        }

        // Lam + Alef ligature
        if (curr == 0x0644 && i + 1 < n) {
            dchar next = input[i + 1];
            dchar ligIso = 0, ligFin = 0;
            if (next == 0x0622)      { ligIso = 0xFEF5; ligFin = 0xFEF6; }
            else if (next == 0x0623) { ligIso = 0xFEF7; ligFin = 0xFEF8; }
            else if (next == 0x0625) { ligIso = 0xFEF9; ligFin = 0xFEFA; }
            else if (next == 0x0627) { ligIso = 0xFEFB; ligFin = 0xFEFC; }
            if (ligIso != 0) {
                shaped ~= prevJoins ? ligFin : ligIso;
                i++;
                continue;
            }
        }

        bool nextJoins = false;
        if (currF.joinsLeft && i + 1 < n) {
            auto nextF = getArabicForms(input[i + 1]);
            if (nextF.isolated != 0)
                nextJoins = true;
        }

        if (prevJoins && nextJoins)
            shaped ~= currF.medial;
        else if (prevJoins && !nextJoins)
            shaped ~= currF.final_;
        else if (!prevJoins && nextJoins)
            shaped ~= currF.initial;
        else
            shaped ~= currF.isolated;
    }

    dchar[] result;
    result.reserve(shaped.length);

    size_t idx = 0;
    while (idx < shaped.length) {
        if (!isArabicChar(shaped[idx])) {
            if ((shaped[idx] == '(' || shaped[idx] == '[') && idx + 1 < shaped.length && isArabicChar(shaped[idx + 1])) {
                // Include leading bracket in RTL segment
            } else {
                result ~= shaped[idx];
                idx++;
                continue;
            }
        }

        size_t start = idx;
        size_t end = idx;
        size_t i = idx;
        while (i < shaped.length) {
            dchar c = shaped[i];
            if (isArabicChar(c) || c == ')' || c == ']') {
                i++;
                end = i;
            } else if (c == ' ' || c == '(' || c == '[' || c == '-' || c == '/' || c == ':' || (c >= '0' && c <= '9')) {
                i++;
            } else {
                break;
            }
        }
        while (end < i && (shaped[end] == ')' || shaped[end] == ']'))
            end++;

        dchar[] rtlSlice = shaped[start .. end];
        dchar[] visualRtl;
        visualRtl.length = rtlSlice.length;
        foreach (k, ch; rtlSlice) {
            visualRtl[rtlSlice.length - 1 - k] = mirrorBracket(ch);
        }
        size_t d = 0;
        while (d < visualRtl.length) {
            if (visualRtl[d] >= '0' && visualRtl[d] <= '9') {
                size_t dEnd = d + 1;
                while (dEnd < visualRtl.length && visualRtl[dEnd] >= '0' && visualRtl[dEnd] <= '9')
                    dEnd++;
                if (dEnd - d > 1) {
                    visualRtl[d .. dEnd].reverse();
                }
                d = dEnd;
            } else {
                d++;
            }
        }

        result ~= visualRtl;
        idx = end;
    }

    return cast(dstring) result;
}

// =============================================================================
// Report Options, Grouping, & Summary Structures
// =============================================================================

struct ReportOptions {
    string groupByKey = "category";
    string filterGroupValue = "";  /// Empty = include all groups
    string searchQuery = "";
    bool availableOnly = false;
    string[] tableColumnKeys;      /// Empty = auto-pick clean default columns
    string reportTitle = "College Library — Books Report";
    bool pageBreakPerGroup = false;
}

struct ReportGroup {
    string heading;
    Record[] books;
    int totalCopies;
}

struct ReportResult {
    bool ok = false;
    string error;
    string outputPath;
    int pageCount = 0;
    int groupCount = 0;
    int bookCount = 0;
    int totalCopies = 0;
}

/// Returns the default subject/category schema column key.
string defaultSubjectColumnKey(FieldDef[] schema) {
    foreach (f; schema) {
        if (f.key.toLower() == "subject" || f.label.toLower() == "subject")
            return f.key;
    }
    foreach (f; schema) {
        if (f.key.toLower() == "category")
            return f.key;
    }
    return schema.length > 0 ? schema[0].key : "category";
}

/// Human-friendly label for a schema field, annotating 'Category' as 'Category (Subject)'.
string reportFieldDisplayLabel(FieldDef f) {
    if (f.key.toLower() == "category" && f.label.toLower() == "category")
        return "Category (Subject)";
    return f.label;
}

/// Build a descriptive, non-colliding default PDF path that includes both
/// the segregation criterion (schema column) and the selected filter value ('all' if unfiltered).
string defaultReportPdfPathFor(string colKey, string filterVal = "") {
    string cleanKey = (colKey.toLower() == "category") ? "subject" : LibraryStore.sanitizeKey(colKey);
    if (cleanKey.length == 0) cleanKey = "books";

    string cleanVal;
    string trimmedFilter = filterVal.strip();
    if (trimmedFilter.length == 0) {
        cleanVal = "all";
    } else {
        cleanVal = LibraryStore.sanitizeKey(trimmedFilter);
        if (cleanVal.length == 0) {
            // Preserve safe Unicode characters (e.g. Urdu author/title) for Windows filenames
            dchar[] safe;
            bool lastUnder = false;
            foreach (dchar c; toUTF32(trimmedFilter)) {
                if (c == '/' || c == '\\' || c == ':' || c == '*' || c == '?' ||
                    c == '"' || c == '<' || c == '>' || c == '|' || c < 32) {
                    continue;
                }
                if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
                    if (!lastUnder && safe.length > 0) {
                        safe ~= '_';
                        lastUnder = true;
                    }
                } else {
                    safe ~= c;
                    lastUnder = false;
                }
                if (safe.length >= 40) break;
            }
            while (safe.length > 0 && safe[$ - 1] == '_')
                safe = safe[0 .. $ - 1];
            cleanVal = safe.length > 0 ? toUTF8(cast(dstring) safe) : "filtered";
        } else if (cleanVal.length > 40) {
            cleanVal = cleanVal[0 .. 40];
            while (cleanVal.length > 0 && cleanVal[$ - 1] == '_')
                cleanVal = cleanVal[0 .. $ - 1];
        }
    }

    return "reports/books_by_" ~ cleanKey ~ "_" ~ cleanVal ~ "_" ~ todayIso() ~ ".pdf";
}

/// Default columns to include in the PDF table (excluding the groupBy column to avoid redundancy).
string[] defaultReportTableColumns(FieldDef[] schema, string groupByKey) {
    static immutable string[] preferred = [
        "accessionNo", "title", "author", "category", "edition", "copies", "status"
    ];
    string[] cols;
    foreach (pk; preferred) {
        if (pk == groupByKey) continue;
        foreach (f; schema) {
            if (f.key == pk) {
                cols ~= f.key;
                break;
            }
        }
    }
    // Always ensure at least title or first non-group column
    if (cols.length == 0) {
        foreach (f; schema) {
            if (f.key != groupByKey) {
                cols ~= f.key;
                if (cols.length >= 5) break;
            }
        }
    }
    return cols;
}

/// Compute all distinct group headings and their counts for a given schema column.
ReportGroup[] buildReportGroups(LibraryStore store, ReportOptions opts) {
    auto schema = store.schemaFor(EntityType.book);
    string groupKey = opts.groupByKey.length > 0 ? opts.groupByKey : defaultSubjectColumnKey(schema);

    FieldType groupFieldType = FieldType.text;
    foreach (f; schema) {
        if (f.key == groupKey) {
            groupFieldType = f.type;
            break;
        }
    }

    string q = opts.searchQuery.strip().toLower();
    string filterVal = opts.filterGroupValue.strip();

    Record[][string] buckets;
    string[string] canonicalHeading;

    foreach (ref b; store.books) {
        string id = b.get("id");
        if (opts.availableOnly && store.availableCopiesForBook(id) <= 0)
            continue;

        if (q.length > 0) {
            bool match = false;
            foreach (k, v; b.data) {
                if (v.toLower().canFind(q)) {
                    match = true;
                    break;
                }
            }
            if (!match) continue;
        }

        string rawVal = b.get(groupKey).strip();
        if (rawVal.length == 0 || rawVal.toLower() == "na" || rawVal.toLower() == "n/a") {
            rawVal = "Unspecified";
        }

        string normKey = rawVal.toLower();
        if (filterVal.length > 0 && normKey != filterVal.toLower())
            continue;

        if (normKey !in canonicalHeading) {
            canonicalHeading[normKey] = rawVal;
        }
        buckets[normKey] ~= b;
    }

    ReportGroup[] groups;
    foreach (normKey, list; buckets) {
        ReportGroup g;
        g.heading = canonicalHeading[normKey];

        // Sort books inside each group by Title, then Author, then ID
        Record[] sortedBooks = list.dup;
        sortedBooks.sort!((a, b) {
            string ta = a.get("title").toLower();
            string tb = b.get("title").toLower();
            if (ta != tb) return ta < tb;
            string aa = a.get("author").toLower();
            string ab = b.get("author").toLower();
            if (aa != ab) return aa < ab;
            return a.get("id") < b.get("id");
        });
        g.books = sortedBooks;

        int copies = 0;
        foreach (ref bk; g.books) {
            copies += store.totalCopiesForBook(bk.get("id"));
        }
        g.totalCopies = copies;
        groups ~= g;
    }

    // Sort groups cleanly (Unspecified always last)
    groups.sort!((a, b) {
        bool aUn = (a.heading == "Unspecified");
        bool bUn = (b.heading == "Unspecified");
        if (aUn != bUn) return !aUn;
        if (groupFieldType == FieldType.number) {
            try {
                return to!double(a.heading) < to!double(b.heading);
            } catch (Exception) {}
        }
        return a.heading.toLower() < b.heading.toLower();
    });

    return groups;
}

// =============================================================================
// Minimal TrueType Font Reader (for Full Unicode + Urdu PDF Embedding)
// =============================================================================

private ushort readU16BE(const(ubyte)[] data, size_t off) pure nothrow @nogc {
    return cast(ushort)((cast(uint) data[off] << 8) | cast(uint) data[off + 1]);
}

private short readI16BE(const(ubyte)[] data, size_t off) pure nothrow @nogc {
    return cast(short) readU16BE(data, off);
}

private uint readU32BE(const(ubyte)[] data, size_t off) pure nothrow @nogc {
    return (cast(uint) data[off] << 24) |
           (cast(uint) data[off + 1] << 16) |
           (cast(uint) data[off + 2] << 8) |
           cast(uint) data[off + 3];
}

private class TrueTypeFont {
    string psName;
    ubyte[] rawData;
    ushort unitsPerEm = 2048;
    short xMin = -500, yMin = -300, xMax = 2000, yMax = 1800;
    short ascent = 1500, descent = -400;
    ushort numGlyphs = 0;
    ushort[] glyphWidths1000;   // scaled to 1000-unit PDF glyph space
    ushort[dchar] cpToGid;
    dchar[ushort] usedGidToCp;  // tracks glyphs actually used in document

    static TrueTypeFont tryLoad(string[] candidatePaths, string postScriptName) {
        foreach (path; candidatePaths) {
            if (!exists(path)) continue;
            try {
                auto bytes = cast(ubyte[]) std.file.read(path);
                auto f = new TrueTypeFont();
                f.psName = postScriptName;
                if (f.parse(bytes))
                    return f;
            } catch (Exception) {}
        }
        return null;
    }

    private bool parse(ubyte[] data) {
        if (data.length < 12) return false;
        rawData = data;
        ushort numTables = readU16BE(data, 4);
        if (12 + cast(size_t) numTables * 16 > data.length) return false;

        struct TableSpan { uint off; uint len; }
        TableSpan[string] tables;
        for (size_t i = 0; i < numTables; i++) {
            size_t p = 12 + i * 16;
            string tag = cast(string) data[p .. p + 4].idup;
            uint off = readU32BE(data, p + 8);
            uint len = readU32BE(data, p + 12);
            if (off + len <= data.length)
                tables[tag] = TableSpan(off, len);
        }

        if ("head" !in tables || "hhea" !in tables || "maxp" !in tables ||
            "hmtx" !in tables || "cmap" !in tables)
            return false;

        // head
        auto head = tables["head"];
        if (head.len < 44) return false;
        unitsPerEm = readU16BE(data, head.off + 18);
        if (unitsPerEm == 0) unitsPerEm = 2048;
        xMin = readI16BE(data, head.off + 36);
        yMin = readI16BE(data, head.off + 38);
        xMax = readI16BE(data, head.off + 40);
        yMax = readI16BE(data, head.off + 42);

        // hhea
        auto hhea = tables["hhea"];
        if (hhea.len < 36) return false;
        ascent = readI16BE(data, hhea.off + 4);
        descent = readI16BE(data, hhea.off + 6);
        ushort numHMetrics = readU16BE(data, hhea.off + 34);

        // maxp
        auto maxp = tables["maxp"];
        if (maxp.len < 6) return false;
        numGlyphs = readU16BE(data, maxp.off + 4);
        if (numGlyphs == 0) return false;

        // hmtx
        auto hmtx = tables["hmtx"];
        glyphWidths1000.length = numGlyphs;
        ushort lastAw = 500;
        for (size_t g = 0; g < numGlyphs; g++) {
            ushort rawAw;
            if (g < numHMetrics && (g * 4 + 2) <= hmtx.len) {
                rawAw = readU16BE(data, hmtx.off + g * 4);
                lastAw = rawAw;
            } else {
                rawAw = lastAw;
            }
            glyphWidths1000[g] = cast(ushort) round(cast(double) rawAw * 1000.0 / cast(double) unitsPerEm);
        }

        // cmap (format 4 BMP)
        auto cmap = tables["cmap"];
        if (cmap.len < 4) return false;
        ushort numSub = readU16BE(data, cmap.off + 2);
        uint subOff = 0;
        for (size_t i = 0; i < numSub; i++) {
            size_t p = cmap.off + 4 + i * 8;
            if (p + 8 > data.length) break;
            ushort pid = readU16BE(data, p);
            ushort eid = readU16BE(data, p + 2);
            uint rel = readU32BE(data, p + 4);
            if ((pid == 3 && eid == 1) || (pid == 0 && eid == 3)) {
                subOff = cmap.off + rel;
                if (pid == 3 && eid == 1) break;
            }
        }
        if (subOff == 0 || subOff + 14 > data.length) return false;
        ushort fmt = readU16BE(data, subOff);
        if (fmt != 4) return false;

        ushort segCountX2 = readU16BE(data, subOff + 6);
        size_t segCount = segCountX2 / 2;
        size_t endCodeOff = subOff + 14;
        size_t startCodeOff = endCodeOff + segCountX2 + 2;
        size_t idDeltaOff = startCodeOff + segCountX2;
        size_t idRangeOffsetOff = idDeltaOff + segCountX2;

        if (idRangeOffsetOff + segCountX2 > data.length) return false;

        for (size_t s = 0; s < segCount; s++) {
            ushort endC = readU16BE(data, endCodeOff + s * 2);
            ushort startC = readU16BE(data, startCodeOff + s * 2);
            short idDelta = readI16BE(data, idDeltaOff + s * 2);
            ushort idRangeOff = readU16BE(data, idRangeOffsetOff + s * 2);
            if (startC == 0xFFFF && endC == 0xFFFF) break;

            for (uint cp = startC; cp <= endC; cp++) {
                ushort gid = 0;
                if (idRangeOff == 0) {
                    gid = cast(ushort)((cp + cast(int) idDelta) & 0xFFFF);
                } else {
                    size_t glyphIndexAddr = (idRangeOffsetOff + s * 2) + idRangeOff + (cp - startC) * 2;
                    if (glyphIndexAddr + 2 <= data.length) {
                        ushort val = readU16BE(data, glyphIndexAddr);
                        if (val != 0)
                            gid = cast(ushort)((val + cast(int) idDelta) & 0xFFFF);
                    }
                }
                if (gid != 0 && gid < numGlyphs) {
                    cpToGid[cast(dchar) cp] = gid;
                }
            }
        }

        // Pre-register space so font always has at least 1 used glyph
        gidFor(' ');
        return cpToGid.length > 50;
    }

    ushort gidFor(dchar cp) {
        if (auto p = cp in cpToGid) {
            ushort gid = *p;
            if (gid !in usedGidToCp)
                usedGidToCp[gid] = cp;
            return gid;
        }
        // Fallback for smart punctuation or unmapped chars
        if (cp == 0x2018 || cp == 0x2019) return gidFor('\'');
        if (cp == 0x201C || cp == 0x201D) return gidFor('"');
        if (cp == 0x2013 || cp == 0x2014) return gidFor('-');
        if (auto p = '?' in cpToGid) {
            ushort gid = *p;
            if (gid !in usedGidToCp) usedGidToCp[gid] = '?';
            return gid;
        }
        return 0;
    }

    double measureText(dstring shapedText, double fontSize) {
        double total = 0.0;
        foreach (dchar c; shapedText) {
            ushort gid = gidFor(c);
            ushort w = (gid < glyphWidths1000.length) ? glyphWidths1000[gid] : 500;
            total += w;
        }
        return (total / 1000.0) * fontSize;
    }

    string encodeHexGlyphs(dstring shapedText) {
        static immutable char[16] hex = "0123456789ABCDEF";
        char[] outBuf;
        outBuf.reserve(shapedText.length * 4 + 2);
        outBuf ~= '<';
        foreach (dchar c; shapedText) {
            ushort gid = gidFor(c);
            outBuf ~= hex[(gid >> 12) & 0xF];
            outBuf ~= hex[(gid >> 8) & 0xF];
            outBuf ~= hex[(gid >> 4) & 0xF];
            outBuf ~= hex[gid & 0xF];
        }
        outBuf ~= '>';
        return cast(string) outBuf;
    }

    string buildWidthsArray() {
        ushort[] gids = usedGidToCp.keys.dup;
        gids.sort();
        auto app = appender!string();
        app.put("[");
        foreach (gid; gids) {
            ushort w = (gid < glyphWidths1000.length) ? glyphWidths1000[gid] : 500;
            app.put(format("%d [%d] ", gid, w));
        }
        app.put("]");
        return app.data;
    }

    string buildToUnicodeCMap() {
        ushort[] gids = usedGidToCp.keys.dup;
        gids.sort();
        auto app = appender!string();
        app.put("/CIDInit /ProcSet findresource begin\n");
        app.put("12 dict begin\n");
        app.put("begincmap\n");
        app.put("/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def\n");
        app.put("/CMapName /Adobe-Identity-UCS def\n");
        app.put("/CMapType 2 def\n");
        app.put("1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange\n");

        size_t i = 0;
        while (i < gids.length) {
            size_t chunk = min(cast(size_t) 100, gids.length - i);
            app.put(format("%d beginbfchar\n", chunk));
            for (size_t k = 0; k < chunk; k++) {
                ushort gid = gids[i + k];
                uint cp = cast(uint) usedGidToCp[gid];
                if (cp > 0xFFFF) cp = '?';
                app.put(format("<%04X> <%04X>\n", gid, cp));
            }
            app.put("endbfchar\n");
            i += chunk;
        }

        app.put("endcmap\n");
        app.put("CMapName currentdict /CMap defineresource pop\n");
        app.put("end\nend\n");
        return app.data;
    }
}

// =============================================================================
// Pure-D PDF 1.4 Document Writer (Vector Tables + Unicode TTF + FlateDecode)
// =============================================================================

private class PdfWriter {
    double pageW;
    double pageH;
    TrueTypeFont fontRegular;
    TrueTypeFont fontBold;
    bool useTrueType = false;

    Appender!string[] pages;
    size_t currentPage = 0;

    this(double widthPt, double heightPt) {
        this.pageW = widthPt;
        this.pageH = heightPt;
        fontRegular = TrueTypeFont.tryLoad([
            `C:\Windows\Fonts\arial.ttf`,
            `C:\Windows\Fonts\tahoma.ttf`,
            `C:\Windows\Fonts\segoeui.ttf`
        ], "LibSysSans-Regular");
        fontBold = TrueTypeFont.tryLoad([
            `C:\Windows\Fonts\arialbd.ttf`,
            `C:\Windows\Fonts\tahomabd.ttf`,
            `C:\Windows\Fonts\segoeuib.ttf`
        ], "LibSysSans-Bold");

        if (fontRegular !is null && fontBold is null)
            fontBold = fontRegular;
        useTrueType = (fontRegular !is null && fontBold !is null);
    }

    void newPage() {
        pages ~= appender!string();
        currentPage = pages.length - 1;
    }

    private ref Appender!string buf() {
        return pages[currentPage];
    }

    private double pdfY(double yTop) const {
        return pageH - yTop;
    }

    void fillRect(double x, double yTop, double w, double h, double r, double g, double b) {
        double yBottom = pageH - yTop - h;
        buf.put(format("%.3f %.3f %.3f rg %.2f %.2f %.2f %.2f re f\n", r, g, b, x, yBottom, w, h));
    }

    void strokeRect(double x, double yTop, double w, double h, double r, double g, double b, double lw = 0.5) {
        double yBottom = pageH - yTop - h;
        buf.put(format("%.2f w %.3f %.3f %.3f RG %.2f %.2f %.2f %.2f re S\n", lw, r, g, b, x, yBottom, w, h));
    }

    void drawLine(double x1, double y1Top, double x2, double y2Top, double r, double g, double b, double lw = 0.5) {
        buf.put(format("%.2f w %.3f %.3f %.3f RG %.2f %.2f m %.2f %.2f l S\n",
            lw, r, g, b, x1, pdfY(y1Top), x2, pdfY(y2Top)));
    }

    double measureText(string text, double fontSize, bool bold) {
        if (text.length == 0) return 0.0;
        if (useTrueType) {
            dstring shaped = shapeForDisplay(toUTF32(text));
            auto f = bold ? fontBold : fontRegular;
            return f.measureText(shaped, fontSize);
        }
        // Approximate Helvetica average width
        double factor = bold ? 0.56 : 0.52;
        return cast(double) text.length * fontSize * factor;
    }

    private static string escapeAsciiPdf(string s) {
        auto app = appender!string();
        foreach (dchar c; toUTF32(s)) {
            if (c == 0x2018 || c == 0x2019) app.put('\'');
            else if (c == 0x201C || c == 0x201D) app.put('"');
            else if (c == 0x2013 || c == 0x2014) app.put('-');
            else if (c == '(' || c == ')' || c == '\\') {
                app.put('\\');
                app.put(cast(char) c);
            } else if (c >= 32 && c <= 126) {
                app.put(cast(char) c);
            } else {
                app.put('?');
            }
        }
        return app.data;
    }

    void drawTextOnPage(size_t pageIdx, double x, double baselineYTop, string text,
                        double fontSize, bool bold, double r, double g, double b,
                        bool alignRight = false) {
        if (text.length == 0) return;
        double drawX = x;
        if (alignRight) {
            drawX = x - measureText(text, fontSize, bold);
        }
        string fontRes = bold ? "/F2" : "/F1";
        double by = pageH - baselineYTop;
        auto p = &pages[pageIdx];
        p.put(format("BT %.3f %.3f %.3f rg %s %.2f Tf 1 0 0 1 %.2f %.2f Tm ",
            r, g, b, fontRes, fontSize, drawX, by));
        if (useTrueType) {
            dstring shaped = shapeForDisplay(toUTF32(text));
            auto f = bold ? fontBold : fontRegular;
            p.put(f.encodeHexGlyphs(shaped));
            p.put(" Tj ET\n");
        } else {
            p.put("(");
            p.put(escapeAsciiPdf(text));
            p.put(") Tj ET\n");
        }
    }

    void drawText(double x, double baselineYTop, string text, double fontSize, bool bold,
                  double r, double g, double b, bool alignRight = false) {
        drawTextOnPage(currentPage, x, baselineYTop, text, fontSize, bold, r, g, b, alignRight);
    }

    /// Word-wrap text cleanly to fit within maxWidth points.
    string[] wrapText(string raw, double fontSize, bool bold, double maxWidth) {
        string clean = raw.strip();
        if (clean.length == 0) return ["—"];
        if (maxWidth <= fontSize) return [clean];
        if (measureText(clean, fontSize, bold) <= maxWidth)
            return [clean];

        string[] words = clean.split();
        string[] lines;
        string curr = "";

        foreach (w; words) {
            string candidate = curr.length == 0 ? w : (curr ~ " " ~ w);
            if (measureText(candidate, fontSize, bold) <= maxWidth) {
                curr = candidate;
            } else {
                if (curr.length > 0) {
                    lines ~= curr;
                    curr = "";
                }
                // Handle single word wider than column by splitting on codepoints
                if (measureText(w, fontSize, bold) > maxWidth) {
                    dstring dw = toUTF32(w);
                    dchar[] part;
                    foreach (dchar ch; dw) {
                        string test = toUTF8(cast(dstring)(part ~ ch));
                        if (part.length > 0 && measureText(test, fontSize, bold) > maxWidth) {
                            lines ~= toUTF8(cast(dstring) part);
                            part = [ch];
                        } else {
                            part ~= ch;
                        }
                    }
                    curr = toUTF8(cast(dstring) part);
                } else {
                    curr = w;
                }
            }
        }
        if (curr.length > 0)
            lines ~= curr;
        return lines.length > 0 ? lines : ["—"];
    }

    /// Finalize PDF 1.4 binary bytes with compressed page streams and embedded TTF fonts.
    ubyte[] finalizeBytes() {
        struct PdfObj {
            ubyte[] content;
        }
        PdfObj[] objects; // 1-indexed via objects[id - 1]

        int addObj(const(ubyte)[] data) {
            objects ~= PdfObj(data.dup);
            return cast(int) objects.length;
        }
        int addStrObj(string s) {
            return addObj(cast(const(ubyte)[]) s);
        }
        int addStreamObj(string dictEntries, const(ubyte)[] streamData, bool doCompress = true) {
            const(ubyte)[] payload = doCompress ? cast(const(ubyte)[]) compress(streamData) : streamData;
            string filter = doCompress ? "/Filter /FlateDecode " : "";
            string header = format("<< %s%s/Length %d >>\nstream\n", dictEntries, filter, payload.length);
            ubyte[] combined;
            combined.reserve(header.length + payload.length + 11);
            combined ~= cast(const(ubyte)[]) header;
            combined ~= payload;
            combined ~= cast(const(ubyte)[]) "\nendstream";
            return addObj(combined);
        }

        // Helper to emit a Type0/CIDFontType2 TrueType font
        int emitTtfFont(TrueTypeFont f) {
            int fontFileId = addStreamObj(format("/Length1 %d ", f.rawData.length), f.rawData, true);
            int scale(int v) { return cast(int) round(cast(double) v * 1000.0 / cast(double) f.unitsPerEm); }
            int descId = addStrObj(format(
                "<< /Type /FontDescriptor /FontName /%s /Flags 32 " ~
                "/FontBBox [%d %d %d %d] /ItalicAngle 0 /Ascent %d /Descent %d " ~
                "/CapHeight %d /StemV 80 /FontFile2 %d 0 R >>",
                f.psName, scale(f.xMin), scale(f.yMin), scale(f.xMax), scale(f.yMax),
                scale(f.ascent), scale(f.descent), scale(f.ascent), fontFileId
            ));
            string widths = f.buildWidthsArray();
            int cidFontId = addStrObj(format(
                "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /%s " ~
                "/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> " ~
                "/FontDescriptor %d 0 R /DW 500 /W %s /CIDToGIDMap /Identity >>",
                f.psName, descId, widths
            ));
            string cmapStr = f.buildToUnicodeCMap();
            int toUnicodeId = addStreamObj("", cast(const(ubyte)[]) cmapStr, true);
            int type0Id = addStrObj(format(
                "<< /Type /Font /Subtype /Type0 /BaseFont /%s " ~
                "/Encoding /Identity-H /DescendantFonts [%d 0 R] /ToUnicode %d 0 R >>",
                f.psName, cidFontId, toUnicodeId
            ));
            return type0Id;
        }

        int f1Id, f2Id;
        if (useTrueType) {
            f1Id = emitTtfFont(fontRegular);
            f2Id = (fontBold is fontRegular) ? f1Id : emitTtfFont(fontBold);
        } else {
            f1Id = addStrObj("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>");
            f2Id = addStrObj("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>");
        }

        // Reserve Pages object ID
        int pagesObjId = addStrObj(""); // placeholder

        int[] pageObjIds;
        foreach (ref pg; pages) {
            int contentId = addStreamObj("", cast(const(ubyte)[]) pg.data, true);
            int pageId = addStrObj(format(
                "<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %.2f %.2f] " ~
                "/Resources << /Font << /F1 %d 0 R /F2 %d 0 R >> >> " ~
                "/Contents %d 0 R >>",
                pagesObjId, pageW, pageH, f1Id, f2Id, contentId
            ));
            pageObjIds ~= pageId;
        }

        auto kidsApp = appender!string();
        kidsApp.put("[");
        foreach (pid; pageObjIds) {
            kidsApp.put(format("%d 0 R ", pid));
        }
        kidsApp.put("]");

        objects[pagesObjId - 1].content = cast(ubyte[]) format(
            "<< /Type /Pages /Kids %s /Count %d >>",
            kidsApp.data, pageObjIds.length
        ).dup;

        int catalogId = addStrObj(format("<< /Type /Catalog /Pages %d 0 R >>", pagesObjId));

        // Assemble final PDF file with exact byte offsets
        auto outApp = appender!(ubyte[])();
        outApp.put(cast(const(ubyte)[]) "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n");

        size_t[] offsets;
        offsets.length = objects.length + 1; // 1-indexed
        for (size_t i = 0; i < objects.length; i++) {
            offsets[i + 1] = outApp.data.length;
            outApp.put(cast(const(ubyte)[]) format("%d 0 obj\n", i + 1));
            outApp.put(objects[i].content);
            outApp.put(cast(const(ubyte)[]) "\nendobj\n");
        }

        size_t xrefPos = outApp.data.length;
        outApp.put(cast(const(ubyte)[]) format("xref\n0 %d\n", objects.length + 1));
        outApp.put(cast(const(ubyte)[]) "0000000000 65535 f \n");
        for (size_t i = 1; i <= objects.length; i++) {
            outApp.put(cast(const(ubyte)[]) format("%010d 00000 n \n", offsets[i]));
        }

        outApp.put(cast(const(ubyte)[]) format(
            "trailer\n<< /Size %d /Root %d 0 R >>\nstartxref\n%d\n%%%%EOF\n",
            objects.length + 1, catalogId, xrefPos
        ));

        return outApp.data;
    }
}

// =============================================================================
// High-Level Books PDF Report Generator
// =============================================================================

/// Generate a styled, multi-page PDF report segregating books under headings
/// derived from any chosen schema column (default: subject / category).
ReportResult generateBooksPdfReport(LibraryStore store, ReportOptions opts, string outputPath) {
    ReportResult res;
    res.outputPath = outputPath;

    auto schema = store.schemaFor(EntityType.book);
    if (schema.length == 0) {
        res.error = "Book schema is empty.";
        return res;
    }

    string groupKey = opts.groupByKey.length > 0 ? opts.groupByKey : defaultSubjectColumnKey(schema);
    string groupLabel = groupKey;
    foreach (f; schema) {
        if (f.key == groupKey) {
            groupLabel = reportFieldDisplayLabel(f);
            break;
        }
    }

    ReportGroup[] groups = buildReportGroups(store, opts);
    if (groups.length == 0) {
        res.error = "No books match the selected filter criteria.";
        return res;
    }

    // Resolve table columns
    string[] colKeys = opts.tableColumnKeys.length > 0
        ? opts.tableColumnKeys
        : defaultReportTableColumns(schema, groupKey);

    FieldDef[] colDefs;
    foreach (ck; colKeys) {
        foreach (f; schema) {
            if (f.key == ck) {
                colDefs ~= f;
                break;
            }
        }
    }
    if (colDefs.length == 0) {
        foreach (f; schema) {
            if (f.key != groupKey) {
                colDefs ~= f;
                if (colDefs.length >= 5) break;
            }
        }
    }

    int totalBooks = 0;
    int totalCopies = 0;
    foreach (ref g; groups) {
        totalBooks += cast(int) g.books.length;
        totalCopies += g.totalCopies;
    }

    // Choose A4 Portrait for <= 6 data columns, A4 Landscape for wider tables
    bool landscape = colDefs.length > 6;
    double pageW = landscape ? 841.89 : 595.28;
    double pageH = landscape ? 595.28 : 841.89;
    double marginX = 36.0;
    double marginTop = 36.0;
    double marginBottom = 42.0;
    double contentW = pageW - 2.0 * marginX;
    double usableBottom = pageH - marginBottom;

    auto pdf = new PdfWriter(pageW, pageH);
    pdf.newPage();

    // Compute proportional column widths: [#] + selected schema columns
    double srColW = 26.0;
    double remainingW = contentW - srColW;
    double weightSum = 0.0;
    double[] colWeights;
    foreach (f; colDefs) {
        double w = f.width > 0 ? cast(double) f.width : 120.0;
        if (f.key == "title") w *= 1.30;
        else if (f.key == "author") w *= 1.05;
        else if (f.key == "accessionNo") w = 92.0;
        else if (f.key == "copies") w = 72.0;
        else if (f.key == "year") w = 64.0;
        else if (f.key == "status") w = 88.0;
        else if (f.key == "edition") w = 72.0;
        colWeights ~= w;
        weightSum += w;
    }
    double[] colWidths = [srColW];
    foreach (w; colWeights) {
        colWidths ~= (w / weightSum) * remainingW;
    }

    string[] headers = ["#"];
    foreach (f; colDefs) {
        headers ~= f.label;
    }

    // Colors (RGB 0..1)
    // Slate 900: (0.094, 0.094, 0.106)
    // Blue 600:  (0.145, 0.388, 0.922)
    // Blue 50:   (0.937, 0.965, 1.000)
    // Zinc 100:  (0.957, 0.957, 0.961)
    // Zinc 200:  (0.894, 0.894, 0.906)
    // Zinc 500:  (0.443, 0.443, 0.478)
    // Text Dark: (0.094, 0.094, 0.106)

    double y = marginTop;

    // --- Page 1 Title Banner ---
    double bannerH = 62.0;
    pdf.fillRect(marginX, y, contentW, bannerH, 0.094, 0.094, 0.106);
    pdf.fillRect(marginX, y, contentW, 4.0, 0.145, 0.388, 0.922);

    string titleStr = opts.reportTitle.strip().length > 0
        ? opts.reportTitle.strip()
        : "College Library — Books Report";
    pdf.drawText(marginX + 14.0, y + 27.0, titleStr, 15.0, true, 1.0, 1.0, 1.0);

    string subLine = format("Grouped by: %s   |   Date: %s   |   %d %s   |   %d %s   |   %d %s",
        groupLabel, todayIso(),
        groups.length, groups.length == 1 ? "Group" : "Groups",
        totalBooks, totalBooks == 1 ? "Book" : "Books",
        totalCopies, totalCopies == 1 ? "Copy" : "Copies");
    if (opts.filterGroupValue.strip().length > 0)
        subLine ~= "   |   Filter: " ~ opts.filterGroupValue.strip();
    if (opts.availableOnly)
        subLine ~= "   |   Available Only";
    pdf.drawText(marginX + 14.0, y + 46.0, subLine, 8.5, false, 0.83, 0.83, 0.86);
    y += bannerH + 14.0;

    // --- Summary Overview Table (when multiple groups exist) ---
    if (groups.length > 1) {
        pdf.drawText(marginX, y + 10.0, "Summary by " ~ groupLabel, 10.5, true, 0.094, 0.094, 0.106);
        y += 16.0;

        double sumHdrH = 18.0;
        double sumRowH = 16.0;
        double c1W = contentW * 0.56;
        double c2W = contentW * 0.22;
        double c3W = contentW * 0.22;

        void drawSummaryHeader() {
            pdf.fillRect(marginX, y, contentW, sumHdrH, 0.957, 0.957, 0.961);
            pdf.drawLine(marginX, y + sumHdrH, marginX + contentW, y + sumHdrH, 0.83, 0.83, 0.85, 0.8);
            pdf.drawText(marginX + 8.0, y + 12.5, groupLabel, 8.5, true, 0.247, 0.247, 0.275);
            pdf.drawText(marginX + c1W + c2W - 8.0, y + 12.5, "Titles", 8.5, true, 0.247, 0.247, 0.275, true);
            pdf.drawText(marginX + c1W + c2W + c3W - 8.0, y + 12.5, "Total Copies", 8.5, true, 0.247, 0.247, 0.275, true);
            y += sumHdrH;
        }

        drawSummaryHeader();
        foreach (gi, ref g; groups) {
            if (y + sumRowH > usableBottom) {
                pdf.newPage();
                y = marginTop;
                drawSummaryHeader();
            }
            if (gi % 2 == 1)
                pdf.fillRect(marginX, y, contentW, sumRowH, 0.98, 0.98, 0.985);
            pdf.drawLine(marginX, y + sumRowH, marginX + contentW, y + sumRowH, 0.92, 0.92, 0.93, 0.4);
            pdf.drawText(marginX + 8.0, y + 11.5, g.heading, 8.5, false, 0.094, 0.094, 0.106);
            pdf.drawText(marginX + c1W + c2W - 8.0, y + 11.5, to!string(g.books.length), 8.5, false, 0.094, 0.094, 0.106, true);
            pdf.drawText(marginX + c1W + c2W + c3W - 8.0, y + 11.5, to!string(g.totalCopies), 8.5, false, 0.094, 0.094, 0.106, true);
            y += sumRowH;
        }
        // Summary total footer row
        if (y + sumRowH > usableBottom) {
            pdf.newPage();
            y = marginTop;
        }
        pdf.fillRect(marginX, y, contentW, sumRowH + 2.0, 0.937, 0.965, 1.0);
        pdf.drawLine(marginX, y, marginX + contentW, y, 0.145, 0.388, 0.922, 0.8);
        pdf.drawText(marginX + 8.0, y + 12.5, "Total", 8.5, true, 0.118, 0.251, 0.686);
        pdf.drawText(marginX + c1W + c2W - 8.0, y + 12.5, to!string(totalBooks), 8.5, true, 0.118, 0.251, 0.686, true);
        pdf.drawText(marginX + c1W + c2W + c3W - 8.0, y + 12.5, to!string(totalCopies), 8.5, true, 0.118, 0.251, 0.686, true);
        y += sumRowH + 18.0;
    }

    // --- Table Rendering Helpers ---
    double headerRowH = 20.0;
    double bodyFontSize = landscape ? 8.0 : 8.2;
    double lineHeight = 10.8;
    double cellPadX = 5.0;
    double cellPadY = 4.0;

    void drawTableHeader() {
        pdf.fillRect(marginX, y, contentW, headerRowH, 0.957, 0.957, 0.961);
        pdf.drawLine(marginX, y, marginX + contentW, y, 0.83, 0.83, 0.85, 0.6);
        pdf.drawLine(marginX, y + headerRowH, marginX + contentW, y + headerRowH, 0.75, 0.75, 0.78, 0.8);
        double cx = marginX;
        foreach (ci, h; headers) {
            double cw = colWidths[ci];
            if (ci > 0)
                pdf.drawLine(cx, y, cx, y + headerRowH, 0.89, 0.89, 0.91, 0.4);
            // Clip header label cleanly if narrow
            auto hLines = pdf.wrapText(h, 8.0, true, cw - 2.0 * cellPadX);
            pdf.drawText(cx + cellPadX, y + 13.5, hLines[0], 8.0, true, 0.247, 0.247, 0.275);
            cx += cw;
        }
        y += headerRowH;
    }

    void drawGroupHeading(string heading, int bookCount, int copyCount, bool continued) {
        double hBar = continued ? 20.0 : 26.0;
        pdf.fillRect(marginX, y, contentW, hBar, 0.937, 0.965, 1.0);
        pdf.fillRect(marginX, y, 4.0, hBar, 0.145, 0.388, 0.922);
        pdf.drawLine(marginX, y + hBar, marginX + contentW, y + hBar, 0.75, 0.85, 0.99, 0.6);

        string titleText = continued ? (heading ~ " (continued)") : heading;
        double titleSize = continued ? 9.5 : 11.5;
        double textBaseY = continued ? (y + 13.5) : (y + 17.5);
        pdf.drawText(marginX + 12.0, textBaseY, titleText, titleSize, true, 0.094, 0.094, 0.106);

        string badge = format("%d %s · %d %s",
            bookCount, bookCount == 1 ? "Book" : "Books",
            copyCount, copyCount == 1 ? "Copy" : "Copies");
        pdf.drawText(marginX + contentW - 10.0, textBaseY, badge, 8.5, true, 0.145, 0.388, 0.922, true);
        y += hBar;
    }

    // --- Render Every Group Section + Its Book Table ---
    foreach (gi, ref g; groups) {
        if (opts.pageBreakPerGroup && (gi > 0 || groups.length > 1)) {
            if (y > marginTop + 5.0) {
                pdf.newPage();
                y = marginTop;
            }
        } else {
            // Keep heading + table header + at least one row together
            if (y + 26.0 + headerRowH + 22.0 > usableBottom) {
                pdf.newPage();
                y = marginTop;
            }
        }

        drawGroupHeading(g.heading, cast(int) g.books.length, g.totalCopies, false);
        drawTableHeader();

        foreach (bi, ref b; g.books) {
            // Prepare wrapped lines for every cell in this row
            string[][] cellLines;
            cellLines.length = headers.length;
            cellLines[0] = [to!string(bi + 1)];
            size_t maxLines = 1;

            foreach (ci, f; colDefs) {
                string val = b.get(f.key);
                if (val.length == 0) val = "—";
                auto wrapped = pdf.wrapText(val, bodyFontSize, false, colWidths[ci + 1] - 2.0 * cellPadX);
                cellLines[ci + 1] = wrapped;
                if (wrapped.length > maxLines)
                    maxLines = wrapped.length;
            }

            double rowH = cast(double) maxLines * lineHeight + 2.0 * cellPadY;
            if (rowH < 17.5) rowH = 17.5;

            if (y + rowH > usableBottom) {
                pdf.newPage();
                y = marginTop;
                drawGroupHeading(g.heading, cast(int) g.books.length, g.totalCopies, true);
                drawTableHeader();
            }

            // Zebra striping
            if (bi % 2 == 1) {
                pdf.fillRect(marginX, y, contentW, rowH, 0.98, 0.98, 0.985);
            }
            pdf.drawLine(marginX, y + rowH, marginX + contentW, y + rowH, 0.894, 0.894, 0.906, 0.45);

            double cx = marginX;
            for (size_t ci = 0; ci < headers.length; ci++) {
                double cw = colWidths[ci];
                if (ci > 0)
                    pdf.drawLine(cx, y, cx, y + rowH, 0.94, 0.94, 0.95, 0.35);

                double ty = y + cellPadY + bodyFontSize + 0.5;
                foreach (line; cellLines[ci]) {
                    bool isMuted = (line == "—" || line == "NA");
                    double tr = isMuted ? 0.63 : 0.094;
                    double tg = isMuted ? 0.63 : 0.094;
                    double tb = isMuted ? 0.67 : 0.106;
                    if (ci > 0 && colDefs[ci - 1].key == "status") {
                        if (line == "Available") { tr = 0.020; tg = 0.588; tb = 0.412; }
                        else if (line == "Issued") { tr = 0.863; tg = 0.149; tb = 0.149; }
                    }
                    pdf.drawText(cx + cellPadX, ty, line, bodyFontSize, false, tr, tg, tb);
                    ty += lineHeight;
                }
                cx += cw;
            }

            y += rowH;
        }

        // Spacing before next section
        y += 14.0;
    }

    // --- Add Page Footers with Exact Page X of Y ---
    size_t totalPages = pdf.pages.length;
    for (size_t pi = 0; pi < totalPages; pi++) {
        double footY = pageH - 22.0;
        pdf.pages[pi].put(format("0.5 w 0.894 0.894 0.906 RG %.2f %.2f m %.2f %.2f l S\n",
            marginX, pageH - (footY - 12.0), marginX + contentW, pageH - (footY - 12.0)));
        pdf.drawTextOnPage(pi, marginX, footY,
            "College Library Management System · Grouped by " ~ groupLabel,
            7.8, false, 0.443, 0.443, 0.478, false);
        pdf.drawTextOnPage(pi, marginX + contentW, footY,
            format("Page %d of %d", pi + 1, totalPages),
            7.8, true, 0.443, 0.443, 0.478, true);
    }

    // --- Write PDF File ---
    try {
        string dir = dirName(outputPath);
        if (dir.length > 0 && dir != "." && !exists(dir)) {
            mkdirRecurse(dir);
        }
        ubyte[] bytes = pdf.finalizeBytes();
        std.file.write(outputPath, bytes);
        res.ok = true;
        res.pageCount = cast(int) totalPages;
        res.groupCount = cast(int) groups.length;
        res.bookCount = totalBooks;
        res.totalCopies = totalCopies;
    } catch (Exception e) {
        res.error = "Failed to save PDF: " ~ e.msg;
    }

    return res;
}
