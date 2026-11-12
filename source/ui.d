module ui;

import dlangui;
import dlangui.widgets.grid;
import dlangui.widgets.combobox;
import std.algorithm;
import std.array;
import std.conv;
import std.string;
import std.uni : toLower;
import store;

// =============================================================================
// Note on DLangUI Colors:
// DLangUI uses 0xAARRGGBB where AA=0x00 is 100% OPAQUE and AA=0xFF is 100% TRANSPARENT.
// All solid colors below use 0x00RRGGBB (written as 0xRRGGBB).
// =============================================================================

// =============================================================================
// Urdu / Arabic Contextual Shaper & Visual BiDi Helper for DLangUI
// Converts logical Urdu/Arabic codepoints (U+0600..U+06FF) into connected
// Arabic Presentation Forms-A/B (U+FB50..U+FEFF) and reorders RTL runs for
// DLangUI's left-to-right glyph renderer.
// =============================================================================

private struct ArabicForms {
    dchar isolated;
    dchar final_;
    dchar initial;
    dchar medial;
    bool joinsLeft; // true = dual-joining, false = right-joining only
}

private ArabicForms getArabicForms(dchar c) pure nothrow @nogc {
    switch (c) {
        // Right-joining only letters (Dal, Raa, Waw, Alef variants, Yet/Bari Ye)
        case 0x0621: return ArabicForms(0xFE80, 0xFE80, 0xFE80, 0xFE80, false); // Hamza
        case 0x0622: return ArabicForms(0xFE81, 0xFE82, 0xFE81, 0xFE82, false); // Alef Madda
        case 0x0623: return ArabicForms(0xFE83, 0xFE84, 0xFE83, 0xFE84, false); // Alef Hamza Above
        case 0x0624: return ArabicForms(0xFE85, 0xFE86, 0xFE85, 0xFE86, false); // Waw Hamza
        case 0x0625: return ArabicForms(0xFE87, 0xFE88, 0xFE87, 0xFE88, false); // Alef Hamza Below
        case 0x0627: return ArabicForms(0xFE8D, 0xFE8E, 0xFE8D, 0xFE8E, false); // Alef
        case 0x0629: return ArabicForms(0xFE93, 0xFE94, 0xFE93, 0xFE94, false); // Teh Marbuta
        case 0x062F: return ArabicForms(0xFED9, 0xFEDA, 0xFED9, 0xFEDA, false); // Dal
        case 0x0630: return ArabicForms(0xFEDB, 0xFEDC, 0xFEDB, 0xFEDC, false); // Thal
        case 0x0631: return ArabicForms(0xFEDD, 0xFEDE, 0xFEDD, 0xFEDE, false); // Reh
        case 0x0632: return ArabicForms(0xFEDF, 0xFEE0, 0xFEDF, 0xFEE0, false); // Zain
        case 0x0648: return ArabicForms(0xFEED, 0xFEEE, 0xFEED, 0xFEEE, false); // Waw
        case 0x0649: return ArabicForms(0xFEEF, 0xFEF0, 0xFEEF, 0xFEF0, false); // Alef Maksura
        case 0x0688: return ArabicForms(0xFB88, 0xFB89, 0xFB88, 0xFB89, false); // Urdu Ddal (ڈ)
        case 0x0691: return ArabicForms(0xFB8C, 0xFB8D, 0xFB8C, 0xFB8D, false); // Urdu Rreh (ڑ)
        case 0x0698: return ArabicForms(0xFB8A, 0xFB8B, 0xFB8A, 0xFB8B, false); // Jeh (ژ)
        case 0x06BA: return ArabicForms(0xFB9E, 0xFB9F, 0xFB9E, 0xFB9F, false); // Urdu Noon Ghunna (ں)
        case 0x06C0: return ArabicForms(0xFBA4, 0xFBA5, 0xFBA4, 0xFBA5, false); // Heh with Yeh above (ۂ)
        case 0x06C2: return ArabicForms(0xFBA4, 0xFBA5, 0xFBA4, 0xFBA5, false); // Heh Goal with Hamza (ۂ)
        case 0x06C3: return ArabicForms(0xFE93, 0xFE94, 0xFE93, 0xFE94, false); // Teh Marbuta Goal (ۃ)
        case 0x06D2: return ArabicForms(0xFBAE, 0xFBAF, 0xFBAE, 0xFBAF, false); // Urdu Bari Ye (ے)
        case 0x06D3: return ArabicForms(0xFBB0, 0xFBB1, 0xFBB0, 0xFBB1, false); // Urdu Bari Ye with Hamza (ۓ)

        // Dual-joining letters (join both right and left)
        case 0x0626: return ArabicForms(0xFE89, 0xFE8A, 0xFE8B, 0xFE8C, true); // Yeh Hamza (ئ)
        case 0x0628: return ArabicForms(0xFE8F, 0xFE90, 0xFE91, 0xFE92, true); // Beh (ب)
        case 0x067E: return ArabicForms(0xFB56, 0xFB57, 0xFB58, 0xFB59, true); // Urdu Peh (پ)
        case 0x062A: return ArabicForms(0xFE95, 0xFE96, 0xFE97, 0xFE98, true); // Teh (ت)
        case 0x0679: return ArabicForms(0xFB66, 0xFB67, 0xFB68, 0xFB69, true); // Urdu Tteh (ٹ)
        case 0x062B: return ArabicForms(0xFE99, 0xFE9A, 0xFE9B, 0xFE9C, true); // Theh (ث)
        case 0x062C: return ArabicForms(0xFE9D, 0xFE9E, 0xFE9F, 0xFEA0, true); // Jeem (ج)
        case 0x0686: return ArabicForms(0xFB7A, 0xFB7B, 0xFB7C, 0xFB7D, true); // Urdu Tcheh (چ)
        case 0x062D: return ArabicForms(0xFEA1, 0xFEA2, 0xFEA3, 0xFEA4, true); // Hah (ح)
        case 0x062E: return ArabicForms(0xFEA5, 0xFEA6, 0xFEA7, 0xFEA8, true); // Khah (خ)
        case 0x0633: return ArabicForms(0xFEB1, 0xFEB2, 0xFEB3, 0xFEB4, true); // Seen (س)
        case 0x0634: return ArabicForms(0xFEB5, 0xFEB6, 0xFEB7, 0xFEB8, true); // Sheen (ش)
        case 0x0635: return ArabicForms(0xFEB9, 0xFEBA, 0xFEBB, 0xFEBC, true); // Sad (ص)
        case 0x0636: return ArabicForms(0xFEBD, 0xFEBE, 0xFEBF, 0xFEC0, true); // Dad (ض)
        case 0x0637: return ArabicForms(0xFEC1, 0xFEC2, 0xFEC3, 0xFEC4, true); // Tah (ط)
        case 0x0638: return ArabicForms(0xFEC5, 0xFEC6, 0xFEC7, 0xFEC8, true); // Zah (ظ)
        case 0x0639: return ArabicForms(0xFEC9, 0xFECA, 0xFECB, 0xFECC, true); // Ain (ع)
        case 0x063A: return ArabicForms(0xFECD, 0xFECE, 0xFECF, 0xFED0, true); // Ghain (غ)
        case 0x0640: return ArabicForms(0x0640, 0x0640, 0x0640, 0x0640, true); // Tatweel
        case 0x0641: return ArabicForms(0xFED1, 0xFED2, 0xFED3, 0xFED4, true); // Feh (ف)
        case 0x0642: return ArabicForms(0xFED5, 0xFED6, 0xFED7, 0xFED8, true); // Qaf (ق)
        case 0x0643: return ArabicForms(0xFED9, 0xFEDA, 0xFEDB, 0xFEDC, true); // Arabic Kaf -> mapped below
        case 0x06A9: return ArabicForms(0xFB8E, 0xFB8F, 0xFB90, 0xFB91, true); // Urdu Keheh (ک)
        case 0x06AF: return ArabicForms(0xFB92, 0xFB93, 0xFB94, 0xFB95, true); // Urdu Gaf (گ)
        case 0x0644: return ArabicForms(0xFEDD, 0xFEDE, 0xFEDF, 0xFEE0, true); // Lam -> fixed below
        case 0x0645: return ArabicForms(0xFEE1, 0xFEE2, 0xFEE3, 0xFEE4, true); // Meem (م)
        case 0x0646: return ArabicForms(0xFEE5, 0xFEE6, 0xFEE7, 0xFEE8, true); // Noon (ن)
        case 0x0647: return ArabicForms(0xFEE9, 0xFEEA, 0xFEEB, 0xFEEC, true); // Heh (ه)
        case 0x06C1: return ArabicForms(0xFBA6, 0xFBA7, 0xFBA8, 0xFBA9, true); // Urdu Heh Goal (ہ)
        case 0x06BE: return ArabicForms(0xFBAA, 0xFBAB, 0xFBAC, 0xFBAD, true); // Urdu Heh Doachashmee (ھ)
        case 0x064A: return ArabicForms(0xFEF1, 0xFEF2, 0xFEF3, 0xFEF4, true); // Arabic Yeh (ي)
        case 0x06CC: return ArabicForms(0xFBFC, 0xFBFD, 0xFBFE, 0xFBFF, true); // Urdu Farsi Yeh (ی)
        default:     return ArabicForms(0, 0, 0, 0, false);
    }
}

