module app;

import dlangui;
import std.algorithm : canFind;
import std.file : exists, remove;
import store;
import ui;

mixin APP_ENTRY_POINT;

extern (C) int UIAppMain(string[] args) {
    if (args.canFind("--self-test")) {
        return runSelfTest();
    }

    Platform.instance.uiTheme = "theme_default";

    auto dataStore = new LibraryStore("data/library_data.json");
    Window window = Platform.instance.createWindow(
        "College Library"d,
        null,
        WindowFlag.Resizable,
        1280,
        800
    );

    auto mainView = new LibraryAppView(dataStore);
    window.mainWidget = mainView;
    window.show();

    return Platform.instance.enterMessageLoop();
}

/// Automated end-to-end verification of legacy data loading, store, dynamic schemas, CNIC lookup, and issuance.
private int runSelfTest() {
    // 0. Verify loading and normalizing actual legacy data/library_data.json
    auto legacyStore = new LibraryStore("data/library_data.json");
    assert(legacyStore.books.length >= 1800, "Legacy and CSV deduplicated books should be loaded");
    auto b1 = legacyStore.findBook("1");
    assert(b1 !is null, "Book with integer id 1 should be loaded");
    assert(b1.get("accessionNo") == "1", "Legacy accessionNo should be preserved");
    assert("isbn" in b1.data, "Missing schema field 'isbn' should be integrated into record");

    string testFile = "library_test_temp.json";
    scope(exit) {
        if (exists(testFile))
            remove(testFile);
    }
    if (exists(testFile))
        remove(testFile);

    auto s = new LibraryStore(testFile);
    assert(s.books.length >= 10, "Default books should be seeded");
    assert(s.members.length >= 4, "Default members should be seeded");

    // 1. Verify CNIC normalization without dashes
    assert(normalizeCnic("35202-4455667-7") == "3520244556677");
    assert(s.findMemberByCnic("35202-4455667-7") !is null, "Should find member with or without dashes");

    // 2. Verify dynamic schema addition for books and members
    string err;
    bool ok = s.addSchemaField(EntityType.book, "call_no", "Call No", FieldType.text, false, err);
    assert(ok, "Should add custom book schema field: " ~ err);

    ok = s.addSchemaField(EntityType.member, "blood_group", "Blood Group", FieldType.text, false, err);
    assert(ok, "Should add custom member schema field: " ~ err);

    // 3. Verify book creation with default/empty fields and custom schema field
    Record newBook;
    newBook.set("title", "Compilers: Principles, Techniques, and Tools");
    newBook.set("copies", "2");
    newBook.set("call_no", "CS-9901");
    string savedBookId;
    ok = s.upsertBook(newBook, savedBookId, err);
    assert(ok && savedBookId.length > 0, "Should save new book: " ~ err);
    assert(s.findBook(savedBookId).get("call_no") == "CS-9901");
    assert(s.findBook(savedBookId).get("publisher") == "", "Nullable fields should be empty");

    // 4. Verify issuing a book to a NON-EXISTENT member creates the member on the fly
    string newCnic = "35202-8888999-1";
    assert(s.findMemberByCnic(newCnic) is null, "Member should not exist yet");

    Record flyMember;
    flyMember.set("name", "Zainab Raza");
    flyMember.set("role", "Teacher");
    flyMember.set("department", "Electrical Engineering");
    flyMember.set("blood_group", "O+");

    Record extraIssue;
    extraIssue.set("condition", "New");

    string issueId;
    ok = s.issueBook(savedBookId, newCnic, flyMember, datePlusDaysIso(14), extraIssue, issueId, err);
    assert(ok, "Should issue book and create member on the fly: " ~ err);

    auto createdMember = s.findMemberByCnic("3520288889991");
    assert(createdMember !is null, "On-the-fly member should now exist by normalized CNIC");
    assert(createdMember.get("name") == "Zainab Raza");
    assert(createdMember.get("role") == "Teacher");
    assert(createdMember.get("blood_group") == "O+");
    assert(s.availableCopiesForBook(savedBookId) == 1);

    // 5. Verify returning the book restores available copies
    ok = s.returnIssue(issueId, err);
    assert(ok, "Should return issued book: " ~ err);
    assert(s.availableCopiesForBook(savedBookId) == 2);

    // 6. Verify reload from disk preserves custom schemas and records
    auto s2 = new LibraryStore(testFile);
    assert(s2.findMemberByCnic("3520288889991").get("blood_group") == "O+");
    assert(s2.findBook(savedBookId).get("call_no") == "CS-9901");

    return 0;
}