private ArabicForms lookupArabicLetter(dchar c) pure nothrow @nogc {
    // Fix exact codepoints for Dal/Reh/Kaf/Lam in Arabic Presentation Forms-B:
    switch (c) {
        case 0x062F: return ArabicForms(0xFEA9, 0xFEAA, 0xFEA9, 0xFEAA, false); // Dal (د)
        case 0x0630: return ArabicForms(0xFEAB, 0xFEAC, 0xFEAB, 0xFEAC, false); // Thal (ذ)
        case 0x0631: return ArabicForms(0xFEAD, 0xFEAE, 0xFEAD, 0xFEAE, false); // Reh (ر)
        case 0x0632: return ArabicForms(0xFEAF, 0xFEB0, 0xFEAF, 0xFEB0, false); // Zain (ز)
        case 0x0643: return ArabicForms(0xFED9, 0xFEDA, 0xFEDB, 0xFEDC, true);  // Kaf (ك)
        case 0x0644: return ArabicForms(0xFEDD, 0xFEDE, 0xFEDF, 0xFEE0, true);  // Lam (ل)
        default:     return getArabicForms(c);
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
/// for DLangUI's left-to-right renderer. Returns pure ASCII strings unchanged.
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

    // Step 1: Contextual Joining (Initial / Medial / Final / Isolated + Lam-Alef ligature)
    dchar[] shaped;
    shaped.reserve(input.length);

    size_t n = input.length;
    for (size_t i = 0; i < n; i++) {
        dchar curr = input[i];
        auto currF = lookupArabicLetter(curr);
        if (currF.isolated == 0) {
            shaped ~= curr;
            continue;
        }

        bool prevJoins = false;
        if (i > 0) {
            auto prevF = lookupArabicLetter(input[i - 1]);
            if (prevF.isolated != 0 && prevF.joinsLeft)
                prevJoins = true;
        }

        // Check Lam + Alef ligature
        if (curr == 0x0644 && i + 1 < n) {
            dchar next = input[i + 1];
            dchar ligIso = 0, ligFin = 0;
            if (next == 0x0622)      { ligIso = 0xFEF5; ligFin = 0xFEF6; }
            else if (next == 0x0623) { ligIso = 0xFEF7; ligFin = 0xFEF8; }
            else if (next == 0x0625) { ligIso = 0xFEF9; ligFin = 0xFEFA; }
            else if (next == 0x0627) { ligIso = 0xFEFB; ligFin = 0xFEFC; }
            if (ligIso != 0) {
                shaped ~= prevJoins ? ligFin : ligIso;
                i++; // consumed Alef
                continue;
            }
        }

        bool nextJoins = false;
        if (currF.joinsLeft && i + 1 < n) {
            auto nextF = lookupArabicLetter(input[i + 1]);
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

    // Step 2: Visual BiDi reordering for RTL runs (preserving LTR runs like Latin/digits inside RTL)
    // Identify contiguous blocks starting at the first Arabic char and ending at the last Arabic char
    // or reverse each RTL phrase while keeping embedded LTR words/numbers in left-to-right order.
    static bool isLtrChar(dchar c) pure nothrow @nogc {
        return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9');
    }

    // Split into runs: if the string is predominantly RTL or contains RTL phrases,
    // reverse the RTL phrase tokens and reverse characters within RTL tokens.
    dchar[] result;
    result.reserve(shaped.length);

    size_t idx = 0;
    while (idx < shaped.length) {
        if (!isArabicChar(shaped[idx])) {
            // Check if this is a bracket immediately preceding an Arabic run
            if ((shaped[idx] == '(' || shaped[idx] == '[') && idx + 1 < shaped.length && isArabicChar(shaped[idx + 1])) {
                // Include in the RTL segment below
            } else {
                result ~= shaped[idx];
                idx++;
                continue;
            }
        }

        // Collect an entire RTL phrase (Arabic letters, spaces, punctuation, brackets, and embedded numbers)
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
        // Include trailing closing bracket if matched
        while (end < i && (shaped[end] == ')' || shaped[end] == ']'))
            end++;

        dchar[] rtlSlice = shaped[start .. end];
        // Reverse the RTL slice for visual left-to-right drawing, mirroring brackets,
        // then un-reverse any contiguous ASCII digit runs inside it.
        dchar[] visualRtl;
        visualRtl.length = rtlSlice.length;
        foreach (k, ch; rtlSlice) {
            visualRtl[rtlSlice.length - 1 - k] = mirrorBracket(ch);
        }
        // Restore LTR order of multi-digit numbers inside the reversed RTL slice
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

/// Clean, modern flat button that draws its own solid fill, border, hover state,
/// and label without DLangUI's legacy 9-patch theme overrides.
class FlatButton : Widget {
    dstring caption;
    uint bgNormal;
    uint bgHover;
    uint bgPressed;
    uint fgColor;
    uint borderColor;
    bool leftAligned = false;

    this(dstring text, uint bg = 0x2563EB, uint fg = 0xFFFFFF, uint hoverBg = 0x1D4ED8, uint border = COLOR_TRANSPARENT) {
        super(null);
        this.caption = text;
        this.bgNormal = bg;
        this.bgHover = hoverBg;
        this.bgPressed = hoverBg;
        this.fgColor = fg;
        this.borderColor = border;
        clickable = true;
        focusable = true;
        trackHover = true;
        fontSize = pointsToPixels(10);
        fontWeight = 600;
        padding = Rect(14, 8, 14, 8);
    }

    void setColors(uint bg, uint fg, uint hoverBg, uint border = COLOR_TRANSPARENT) {
        this.bgNormal = bg;
        this.fgColor = fg;
        this.bgHover = hoverBg;
        this.bgPressed = hoverBg;
        this.borderColor = border;
        invalidate();
    }

    override void measure(int parentWidth, int parentHeight) {
        FontRef fnt = font;
        Point sz = fnt.textSize(caption);
        measuredContent(parentWidth, parentHeight, sz.x, sz.y);
    }

    override void onDraw(DrawBuf buf) {
        if (visibility != Visibility.Visible)
            return;
        Rect rc = _pos;
        applyMargins(rc);
        auto saver = ClipRectSaver(buf, rc, 0);

        uint bg = bgNormal;
        if (state & State.Pressed)
            bg = bgPressed;
        else if (state & State.Hovered)
            bg = bgHover;

        if (bg != COLOR_TRANSPARENT)
            buf.fillRect(rc, bg);

        if (borderColor != COLOR_TRANSPARENT)
            buf.drawFrame(rc, borderColor, Rect(1, 1, 1, 1));

        applyPadding(rc);
        FontRef fnt = font;
        Point sz = fnt.textSize(caption);
        Align ha = leftAligned ? Align.Left : Align.HCenter;
        applyAlign(rc, sz, ha, Align.VCenter);
        fnt.drawText(buf, rc.left, rc.top, caption, fgColor);
    }
}

/// 1px solid divider line (horizontal or vertical).
Widget makeDivider(bool vertical, uint color = 0xE4E4E7) {
    auto w = new Widget();
    w.backgroundColor = color;
    if (vertical) {
        w.layoutWidth = 1;
        w.layoutHeight = FILL_PARENT;
        w.minWidth = 1;
        w.maxWidth = 1;
    } else {
        w.layoutWidth = FILL_PARENT;
        w.layoutHeight = 1;
        w.minHeight = 1;
        w.maxHeight = 1;
    }
    return w;
}

/// Custom Linear / Apple Notes style table widget with opaque colors,
/// clear column headers, row dividers, and full-row selection.
class LinearGridWidget : StringGridWidget {
    this(string ID = null) {
        super(ID);
        styleId = null;
        fontFace = "Segoe UI,Tahoma,Arial";
        showRowHeaders = false;
        showColHeaders = true;
        rowSelect = true;
        defRowHeight = pointsToPixels(24);
        backgroundColor = 0xFFFFFF;
        padding = Rect(0, 0, 0, 0);
        margins = Rect(0, 0, 0, 0);
    }

    override void onThemeChanged() {
        super.onThemeChanged();
        _selectionColor = 0xDBEAFE;
        _selectionColorRowSelect = 0xDBEAFE;
        _fixedCellBackgroundColor = 0xF8FAFC;
        _cellBorderColor = 0xE4E4E7;
        _cellHeaderBorderColor = 0xD4D4D8;
        _cellHeaderBackgroundColor = 0xF4F4F5;
        _cellHeaderSelectedBackgroundColor = 0xE4E4E7;
    }

    protected override Point measureCell(int x, int y) {
        Point sz = super.measureCell(x, y);
        sz.x += 18;
        int minH = pointsToPixels(22);
        if (sz.y < minH)
            sz.y = minH;
        return sz;
    }

    protected override void drawHeaderCellBackground(DrawBuf buf, Rect rc, int c, int r) {
        buf.fillRect(rc, 0xF4F4F5);
        buf.drawLine(Point(rc.right - 1, rc.top), Point(rc.right - 1, rc.bottom), 0xE4E4E7);
        buf.drawLine(Point(rc.left, rc.bottom - 1), Point(rc.right, rc.bottom - 1), 0xD4D4D8);
    }

    protected override void drawHeaderCell(DrawBuf buf, Rect rc, int col, int row) {
        if (row < 0 && col >= 0) {
            dstring txt = colTitle(col);
            if (!txt.length) return;
            rc.shrink(10, 2);
            FontRef fnt = font;
            Point sz = fnt.textSize(txt);
            applyAlign(rc, sz, Align.Left, Align.VCenter);
            fnt.drawText(buf, rc.left, rc.top, txt, 0x3F3F46);
        }
    }

    protected override void drawCellBackground(DrawBuf buf, Rect rc, int c, int r) {
        bool selectedRow = (r == row);
        uint bg = (r % 2 == 1) ? 0xFAFAFA : 0xFFFFFF;
        if (selectedRow)
            bg = 0xDBEAFE;
        buf.fillRect(rc, bg);
        buf.drawLine(Point(rc.right - 1, rc.top), Point(rc.right - 1, rc.bottom), 0xF1F5F9);
        buf.drawLine(Point(rc.left, rc.bottom - 1), Point(rc.right, rc.bottom - 1), 0xE4E4E7);
        if (selectedRow && c == 0) {
            Rect accent = Rect(rc.left, rc.top, rc.left + 4, rc.bottom);
            buf.fillRect(accent, 0x2563EB);
        }
    }

    protected override void drawCell(DrawBuf buf, Rect rc, int col, int row) {
        dstring rawTxt = cellText(col, row);
        if (!rawTxt.length) {
            rawTxt = "—"d;
        }
        dstring txt = shapeForDisplay(rawTxt);
        rc.shrink(10, 2);
        FontRef fnt = font;
        Point sz = fnt.textSize(txt);

        uint fg = 0x18181B;
        if (rawTxt == "—"d) {
            fg = 0xA1A1AA;
        } else if (rawTxt == "Overdue"d || rawTxt == "0 left"d || rawTxt == "Core"d || rawTxt == "Issued"d) {
            fg = 0xDC2626;
        } else if (rawTxt == "Active"d || rawTxt == "Teacher"d || rawTxt == "Yes"d) {
            fg = 0x2563EB;
        } else if (rawTxt == "Returned"d || rawTxt == "Student"d || rawTxt == "Available"d) {
            fg = 0x059669;
        }

        applyAlign(rc, sz, Align.Left, Align.VCenter);
        fnt.drawText(buf, rc.left, rc.top, txt, fg);
    }
}

/// Main single-window application workspace.
class LibraryAppView : HorizontalLayout {
    LibraryStore store;

    // Sidebar navigation buttons & stats
    FlatButton navCirculationBtn;
    FlatButton navBooksBtn;
    FlatButton navMembersBtn;
    FlatButton navSchemaBtn;
    TextWidget statBooksText;
    TextWidget statMembersText;
    TextWidget statIssuesText;
    TextWidget statusBanner;

    // Content stack
    FrameLayout workspaceStack;
    Widget circulationView;
    Widget booksView;
    Widget membersView;
    Widget schemaView;

    // --- 1. Circulation (Issue / Return) widgets ---
    EditLine issueCnicInput;
    VerticalLayout issueMemberStatusCard;
    TextWidget issueMemberBadge;
    VerticalLayout onTheFlyMemberBox;
    EditLine[string] onTheFlyMemberEditors;
    ComboBox onTheFlyRoleCombo;

    EditLine issueBookFilterInput;
    ComboBox issueBookCombo;
    string[] issueBookIds;
    EditLine issueDueDateInput;
    VerticalLayout issueExtraBox;
    EditLine[string] issueExtraEditors;

    EditLine issueSearchInput;
    string issueFilterMode = "active";
    FlatButton issueFilterActiveBtn;
    FlatButton issueFilterOverdueBtn;
    FlatButton issueFilterAllBtn;
    LinearGridWidget issuesGrid;
    string[] displayedIssueIds;

    // --- 2. Books workspace widgets ---
    EditLine bookSearchInput;
    CheckBox bookAvailOnlyCheck;
    LinearGridWidget booksGrid;
    string[] displayedBookIds;
    string selectedBookId;
    VerticalLayout bookFormContainer;
    EditLine[string] bookFormEditors;
    TextWidget bookInspectorHeader;

    // --- 3. Members workspace widgets ---
    EditLine memberSearchInput;
    string memberRoleFilter = "All";
    FlatButton memberFilterAllBtn;
    FlatButton memberFilterStudentBtn;
    FlatButton memberFilterTeacherBtn;
    LinearGridWidget membersGrid;
    string[] displayedMemberCnics;
    string selectedMemberCnic;
    VerticalLayout memberFormContainer;
    EditLine[string] memberFormEditors;
    ComboBox memberFormRoleCombo;
    TextWidget memberInspectorHeader;

    // --- 4. Schema workspace widgets ---
    EntityType currentSchemaEntity = EntityType.book;
    FlatButton schemaEntityBookBtn;
    FlatButton schemaEntityMemberBtn;
    FlatButton schemaEntityIssueBtn;
    LinearGridWidget schemaGrid;
    string selectedSchemaKey;
    EditLine schemaKeyInput;
    EditLine schemaLabelInput;
    ComboBox schemaTypeCombo;
    CheckBox schemaReqCheck;
    TextWidget schemaCoreBadge;

    this(LibraryStore store) {
        super("ROOT");
        this.store = store;
        fontFace = "Segoe UI,Tahoma,Arial";
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;
        backgroundColor = 0xFFFFFF;

        // Left navigation sidebar
        addChild(buildSidebar());
        addChild(makeDivider(true, 0x27272A));

        // Right main column
        auto rightCol = new VerticalLayout();
        rightCol.layoutWidth = FILL_PARENT;
        rightCol.layoutHeight = FILL_PARENT;
        rightCol.backgroundColor = 0xFFFFFF;

        workspaceStack = new FrameLayout("STACK");
        workspaceStack.layoutWidth = FILL_PARENT;
        workspaceStack.layoutHeight = FILL_PARENT;
        workspaceStack.backgroundColor = 0xFFFFFF;

        circulationView = buildCirculationView();
        booksView       = buildBooksView();
        membersView     = buildMembersView();
        schemaView      = buildSchemaView();

        workspaceStack.addChild(circulationView);
        workspaceStack.addChild(booksView);
        workspaceStack.addChild(membersView);
        workspaceStack.addChild(schemaView);

        rightCol.addChild(workspaceStack);
        rightCol.addChild(makeDivider(false, 0xE4E4E7));

        // Bottom status bar
        auto statusBar = new HorizontalLayout();
        statusBar.layoutWidth = FILL_PARENT;
        statusBar.layoutHeight = WRAP_CONTENT;
        statusBar.padding = Rect(16, 7, 16, 7);
        statusBar.backgroundColor = 0xF4F4F5;
        statusBanner = new TextWidget(null, "Ready"d);
        statusBanner.textColor = 0x3F3F46;
        statusBanner.fontSize = pointsToPixels(9);
        statusBar.addChild(statusBanner);
        rightCol.addChild(statusBar);

        addChild(rightCol);

        rebuildDynamicForms();
        refreshAll();
        onIssueCnicChanged();
        switchTab("circulation");
    }

    void setStatus(string msg, bool isError = false) {
        if (!statusBanner) return;
        statusBanner.text = toUTF32(msg);
        statusBanner.textColor = isError ? 0xDC2626 : 0x18181B;
    }

    // =========================================================================
    // Left Sidebar (Apple Notes / Linear Dark Slate)
    // =========================================================================
    private Widget buildSidebar() {
        auto sb = new VerticalLayout("SIDEBAR");
        sb.layoutWidth = 210;
        sb.minWidth = 210;
        sb.maxWidth = 210;
        sb.layoutHeight = FILL_PARENT;
        sb.padding = Rect(14, 20, 14, 18);
        sb.backgroundColor = 0x18181B;

        auto title = new TextWidget(null, "College Library"d);
        title.fontSize = pointsToPixels(13);
        title.fontWeight = 700;
        title.textColor = 0xFAFAFA;
        title.margins = Rect(8, 0, 8, 16);
        sb.addChild(title);

        FlatButton makeNavBtn(dstring label, string tabId) {
            auto b = new FlatButton(label, 0x18181B, 0xA1A1AA, 0x27272A);
            b.leftAligned = true;
            b.layoutWidth = FILL_PARENT;
            b.padding = Rect(12, 9, 12, 9);
            b.margins = Rect(0, 2, 0, 2);
            b.fontSize = pointsToPixels(10);
            b.click = delegate(Widget w) {
                switchTab(tabId);
                return true;
            };
            return b;
        }

        navCirculationBtn = makeNavBtn("Issue & Return"d, "circulation");
        navBooksBtn       = makeNavBtn("Books"d, "books");
        navMembersBtn     = makeNavBtn("Members"d, "members");
        navSchemaBtn      = makeNavBtn("Schema"d, "schema");

        sb.addChild(navCirculationBtn);
        sb.addChild(navBooksBtn);
        sb.addChild(navMembersBtn);
        sb.addChild(navSchemaBtn);

        auto spacer = new Widget();
        spacer.layoutWidth = FILL_PARENT;
        spacer.layoutHeight = FILL_PARENT;
        sb.addChild(spacer);

        // Live counts at bottom of sidebar
        auto statsCard = new VerticalLayout();
        statsCard.layoutWidth = FILL_PARENT;
        statsCard.padding = Rect(10, 10, 10, 10);
        statsCard.backgroundColor = 0x27272A;

        statBooksText = new TextWidget(null, ""d);
        statBooksText.fontSize = pointsToPixels(9);
        statBooksText.textColor = 0xD4D4D8;
        statsCard.addChild(statBooksText);

        statMembersText = new TextWidget(null, ""d);
        statMembersText.fontSize = pointsToPixels(9);
        statMembersText.textColor = 0xD4D4D8;
        statsCard.addChild(statMembersText);

        statIssuesText = new TextWidget(null, ""d);
        statIssuesText.fontSize = pointsToPixels(9);
        statIssuesText.textColor = 0x60A5FA;
        statIssuesText.fontWeight = 600;
        statsCard.addChild(statIssuesText);

        sb.addChild(statsCard);
        return sb;
    }

    void switchTab(string tabId) {
        circulationView.visibility = (tabId == "circulation") ? Visibility.Visible : Visibility.Gone;
        booksView.visibility       = (tabId == "books")       ? Visibility.Visible : Visibility.Gone;
        membersView.visibility     = (tabId == "members")     ? Visibility.Visible : Visibility.Gone;
        schemaView.visibility      = (tabId == "schema")      ? Visibility.Visible : Visibility.Gone;

        void styleNav(FlatButton b, bool active) {
            if (active)
                b.setColors(0x2563EB, 0xFFFFFF, 0x1D4ED8);
            else
                b.setColors(0x18181B, 0xA1A1AA, 0x27272A);
        }

        styleNav(navCirculationBtn, tabId == "circulation");
        styleNav(navBooksBtn,       tabId == "books");
        styleNav(navMembersBtn,     tabId == "members");
        styleNav(navSchemaBtn,      tabId == "schema");

        workspaceStack.requestLayout();
        workspaceStack.invalidate();
    }

    // =========================================================================
    // 1. Circulation (Issue / Return) Workspace
    // =========================================================================
    private Widget buildCirculationView() {
        auto root = new HorizontalLayout("CIRC_VIEW");
        root.layoutWidth = FILL_PARENT;
        root.layoutHeight = FILL_PARENT;
        root.backgroundColor = 0xFFFFFF;

        // Left: Issue Book Desk (Fixed 350px)
        auto leftCol = new VerticalLayout();
        leftCol.layoutWidth = 350;
        leftCol.minWidth = 350;
        leftCol.maxWidth = 350;
        leftCol.layoutHeight = FILL_PARENT;
        leftCol.backgroundColor = 0xFAFAFA;

        // Left header
        auto leftTop = new HorizontalLayout();
        leftTop.layoutWidth = FILL_PARENT;
        leftTop.padding = Rect(18, 14, 18, 14);
        leftTop.backgroundColor = 0xFFFFFF;
        auto deskHeader = new TextWidget(null, "Issue Book"d);
        deskHeader.fontSize = pointsToPixels(13);
        deskHeader.fontWeight = 700;
        deskHeader.textColor = 0x18181B;
        leftTop.addChild(deskHeader);
        leftCol.addChild(leftTop);
        leftCol.addChild(makeDivider(false, 0xE4E4E7));

        auto leftScroll = new ScrollWidget();
        leftScroll.layoutWidth = FILL_PARENT;
        leftScroll.layoutHeight = FILL_PARENT;
        leftScroll.backgroundColor = 0xFAFAFA;

        auto desk = new VerticalLayout();
        desk.layoutWidth = 325;
        desk.layoutHeight = WRAP_CONTENT;
        desk.padding = Rect(18, 14, 18, 18);
        desk.backgroundColor = 0xFAFAFA;

        // Step 1: Member CNIC
        desk.addChild(makeFieldLabel("1. Member CNIC (no dashes)"d));
        issueCnicInput = makeEditLine(""d);
        issueCnicInput.contentChange = delegate(EditableContent content) {
            onIssueCnicChanged();
        };
        desk.addChild(issueCnicInput);

        issueMemberStatusCard = new VerticalLayout();
        issueMemberStatusCard.layoutWidth = FILL_PARENT;
        issueMemberStatusCard.padding = Rect(10, 8, 10, 8);
        issueMemberStatusCard.margins = Rect(0, 2, 0, 10);
        issueMemberStatusCard.backgroundColor = 0xECFDF5;
        issueMemberBadge = new TextWidget(null, ""d);
        issueMemberBadge.fontSize = pointsToPixels(9);
        issueMemberBadge.fontWeight = 600;
        issueMemberBadge.textColor = 0x065F46;
        issueMemberStatusCard.addChild(issueMemberBadge);
        desk.addChild(issueMemberStatusCard);

        // On-the-fly member creation box (auto-shown when CNIC is not found)
        onTheFlyMemberBox = new VerticalLayout();
        onTheFlyMemberBox.layoutWidth = FILL_PARENT;
        onTheFlyMemberBox.layoutHeight = WRAP_CONTENT;
        onTheFlyMemberBox.padding = Rect(12, 10, 12, 10);
        onTheFlyMemberBox.margins = Rect(0, 0, 0, 12);
        onTheFlyMemberBox.backgroundColor = 0xEFF6FF;
        onTheFlyMemberBox.visibility = Visibility.Gone;
        desk.addChild(onTheFlyMemberBox);

        // Step 2: Book selection
        desk.addChild(makeFieldLabel("2. Filter Books (Title / ID / Accession No)"d));
        issueBookFilterInput = makeEditLine(""d);
        issueBookFilterInput.contentChange = delegate(EditableContent content) {
            refreshIssueBookCombo();
        };
        desk.addChild(issueBookFilterInput);

        desk.addChild(makeFieldLabel("Select Book"d));
        issueBookCombo = new ComboBox(null, cast(dstring[]) []);
        issueBookCombo.layoutWidth = FILL_PARENT;
        issueBookCombo.margins = Rect(0, 2, 0, 10);
        desk.addChild(issueBookCombo);

        // Step 3: Due Date
        auto dueHeaderRow = new HorizontalLayout();
        dueHeaderRow.layoutWidth = FILL_PARENT;
        dueHeaderRow.alignment = Align.VCenter;
        dueHeaderRow.addChild(makeFieldLabel("3. Due Date (YYYY-MM-DD)"d));
        auto dueSpacer = new Widget();
        dueSpacer.layoutWidth = FILL_PARENT;
        dueHeaderRow.addChild(dueSpacer);
        auto quick7 = makeSmallBtn("+7d"d);
        quick7.click = delegate(Widget w) { issueDueDateInput.text = toUTF32(datePlusDaysIso(7)); return true; };
        auto quick14 = makeSmallBtn("+14d"d);
        quick14.click = delegate(Widget w) { issueDueDateInput.text = toUTF32(datePlusDaysIso(14)); return true; };
        auto quick30 = makeSmallBtn("+30d"d);
        quick30.click = delegate(Widget w) { issueDueDateInput.text = toUTF32(datePlusDaysIso(30)); return true; };
        dueHeaderRow.addChild(quick7);
        dueHeaderRow.addChild(quick14);
        dueHeaderRow.addChild(quick30);
        desk.addChild(dueHeaderRow);

        issueDueDateInput = makeEditLine(toUTF32(datePlusDaysIso(14)));
        desk.addChild(issueDueDateInput);

        // Dynamic issue schema fields
        issueExtraBox = new VerticalLayout();
        issueExtraBox.layoutWidth = FILL_PARENT;
        issueExtraBox.layoutHeight = WRAP_CONTENT;
        desk.addChild(issueExtraBox);

        auto issueBtn = makePrimaryButton("Issue Book"d);
        issueBtn.layoutWidth = FILL_PARENT;
        issueBtn.margins = Rect(0, 14, 0, 0);
        issueBtn.click = delegate(Widget w) {
            handleIssueSubmit();
            return true;
        };
        desk.addChild(issueBtn);

        leftScroll.contentWidget = desk;
        leftCol.addChild(leftScroll);
        root.addChild(leftCol);
        root.addChild(makeDivider(true, 0xE4E4E7));

        // Right: Active & Past Issued Books Table
        auto rightPane = new VerticalLayout();
        rightPane.layoutWidth = FILL_PARENT;
        rightPane.layoutHeight = FILL_PARENT;
        rightPane.backgroundColor = 0xFFFFFF;

        // Top toolbar
        auto topBar = new HorizontalLayout();
        topBar.layoutWidth = FILL_PARENT;
        topBar.layoutHeight = WRAP_CONTENT;
        topBar.padding = Rect(16, 12, 16, 12);
        topBar.alignment = Align.VCenter;
        topBar.backgroundColor = 0xFFFFFF;

        auto issuesTitle = new TextWidget(null, "Issued Books"d);
        issuesTitle.fontSize = pointsToPixels(13);
        issuesTitle.fontWeight = 700;
        issuesTitle.textColor = 0x18181B;
        issuesTitle.margins = Rect(0, 0, 16, 0);
        topBar.addChild(issuesTitle);

        topBar.addChild(makeInlineLabel("Search:"d));
        issueSearchInput = makeEditLine(""d);
        issueSearchInput.layoutWidth = FILL_PARENT;
        issueSearchInput.margins = Rect(0, 0, 12, 0);
        issueSearchInput.contentChange = delegate(EditableContent c) {
            refreshIssuesGrid();
        };
        topBar.addChild(issueSearchInput);

        issueFilterActiveBtn = makeFilterPill("Active"d, true);
        issueFilterActiveBtn.click = delegate(Widget w) {
            issueFilterMode = "active";
            refreshIssuesGrid();
            return true;
        };
        issueFilterOverdueBtn = makeFilterPill("Overdue"d, false);
        issueFilterOverdueBtn.click = delegate(Widget w) {
            issueFilterMode = "overdue";
            refreshIssuesGrid();
            return true;
        };
        issueFilterAllBtn = makeFilterPill("All"d, false);
        issueFilterAllBtn.click = delegate(Widget w) {
            issueFilterMode = "all";
            refreshIssuesGrid();
            return true;
        };

        topBar.addChild(issueFilterActiveBtn);
        topBar.addChild(issueFilterOverdueBtn);
        topBar.addChild(issueFilterAllBtn);

        auto returnBtn = makeSuccessButton("Return Selected Book"d);
        returnBtn.margins = Rect(10, 0, 0, 0);
        returnBtn.click = delegate(Widget w) {
            handleReturnSelectedIssue();
            return true;
        };
        topBar.addChild(returnBtn);

        rightPane.addChild(topBar);
        rightPane.addChild(makeDivider(false, 0xE4E4E7));

        issuesGrid = new LinearGridWidget("ISSUES_GRID");
        issuesGrid.layoutWidth = FILL_PARENT;
        issuesGrid.layoutHeight = FILL_PARENT;
        issuesGrid.cellActivated = delegate(GridWidgetBase src, int col, int row) {
            handleReturnSelectedIssue();
        };
        rightPane.addChild(issuesGrid);

        root.addChild(rightPane);
        return root;
    }

    private void onIssueCnicChanged() {
        string raw = toUTF8(issueCnicInput.text);
        string norm = normalizeCnic(raw);

        if (norm.length == 0) {
            issueMemberStatusCard.backgroundColor = 0xF4F4F5;
            issueMemberBadge.text = "Type a member CNIC above"d;
            issueMemberBadge.textColor = 0x52525B;
            onTheFlyMemberBox.visibility = Visibility.Gone;
            requestLayout();
            invalidate();
            return;
        }

        auto m = store.findMemberByCnic(norm);
        if (m !is null) {
            int activeCount = store.activeIssueCountForMember(norm);
            string summary = "Matched: " ~ m.get("name") ~ " · " ~ m.get("role") ~
                " (" ~ to!string(activeCount) ~ " active)";
            issueMemberStatusCard.backgroundColor = 0xDCFCE7;
            issueMemberBadge.text = toUTF32(summary);
            issueMemberBadge.textColor = 0x166534;
            onTheFlyMemberBox.visibility = Visibility.Gone;
        } else {
            issueMemberStatusCard.backgroundColor = 0xDBEAFE;
            issueMemberBadge.text = toUTF32("New CNIC (" ~ norm ~ ") — Fill member details below");
            issueMemberBadge.textColor = 0x1E40AF;
            onTheFlyMemberBox.visibility = Visibility.Visible;
        }
        requestLayout();
        invalidate();
    }

    private void handleIssueSubmit() {
        if (issueBookIds.length == 0 || issueBookCombo.selectedItemIndex < 0 ||
            issueBookCombo.selectedItemIndex >= cast(int) issueBookIds.length) {
            setStatus("Select an available book to issue.", true);
            return;
        }
        string bookId = issueBookIds[issueBookCombo.selectedItemIndex];
        string cnic = normalizeCnic(toUTF8(issueCnicInput.text));

        Record newMember;
        newMember.set("cnic", cnic);
        newMember.set("role", (onTheFlyRoleCombo && onTheFlyRoleCombo.selectedItemIndex == 1) ? "Teacher" : "Student");
        foreach (k, ed; onTheFlyMemberEditors) {
            newMember.set(k, toUTF8(ed.text));
        }

        Record extraIssue;
        foreach (k, ed; issueExtraEditors) {
            extraIssue.set(k, toUTF8(ed.text));
        }

        string issueId;
        string err;
        if (!store.issueBook(bookId, cnic, newMember, toUTF8(issueDueDateInput.text), extraIssue, issueId, err)) {
            setStatus(err, true);
            return;
        }

        foreach (k, ed; onTheFlyMemberEditors)
            ed.text = ""d;
        foreach (k, ed; issueExtraEditors)
            ed.text = ""d;

        refreshAll();
        onIssueCnicChanged();
        setStatus("Issued book " ~ bookId ~ " to CNIC " ~ cnic ~ " (" ~ issueId ~ ").");
    }

    private void handleReturnSelectedIssue() {
        int r = issuesGrid.row;
        if (r < 0 || r >= cast(int) displayedIssueIds.length) {
            setStatus("Select an issued book row in the table to return.", true);
            return;
        }
        string issueId = displayedIssueIds[r];
        string err;
        if (!store.returnIssue(issueId, err)) {
            setStatus(err, true);
            return;
        }
        refreshAll();
        setStatus("Returned issued book " ~ issueId ~ ".");
    }

    // =========================================================================
    // 2. Books Workspace View
    // =========================================================================
    private Widget buildBooksView() {
        auto root = new HorizontalLayout("BOOKS_VIEW");
        root.layoutWidth = FILL_PARENT;
        root.layoutHeight = FILL_PARENT;
        root.backgroundColor = 0xFFFFFF;

        // Left: Books Catalog Table
        auto tablePane = new VerticalLayout();
        tablePane.layoutWidth = FILL_PARENT;
        tablePane.layoutHeight = FILL_PARENT;
        tablePane.backgroundColor = 0xFFFFFF;

        auto topBar = new HorizontalLayout();
        topBar.layoutWidth = FILL_PARENT;
        topBar.layoutHeight = WRAP_CONTENT;
        topBar.padding = Rect(16, 12, 16, 12);
        topBar.alignment = Align.VCenter;
        topBar.backgroundColor = 0xFFFFFF;

        auto title = new TextWidget(null, "Books"d);
        title.fontSize = pointsToPixels(13);
        title.fontWeight = 700;
        title.textColor = 0x18181B;
        title.margins = Rect(0, 0, 16, 0);
        topBar.addChild(title);

        topBar.addChild(makeInlineLabel("Search:"d));
        bookSearchInput = makeEditLine(""d);
        bookSearchInput.layoutWidth = FILL_PARENT;
        bookSearchInput.margins = Rect(0, 0, 12, 0);
        bookSearchInput.contentChange = delegate(EditableContent c) {
            refreshBooksGrid();
        };
        topBar.addChild(bookSearchInput);

        bookAvailOnlyCheck = new CheckBox(null, "Available only"d);
        bookAvailOnlyCheck.margins = Rect(0, 0, 12, 0);
        bookAvailOnlyCheck.checkChange = delegate(Widget src, bool checked) {
            refreshBooksGrid();
            return true;
        };
        topBar.addChild(bookAvailOnlyCheck);

        auto issueBookBtn = makeFilterPill("Issue Selected"d, false);
        issueBookBtn.margins = Rect(0, 0, 8, 0);
        issueBookBtn.click = delegate(Widget w) {
            if (selectedBookId.length == 0) {
                setStatus("Select a book row in the table first.", true);
                return true;
            }
            issueBookFilterInput.text = toUTF32(selectedBookId);
            refreshIssueBookCombo();
            switchTab("circulation");
            return true;
        };
        topBar.addChild(issueBookBtn);

        auto newBookBtn = makePrimaryButton("+ New Book"d);
        newBookBtn.click = delegate(Widget w) {
            clearBookForm();
            return true;
        };
        topBar.addChild(newBookBtn);

        tablePane.addChild(topBar);
        tablePane.addChild(makeDivider(false, 0xE4E4E7));

        booksGrid = new LinearGridWidget("BOOKS_GRID");
        booksGrid.layoutWidth = FILL_PARENT;
        booksGrid.layoutHeight = FILL_PARENT;
        booksGrid.cellSelected = delegate(GridWidgetBase src, int col, int row) {
            if (row >= 0 && row < cast(int) displayedBookIds.length) {
                loadBookIntoForm(displayedBookIds[row]);
            }
        };
        tablePane.addChild(booksGrid);
        root.addChild(tablePane);
        root.addChild(makeDivider(true, 0xE4E4E7));

        // Right: Book Inspector Drawer (340px)
        auto rightCol = new VerticalLayout();
        rightCol.layoutWidth = 340;
        rightCol.minWidth = 340;
        rightCol.maxWidth = 340;
        rightCol.layoutHeight = FILL_PARENT;
        rightCol.backgroundColor = 0xFAFAFA;

        auto inspectorTop = new HorizontalLayout();
        inspectorTop.layoutWidth = FILL_PARENT;
        inspectorTop.padding = Rect(18, 14, 18, 14);
        inspectorTop.backgroundColor = 0xFFFFFF;
        bookInspectorHeader = new TextWidget(null, "New Book"d);
        bookInspectorHeader.fontSize = pointsToPixels(13);
        bookInspectorHeader.fontWeight = 700;
        bookInspectorHeader.textColor = 0x18181B;
        inspectorTop.addChild(bookInspectorHeader);
        rightCol.addChild(inspectorTop);
        rightCol.addChild(makeDivider(false, 0xE4E4E7));

        auto inspectorScroll = new ScrollWidget();
        inspectorScroll.layoutWidth = FILL_PARENT;
        inspectorScroll.layoutHeight = FILL_PARENT;
        inspectorScroll.backgroundColor = 0xFAFAFA;

        auto inspector = new VerticalLayout();
        inspector.layoutWidth = 315;
        inspector.layoutHeight = WRAP_CONTENT;
        inspector.padding = Rect(18, 14, 18, 18);
        inspector.backgroundColor = 0xFAFAFA;

        bookFormContainer = new VerticalLayout();
        bookFormContainer.layoutWidth = FILL_PARENT;
        bookFormContainer.layoutHeight = WRAP_CONTENT;
        inspector.addChild(bookFormContainer);

        auto btnRow = new HorizontalLayout();
        btnRow.layoutWidth = FILL_PARENT;
        btnRow.margins = Rect(0, 14, 0, 0);

        auto saveBtn = makePrimaryButton("Save Book"d);
        saveBtn.layoutWidth = FILL_PARENT;
        saveBtn.margins = Rect(0, 0, 8, 0);
        saveBtn.click = delegate(Widget w) {
            saveBookFromForm();
            return true;
        };
        btnRow.addChild(saveBtn);

        auto delBtn = makeDangerButton("Delete"d);
        delBtn.click = delegate(Widget w) {
            if (selectedBookId.length == 0) return true;
            string err;
            if (!store.deleteBook(selectedBookId, err)) {
                setStatus(err, true);
                return true;
            }
            string deleted = selectedBookId;
            clearBookForm();
            refreshAll();
            setStatus("Deleted book " ~ deleted ~ ".");
            return true;
        };
        btnRow.addChild(delBtn);

        inspector.addChild(btnRow);
        inspectorScroll.contentWidget = inspector;
        rightCol.addChild(inspectorScroll);
        root.addChild(rightCol);

        return root;
    }

    private void clearBookForm() {
        selectedBookId = "";
        bookInspectorHeader.text = "New Book"d;
        foreach (k, ed; bookFormEditors) {
            if (k == "copies")
                ed.text = "1"d;
            else if (k == "status")
                ed.text = "Available"d;
            else if (k == "dateAdded")
                ed.text = toUTF32(todayIso());
            else
                ed.text = ""d;
        }
    }

    private void loadBookIntoForm(string bookId) {
        auto b = store.findBook(bookId);
        if (!b) return;
        selectedBookId = bookId;
        bookInspectorHeader.text = toUTF32("Edit Book (" ~ bookId ~ ")");
        foreach (k, ed; bookFormEditors) {
            ed.text = toUTF32(b.get(k));
        }
    }

    private void saveBookFromForm() {
        Record rec;
        if (selectedBookId.length > 0)
            rec.set("id", selectedBookId);
        foreach (k, ed; bookFormEditors) {
            if (k == "id" && selectedBookId.length == 0) continue;
            rec.set(k, toUTF8(ed.text));
        }
        string savedId, err;
        if (!store.upsertBook(rec, savedId, err)) {
            setStatus(err, true);
            return;
        }
        selectedBookId = savedId;
        refreshAll();
        loadBookIntoForm(savedId);
        setStatus("Saved book " ~ savedId ~ ".");
    }

    // =========================================================================
    // 3. Members Workspace View
    // =========================================================================
    private Widget buildMembersView() {
        auto root = new HorizontalLayout("MEMBERS_VIEW");
        root.layoutWidth = FILL_PARENT;
        root.layoutHeight = FILL_PARENT;
        root.backgroundColor = 0xFFFFFF;

        auto tablePane = new VerticalLayout();
        tablePane.layoutWidth = FILL_PARENT;
        tablePane.layoutHeight = FILL_PARENT;
        tablePane.backgroundColor = 0xFFFFFF;

        auto topBar = new HorizontalLayout();
        topBar.layoutWidth = FILL_PARENT;
        topBar.layoutHeight = WRAP_CONTENT;
        topBar.padding = Rect(16, 12, 16, 12);
        topBar.alignment = Align.VCenter;
        topBar.backgroundColor = 0xFFFFFF;

        auto title = new TextWidget(null, "Members"d);
        title.fontSize = pointsToPixels(13);
        title.fontWeight = 700;
        title.textColor = 0x18181B;
        title.margins = Rect(0, 0, 16, 0);
        topBar.addChild(title);

        topBar.addChild(makeInlineLabel("Search CNIC / Name:"d));
        memberSearchInput = makeEditLine(""d);
        memberSearchInput.layoutWidth = FILL_PARENT;
        memberSearchInput.margins = Rect(0, 0, 12, 0);
        memberSearchInput.contentChange = delegate(EditableContent c) {
            refreshMembersGrid();
        };
        topBar.addChild(memberSearchInput);

        memberFilterAllBtn = makeFilterPill("All"d, true);
        memberFilterAllBtn.click = delegate(Widget w) {
            memberRoleFilter = "All";
            refreshMembersGrid();
            return true;
        };
        memberFilterStudentBtn = makeFilterPill("Students"d, false);
        memberFilterStudentBtn.click = delegate(Widget w) {
            memberRoleFilter = "Student";
            refreshMembersGrid();
            return true;
        };
        memberFilterTeacherBtn = makeFilterPill("Teachers"d, false);
        memberFilterTeacherBtn.click = delegate(Widget w) {
            memberRoleFilter = "Teacher";
            refreshMembersGrid();
            return true;
        };
        topBar.addChild(memberFilterAllBtn);
        topBar.addChild(memberFilterStudentBtn);
        topBar.addChild(memberFilterTeacherBtn);

        auto issueToBtn = makeFilterPill("Issue to Selected"d, false);
        issueToBtn.margins = Rect(8, 0, 8, 0);
        issueToBtn.click = delegate(Widget w) {
            if (selectedMemberCnic.length == 0) {
                setStatus("Select a member row first.", true);
                return true;
            }
            issueCnicInput.text = toUTF32(selectedMemberCnic);
            onIssueCnicChanged();
            switchTab("circulation");
            return true;
        };
        topBar.addChild(issueToBtn);

        auto newMemberBtn = makePrimaryButton("+ New Member"d);
        newMemberBtn.click = delegate(Widget w) {
            clearMemberForm();
            return true;
        };
        topBar.addChild(newMemberBtn);

        tablePane.addChild(topBar);
        tablePane.addChild(makeDivider(false, 0xE4E4E7));

        membersGrid = new LinearGridWidget("MEMBERS_GRID");
        membersGrid.layoutWidth = FILL_PARENT;
        membersGrid.layoutHeight = FILL_PARENT;
        membersGrid.cellSelected = delegate(GridWidgetBase src, int col, int row) {
            if (row >= 0 && row < cast(int) displayedMemberCnics.length) {
                loadMemberIntoForm(displayedMemberCnics[row]);
            }
        };
        tablePane.addChild(membersGrid);
        root.addChild(tablePane);
        root.addChild(makeDivider(true, 0xE4E4E7));

        // Right: Member Inspector Drawer (340px)
        auto rightCol = new VerticalLayout();
        rightCol.layoutWidth = 340;
        rightCol.minWidth = 340;
        rightCol.maxWidth = 340;
        rightCol.layoutHeight = FILL_PARENT;
        rightCol.backgroundColor = 0xFAFAFA;

        auto inspectorTop = new HorizontalLayout();
        inspectorTop.layoutWidth = FILL_PARENT;
        inspectorTop.padding = Rect(18, 14, 18, 14);
        inspectorTop.backgroundColor = 0xFFFFFF;
        memberInspectorHeader = new TextWidget(null, "Register Member"d);
        memberInspectorHeader.fontSize = pointsToPixels(13);
        memberInspectorHeader.fontWeight = 700;
        memberInspectorHeader.textColor = 0x18181B;
        inspectorTop.addChild(memberInspectorHeader);
        rightCol.addChild(inspectorTop);
        rightCol.addChild(makeDivider(false, 0xE4E4E7));

        auto inspectorScroll = new ScrollWidget();
        inspectorScroll.layoutWidth = FILL_PARENT;
        inspectorScroll.layoutHeight = FILL_PARENT;
        inspectorScroll.backgroundColor = 0xFAFAFA;

        auto inspector = new VerticalLayout();
        inspector.layoutWidth = 315;
        inspector.layoutHeight = WRAP_CONTENT;
        inspector.padding = Rect(18, 14, 18, 18);
        inspector.backgroundColor = 0xFAFAFA;

        memberFormContainer = new VerticalLayout();
        memberFormContainer.layoutWidth = FILL_PARENT;
        memberFormContainer.layoutHeight = WRAP_CONTENT;
        inspector.addChild(memberFormContainer);

        auto btnRow = new HorizontalLayout();
        btnRow.layoutWidth = FILL_PARENT;
        btnRow.margins = Rect(0, 14, 0, 0);

        auto saveBtn = makePrimaryButton("Save Member"d);
        saveBtn.layoutWidth = FILL_PARENT;
        saveBtn.margins = Rect(0, 0, 8, 0);
        saveBtn.click = delegate(Widget w) {
            saveMemberFromForm();
            return true;
        };
        btnRow.addChild(saveBtn);

        auto delBtn = makeDangerButton("Delete"d);
        delBtn.click = delegate(Widget w) {
            if (selectedMemberCnic.length == 0) return true;
            string err;
            if (!store.deleteMember(selectedMemberCnic, err)) {
                setStatus(err, true);
                return true;
            }
            string deleted = selectedMemberCnic;
            clearMemberForm();
            refreshAll();
            setStatus("Deleted member " ~ deleted ~ ".");
            return true;
        };
        btnRow.addChild(delBtn);

        inspector.addChild(btnRow);
        inspectorScroll.contentWidget = inspector;
        rightCol.addChild(inspectorScroll);
        root.addChild(rightCol);

        return root;
    }

    private void clearMemberForm() {
        selectedMemberCnic = "";
        memberInspectorHeader.text = "Register Member"d;
        foreach (k, ed; memberFormEditors) {
            ed.text = ""d;
        }
        if (memberFormRoleCombo)
            memberFormRoleCombo.selectedItemIndex = 0;
    }

    private void loadMemberIntoForm(string cnic) {
        auto m = store.findMemberByCnic(cnic);
        if (!m) return;
        selectedMemberCnic = cnic;
        memberInspectorHeader.text = toUTF32("Edit Member (" ~ cnic ~ ")");
        foreach (k, ed; memberFormEditors) {
            ed.text = toUTF32(m.get(k));
        }
        if (memberFormRoleCombo) {
            memberFormRoleCombo.selectedItemIndex = (m.get("role") == "Teacher") ? 1 : 0;
        }
    }

    private void saveMemberFromForm() {
        Record rec;
        foreach (k, ed; memberFormEditors) {
            rec.set(k, toUTF8(ed.text));
        }
        if (memberFormRoleCombo) {
            rec.set("role", memberFormRoleCombo.selectedItemIndex == 1 ? "Teacher" : "Student");
        }
        string savedCnic, err;
        if (!store.upsertMember(rec, savedCnic, err)) {
            setStatus(err, true);
            return;
        }
        selectedMemberCnic = savedCnic;
        refreshAll();
        loadMemberIntoForm(savedCnic);
        onIssueCnicChanged();
        setStatus("Saved member CNIC " ~ savedCnic ~ ".");
    }

    // =========================================================================
    // 4. Schema Workspace View (Dynamic Columns & Layout Editor)
    // =========================================================================
    private Widget buildSchemaView() {
        auto root = new HorizontalLayout("SCHEMA_VIEW");
        root.layoutWidth = FILL_PARENT;
        root.layoutHeight = FILL_PARENT;
        root.backgroundColor = 0xFFFFFF;

        auto tablePane = new VerticalLayout();
        tablePane.layoutWidth = FILL_PARENT;
        tablePane.layoutHeight = FILL_PARENT;
        tablePane.backgroundColor = 0xFFFFFF;

        auto topBar = new HorizontalLayout();
        topBar.layoutWidth = FILL_PARENT;
        topBar.layoutHeight = WRAP_CONTENT;
        topBar.padding = Rect(16, 12, 16, 12);
        topBar.alignment = Align.VCenter;
        topBar.backgroundColor = 0xFFFFFF;

        auto title = new TextWidget(null, "Schema"d);
        title.fontSize = pointsToPixels(13);
        title.fontWeight = 700;
        title.textColor = 0x18181B;
        title.margins = Rect(0, 0, 16, 0);
        topBar.addChild(title);

        schemaEntityBookBtn = makeFilterPill("Books Columns"d, true);
        schemaEntityBookBtn.click = delegate(Widget w) {
            currentSchemaEntity = EntityType.book;
            clearSchemaEditor();
            refreshSchemaGrid();
            return true;
        };
        schemaEntityMemberBtn = makeFilterPill("Members Columns"d, false);
        schemaEntityMemberBtn.click = delegate(Widget w) {
            currentSchemaEntity = EntityType.member;
            clearSchemaEditor();
            refreshSchemaGrid();
            return true;
        };
        schemaEntityIssueBtn = makeFilterPill("Issuance Columns"d, false);
        schemaEntityIssueBtn.click = delegate(Widget w) {
            currentSchemaEntity = EntityType.issue;
            clearSchemaEditor();
            refreshSchemaGrid();
            return true;
        };

        topBar.addChild(schemaEntityBookBtn);
        topBar.addChild(schemaEntityMemberBtn);
        topBar.addChild(schemaEntityIssueBtn);

        auto spacer = new Widget();
        spacer.layoutWidth = FILL_PARENT;
        topBar.addChild(spacer);

        auto moveUpBtn = makeFilterPill("Move Up"d, false);
        moveUpBtn.margins = Rect(0, 0, 6, 0);
        moveUpBtn.click = delegate(Widget w) {
            if (selectedSchemaKey.length == 0) return true;
            if (store.moveSchemaField(currentSchemaEntity, selectedSchemaKey, -1)) {
                rebuildDynamicForms();
                refreshAll();
            }
            return true;
        };
        auto moveDownBtn = makeFilterPill("Move Down"d, false);
        moveDownBtn.margins = Rect(0, 0, 8, 0);
        moveDownBtn.click = delegate(Widget w) {
            if (selectedSchemaKey.length == 0) return true;
            if (store.moveSchemaField(currentSchemaEntity, selectedSchemaKey, 1)) {
                rebuildDynamicForms();
                refreshAll();
            }
            return true;
        };
        auto newFieldBtn = makePrimaryButton("+ New Column"d);
        newFieldBtn.click = delegate(Widget w) {
            clearSchemaEditor();
            return true;
        };

        topBar.addChild(moveUpBtn);
        topBar.addChild(moveDownBtn);
        topBar.addChild(newFieldBtn);

        tablePane.addChild(topBar);
        tablePane.addChild(makeDivider(false, 0xE4E4E7));

        schemaGrid = new LinearGridWidget("SCHEMA_GRID");
        schemaGrid.layoutWidth = FILL_PARENT;
        schemaGrid.layoutHeight = FILL_PARENT;
        schemaGrid.cellSelected = delegate(GridWidgetBase src, int col, int row) {
            auto fields = store.schemaFor(currentSchemaEntity);
            if (row >= 0 && row < cast(int) fields.length) {
                loadSchemaFieldIntoEditor(fields[row]);
            }
        };
        tablePane.addChild(schemaGrid);
        root.addChild(tablePane);
        root.addChild(makeDivider(true, 0xE4E4E7));

        // Right: Column Editor (340px)
        auto rightCol = new VerticalLayout();
        rightCol.layoutWidth = 340;
        rightCol.minWidth = 340;
        rightCol.maxWidth = 340;
        rightCol.layoutHeight = FILL_PARENT;
        rightCol.backgroundColor = 0xFAFAFA;

        auto inspectorTop = new HorizontalLayout();
        inspectorTop.layoutWidth = FILL_PARENT;
        inspectorTop.padding = Rect(18, 14, 18, 14);
        inspectorTop.backgroundColor = 0xFFFFFF;
        auto header = new TextWidget(null, "Column Properties"d);
        header.fontSize = pointsToPixels(13);
        header.fontWeight = 700;
        header.textColor = 0x18181B;
        inspectorTop.addChild(header);
        rightCol.addChild(inspectorTop);
        rightCol.addChild(makeDivider(false, 0xE4E4E7));

        auto inspector = new VerticalLayout();
        inspector.layoutWidth = FILL_PARENT;
        inspector.layoutHeight = FILL_PARENT;
        inspector.padding = Rect(18, 14, 18, 18);
        inspector.backgroundColor = 0xFAFAFA;

        schemaCoreBadge = new TextWidget(null, "New Custom Column"d);
        schemaCoreBadge.fontSize = pointsToPixels(9);
        schemaCoreBadge.fontWeight = 600;
        schemaCoreBadge.textColor = 0x2563EB;
        schemaCoreBadge.margins = Rect(0, 0, 0, 12);
        inspector.addChild(schemaCoreBadge);

        inspector.addChild(makeFieldLabel("Column Title"d));
        schemaLabelInput = makeEditLine(""d);
        schemaLabelInput.contentChange = delegate(EditableContent c) {
            if (selectedSchemaKey.length == 0) {
                schemaKeyInput.text = toUTF32(LibraryStore.sanitizeKey(toUTF8(schemaLabelInput.text)));
            }
        };
        inspector.addChild(schemaLabelInput);

        inspector.addChild(makeFieldLabel("Internal Key"d));
        schemaKeyInput = makeEditLine(""d);
        inspector.addChild(schemaKeyInput);

        inspector.addChild(makeFieldLabel("Data Type"d));
        schemaTypeCombo = new ComboBox(null, ["text"d, "number"d, "date"d]);
        schemaTypeCombo.selectedItemIndex = 0;
        schemaTypeCombo.layoutWidth = FILL_PARENT;
        schemaTypeCombo.margins = Rect(0, 2, 0, 10);
        inspector.addChild(schemaTypeCombo);

        schemaReqCheck = new CheckBox(null, "Required field"d);
        schemaReqCheck.margins = Rect(0, 4, 0, 16);
        inspector.addChild(schemaReqCheck);

        auto addOrUpdateBtn = makePrimaryButton("Save Column"d);
        addOrUpdateBtn.layoutWidth = FILL_PARENT;
        addOrUpdateBtn.margins = Rect(0, 0, 0, 8);
        addOrUpdateBtn.click = delegate(Widget w) {
            handleSaveSchemaField();
            return true;
        };
        inspector.addChild(addOrUpdateBtn);

        auto removeBtn = makeDangerButton("Delete Column"d);
        removeBtn.layoutWidth = FILL_PARENT;
        removeBtn.click = delegate(Widget w) {
            if (selectedSchemaKey.length == 0) return true;
            string err;
            if (!store.removeSchemaField(currentSchemaEntity, selectedSchemaKey, err)) {
                setStatus(err, true);
                return true;
            }
            string removed = selectedSchemaKey;
            clearSchemaEditor();
            rebuildDynamicForms();
            refreshAll();
            setStatus("Removed column '" ~ removed ~ "'.");
            return true;
        };
        inspector.addChild(removeBtn);

        rightCol.addChild(inspector);
        root.addChild(rightCol);
        return root;
    }

    private void clearSchemaEditor() {
        selectedSchemaKey = "";
        schemaCoreBadge.text = "New Custom Column"d;
        schemaCoreBadge.textColor = 0x2563EB;
        schemaLabelInput.text = ""d;
        schemaKeyInput.text = ""d;
        schemaKeyInput.enabled = true;
        schemaTypeCombo.selectedItemIndex = 0;
        schemaTypeCombo.enabled = true;
        schemaReqCheck.checked = false;
        schemaReqCheck.enabled = true;
    }

    private void loadSchemaFieldIntoEditor(FieldDef f) {
        selectedSchemaKey = f.key;
        schemaLabelInput.text = toUTF32(f.label);
        schemaKeyInput.text = toUTF32(f.key);
        schemaKeyInput.enabled = false;

        if (f.type == FieldType.number) schemaTypeCombo.selectedItemIndex = 1;
        else if (f.type == FieldType.date) schemaTypeCombo.selectedItemIndex = 2;
        else schemaTypeCombo.selectedItemIndex = 0;

        schemaReqCheck.checked = f.required;
        schemaTypeCombo.enabled = !f.core;
        schemaReqCheck.enabled = !f.core;

        if (f.core) {
            schemaCoreBadge.text = "Core Column (Title editable, key protected)"d;
            schemaCoreBadge.textColor = 0xDC2626;
        } else {
            schemaCoreBadge.text = "Custom Column (Editable & removable)"d;
            schemaCoreBadge.textColor = 0x059669;
        }
    }

    private void handleSaveSchemaField() {
        FieldType ft = FieldType.text;
        if (schemaTypeCombo.selectedItemIndex == 1) ft = FieldType.number;
        else if (schemaTypeCombo.selectedItemIndex == 2) ft = FieldType.date;

        string err;
        if (selectedSchemaKey.length > 0) {
            if (!store.updateSchemaField(currentSchemaEntity, selectedSchemaKey,
                    toUTF8(schemaLabelInput.text), ft, schemaReqCheck.checked, err)) {
                setStatus(err, true);
                return;
            }
            setStatus("Updated column '" ~ selectedSchemaKey ~ "'.");
        } else {
            if (!store.addSchemaField(currentSchemaEntity,
                    toUTF8(schemaKeyInput.text), toUTF8(schemaLabelInput.text),
                    ft, schemaReqCheck.checked, err)) {
                setStatus(err, true);
                return;
            }
            setStatus("Added column '" ~ toUTF8(schemaLabelInput.text) ~ "'.");
            clearSchemaEditor();
        }
        rebuildDynamicForms();
        refreshAll();
    }

    // =========================================================================
    // Dynamic Form Rebuilders (Driven by Live Schemas)
    // =========================================================================
    void rebuildDynamicForms() {
        // 1. Rebuild Book Inspector Form
        bookFormContainer.removeAllChildren();
        bookFormEditors.clear();
        foreach (f; store.schemaFor(EntityType.book)) {
            if (f.key == "id") continue;
            string lbl = f.label ~ (f.required ? " *" : "");
            bookFormContainer.addChild(makeFieldLabel(toUTF32(lbl)));
            dstring defaultVal = ""d;
            if (f.key == "copies") defaultVal = "1"d;
            else if (f.key == "status") defaultVal = "Available"d;
            else if (f.key == "dateAdded") defaultVal = toUTF32(todayIso());
            auto ed = makeEditLine(defaultVal);
            bookFormEditors[f.key] = ed;
            bookFormContainer.addChild(ed);
        }
        if (selectedBookId.length > 0)
            loadBookIntoForm(selectedBookId);

        // 2. Rebuild Member Inspector Form
        memberFormContainer.removeAllChildren();
        memberFormEditors.clear();
        foreach (f; store.schemaFor(EntityType.member)) {
            string lbl = f.label ~ (f.required ? " *" : "");
            memberFormContainer.addChild(makeFieldLabel(toUTF32(lbl)));
            if (f.key == "role" || f.type == FieldType.role) {
                memberFormRoleCombo = new ComboBox(null, ["Student"d, "Teacher"d]);
                memberFormRoleCombo.selectedItemIndex = 0;
                memberFormRoleCombo.layoutWidth = FILL_PARENT;
                memberFormRoleCombo.margins = Rect(0, 2, 0, 8);
                memberFormContainer.addChild(memberFormRoleCombo);
            } else {
                auto ed = makeEditLine(""d);
                memberFormEditors[f.key] = ed;
                memberFormContainer.addChild(ed);
            }
        }
        if (selectedMemberCnic.length > 0)
            loadMemberIntoForm(selectedMemberCnic);

        // 3. Rebuild On-the-Fly Member Form inside Circulation Issue Desk
        onTheFlyMemberBox.removeAllChildren();
        onTheFlyMemberEditors.clear();
        auto flyTitle = new TextWidget(null, "Register New Member"d);
        flyTitle.fontSize = pointsToPixels(10);
        flyTitle.fontWeight = 700;
        flyTitle.textColor = 0x1E3A8A;
        flyTitle.margins = Rect(0, 0, 0, 6);
        onTheFlyMemberBox.addChild(flyTitle);

        foreach (f; store.schemaFor(EntityType.member)) {
            if (f.key == "cnic") continue;
            string lbl = f.label ~ (f.required ? " *" : "");
            onTheFlyMemberBox.addChild(makeFieldLabel(toUTF32(lbl)));
            if (f.key == "role" || f.type == FieldType.role) {
                onTheFlyRoleCombo = new ComboBox(null, ["Student"d, "Teacher"d]);
                onTheFlyRoleCombo.selectedItemIndex = 0;
                onTheFlyRoleCombo.layoutWidth = FILL_PARENT;
                onTheFlyRoleCombo.margins = Rect(0, 2, 0, 6);
                onTheFlyMemberBox.addChild(onTheFlyRoleCombo);
            } else {
                auto ed = makeEditLine(""d);
                onTheFlyMemberEditors[f.key] = ed;
                onTheFlyMemberBox.addChild(ed);
            }
        }

        // 4. Rebuild Dynamic Extra Issue Fields inside Issue Desk
        issueExtraBox.removeAllChildren();
        issueExtraEditors.clear();
        foreach (f; store.schemaFor(EntityType.issue)) {
            if (f.core) continue;
            string lbl = f.label ~ (f.required ? " *" : "");
            issueExtraBox.addChild(makeFieldLabel(toUTF32(lbl)));
            auto ed = makeEditLine(""d);
            issueExtraEditors[f.key] = ed;
            issueExtraBox.addChild(ed);
        }
    }

    // =========================================================================
    // Grid & State Refreshers
    // =========================================================================
    void refreshAll() {
        refreshSidebarStats();
        refreshIssueBookCombo();
        refreshIssuesGrid();
        refreshBooksGrid();
        refreshMembersGrid();
        refreshSchemaGrid();
    }

    private void refreshSidebarStats() {
        int activeIssues = 0;
        foreach (ref iss; store.issues) {
            if (iss.get("returned_at").length == 0)
                activeIssues++;
        }
        statBooksText.text   = toUTF32("Books: " ~ to!string(store.books.length));
        statMembersText.text = toUTF32("Members: " ~ to!string(store.members.length));
        statIssuesText.text  = toUTF32("Active Issues: " ~ to!string(activeIssues));
    }

    private void refreshIssueBookCombo() {
        string q = toUTF8(issueBookFilterInput.text).strip().toLower();
        issueBookIds = [];
        dstring[] items;

        foreach (ref b; store.books) {
            string id = b.get("id");
            int avail = store.availableCopiesForBook(id);
            if (avail <= 0) continue;

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
            issueBookIds ~= id;
            string acc = b.get("accessionNo");
            string prefix = acc.length > 0 ? ("#" ~ id ~ " (Acc " ~ acc ~ ")") : ("#" ~ id);
            string label = "[" ~ prefix ~ "] " ~ b.get("title") ~ " (" ~ to!string(avail) ~ " left)";
            items ~= shapeForDisplay(toUTF32(label));
            if (items.length >= 250) break; // keep dropdown responsive on 2500+ books
        }

        issueBookCombo.items = items;
        if (items.length > 0)
            issueBookCombo.selectedItemIndex = 0;
    }

    private void refreshIssuesGrid() {
        styleFilterPill(issueFilterActiveBtn,  issueFilterMode == "active");
        styleFilterPill(issueFilterOverdueBtn, issueFilterMode == "overdue");
        styleFilterPill(issueFilterAllBtn,     issueFilterMode == "all");

        string q = toUTF8(issueSearchInput.text).strip().toLower();
        string today = todayIso();

        FieldDef[] extraIssueFields;
        foreach (f; store.schemaFor(EntityType.issue)) {
            if (!f.core)
                extraIssueFields ~= f;
        }

        string[] headers = ["Issue ID", "Status", "Book ID", "Book Title", "Member CNIC", "Member Name", "Role", "Issued", "Due", "Returned"];
        int[] widths     = [85,         90,       80,        220,          130,           160,           85,     100,      100,   100];
        foreach (f; extraIssueFields) {
            headers ~= f.label;
            widths ~= f.width;
        }

        displayedIssueIds = [];
        dstring[][] rows;

        foreach (ref iss; store.issues) {
            bool isReturned = iss.get("returned_at").length > 0;
            bool isOverdue = !isReturned && iss.get("due_at").length > 0 && iss.get("due_at") < today;
            string status = isReturned ? "Returned" : (isOverdue ? "Overdue" : "Active");

            if (issueFilterMode == "active" && isReturned) continue;
            if (issueFilterMode == "overdue" && !isOverdue) continue;

            string bookId = iss.get("book_id");
            string cnic = iss.get("member_cnic");
            auto book = store.findBook(bookId);
            auto member = store.findMemberByCnic(cnic);
            string bookTitle = book ? book.get("title") : "";
            string memberName = member ? member.get("name") : "";
            string memberRole = member ? member.get("role") : "";

            if (q.length > 0) {
                string hay = (iss.get("id") ~ " " ~ bookId ~ " " ~ bookTitle ~ " " ~ cnic ~ " " ~ memberName ~ " " ~ status).toLower();
                if (!hay.canFind(q)) continue;
            }

            displayedIssueIds ~= iss.get("id");
            dstring[] row = [
                toUTF32(iss.get("id")),
                toUTF32(status),
                toUTF32(bookId),
                toUTF32(bookTitle),
                toUTF32(cnic),
                toUTF32(memberName),
                toUTF32(memberRole),
                toUTF32(iss.get("issued_at")),
                toUTF32(iss.get("due_at")),
                toUTF32(iss.get("returned_at"))
            ];
            foreach (f; extraIssueFields) {
                row ~= toUTF32(iss.get(f.key));
            }
            rows ~= row;
        }

        populateGrid(issuesGrid, headers, widths, rows);
    }

    private void refreshBooksGrid() {
        auto schema = store.schemaFor(EntityType.book);
        string q = toUTF8(bookSearchInput.text).strip().toLower();
        bool availOnly = bookAvailOnlyCheck && bookAvailOnlyCheck.checked;

        string[] headers;
        int[] widths;
        foreach (f; schema) {
            headers ~= f.label;
            widths ~= f.width;
            if (f.key == "id") {
                headers ~= "Available";
                widths ~= 90;
            }
        }

        displayedBookIds = [];
        dstring[][] rows;

        foreach (ref b; store.books) {
            string id = b.get("id");
            int avail = store.availableCopiesForBook(id);
            int total = store.totalCopiesForBook(id);
            if (availOnly && avail <= 0) continue;

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

            displayedBookIds ~= id;
            dstring[] row;
            foreach (f; schema) {
                row ~= toUTF32(b.get(f.key));
                if (f.key == "id") {
                    string availStr = avail <= 0 ? "0 left" : (to!string(avail) ~ " / " ~ to!string(total));
                    row ~= toUTF32(availStr);
                }
            }
            rows ~= row;
        }

        populateGrid(booksGrid, headers, widths, rows);
    }

    private void refreshMembersGrid() {
        styleFilterPill(memberFilterAllBtn,     memberRoleFilter == "All");
        styleFilterPill(memberFilterStudentBtn, memberRoleFilter == "Student");
        styleFilterPill(memberFilterTeacherBtn, memberRoleFilter == "Teacher");

        auto schema = store.schemaFor(EntityType.member);
        string q = toUTF8(memberSearchInput.text).strip().toLower();
        string qNormCnic = normalizeCnic(q);

        string[] headers;
        int[] widths;
        foreach (f; schema) {
            headers ~= f.label;
            widths ~= f.width;
        }
        headers ~= "Active Issues";
        widths ~= 100;

        displayedMemberCnics = [];
        dstring[][] rows;

        foreach (ref m; store.members) {
            string role = m.get("role");
            if (memberRoleFilter != "All" && role != memberRoleFilter) continue;

            string cnic = m.get("cnic");
            if (q.length > 0) {
                bool match = false;
                if (qNormCnic.length > 0 && cnic.canFind(qNormCnic)) {
                    match = true;
                } else {
                    foreach (k, v; m.data) {
                        if (v.toLower().canFind(q)) {
                            match = true;
                            break;
                        }
                    }
                }
                if (!match) continue;
            }

            displayedMemberCnics ~= cnic;
            dstring[] row;
            foreach (f; schema) {
                row ~= toUTF32(m.get(f.key));
            }
            row ~= toUTF32(to!string(store.activeIssueCountForMember(cnic)));
            rows ~= row;
        }

        populateGrid(membersGrid, headers, widths, rows);
    }

    private void refreshSchemaGrid() {
        styleFilterPill(schemaEntityBookBtn,   currentSchemaEntity == EntityType.book);
        styleFilterPill(schemaEntityMemberBtn, currentSchemaEntity == EntityType.member);
        styleFilterPill(schemaEntityIssueBtn,  currentSchemaEntity == EntityType.issue);

        auto fields = store.schemaFor(currentSchemaEntity);
        string[] headers = ["#", "Key", "Column Title", "Type", "Required", "Kind"];
        int[] widths     = [45,  140,   220,            100,    95,         95];

        dstring[][] rows;
        foreach (i, f; fields) {
            rows ~= [
                toUTF32(to!string(i + 1)),
                toUTF32(f.key),
                toUTF32(f.label),
                toUTF32(cast(string) f.type),
                f.required ? "Yes"d : "Optional"d,
                f.core ? "Core"d : "Custom"d
            ];
        }

        populateGrid(schemaGrid, headers, widths, rows);
    }

    private static void populateGrid(LinearGridWidget grid, string[] headers, int[] widths, dstring[][] rows) {
        int colCount = cast(int) headers.length;
        int rowCount = cast(int) rows.length;
        grid.resize(colCount, rowCount);
        foreach (c, h; headers) {
            grid.setColTitle(cast(int) c, UIString.fromRaw(toUTF32(h)));
            if (c < widths.length)
                grid.setColWidth(cast(int) c, widths[c]);
        }
        foreach (r, rowData; rows) {
            foreach (c, val; rowData) {
                grid.setCellText(cast(int) c, cast(int) r, UIString.fromRaw(val));
            }
        }
        grid.autoFitRowHeights();
        grid.invalidate();
    }

    // =========================================================================
    // Clean UI Component Helpers (Opaque 0xRRGGBB Colors)
    // =========================================================================
    private static TextWidget makeFieldLabel(dstring text) {
        auto t = new TextWidget(null, text);
        t.fontSize = pointsToPixels(9);
        t.fontWeight = 600;
        t.textColor = 0x3F3F46;
        t.margins = Rect(0, 6, 0, 2);
        return t;
    }

    private static TextWidget makeInlineLabel(dstring text) {
        auto t = new TextWidget(null, text);
        t.fontSize = pointsToPixels(9);
        t.fontWeight = 600;
        t.textColor = 0x52525B;
        t.margins = Rect(0, 0, 6, 0);
        return t;
    }

    private static EditLine makeEditLine(dstring initialText) {
        auto e = new EditLine(null, initialText);
        e.layoutWidth = FILL_PARENT;
        e.fontSize = pointsToPixels(10);
        e.textColor = 0x18181B;
        e.margins = Rect(0, 0, 0, 6);
        return e;
    }

    private static FlatButton makePrimaryButton(dstring text) {
        return new FlatButton(text, 0x2563EB, 0xFFFFFF, 0x1D4ED8);
    }

    private static FlatButton makeSuccessButton(dstring text) {
        return new FlatButton(text, 0x059669, 0xFFFFFF, 0x047857);
    }

    private static FlatButton makeDangerButton(dstring text) {
        return new FlatButton(text, 0xFEE2E2, 0xDC2626, 0xFECACA, 0xFCA5A5);
    }

    private static FlatButton makeFilterPill(dstring text, bool active) {
        auto b = new FlatButton(text);
        b.fontSize = pointsToPixels(9);
        b.padding = Rect(12, 6, 12, 6);
        b.margins = Rect(0, 0, 6, 0);
        styleFilterPill(b, active);
        return b;
    }

    private static void styleFilterPill(FlatButton b, bool active) {
        if (!b) return;
        if (active)
            b.setColors(0x18181B, 0xFFFFFF, 0x27272A, 0x18181B);
        else
            b.setColors(0xF4F4F5, 0x3F3F46, 0xE4E4E7, 0xD4D4D8);
    }

    private static FlatButton makeSmallBtn(dstring text) {
        auto b = new FlatButton(text, 0xE4E4E7, 0x27272A, 0xD4D4D8, 0xD4D4D8);
        b.fontSize = pointsToPixels(8);
        b.padding = Rect(7, 3, 7, 3);
        b.margins = Rect(4, 2, 0, 2);
        return b;
    }
}
