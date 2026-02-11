const booksTableBody = document.getElementById('booksTableBody');
const searchInput = document.getElementById('searchInput');
const addBookBtn = document.getElementById('addBookBtn');
const addBookModal = document.getElementById('addBookModal');
const closeBtn = document.querySelector('.close');
const addBookForm = document.getElementById('addBookForm');
const prevPageBtn = document.getElementById('prevPageBtn');
const nextPageBtn = document.getElementById('nextPageBtn');
const pageInfo = document.getElementById('pageInfo');

// New Selectors
const menuCatalog = document.getElementById('menu-catalog');
const menuIssued = document.getElementById('menu-issued');
const menuMembers = document.getElementById('menu-members');

const catalogView = document.getElementById('catalog-view');
const issuedView = document.getElementById('issued-view');
const membersView = document.getElementById('members-view');

const issuedTableBody = document.getElementById('issuedTableBody');
const issueBookModal = document.getElementById('issueBookModal');
const closeIssueBtn = document.querySelector('.close-issue');
const issueBookForm = document.getElementById('issueBookForm');

const membersTableBody = document.getElementById('membersTableBody');
const addMemberBtn = document.getElementById('addMemberBtn');
const addMemberModal = document.getElementById('addMemberModal');
const closeMemberBtn = document.querySelector('.close-member');
const addMemberForm = document.getElementById('addMemberForm');

// Issue Modal Specifics
const memberSelectMode = document.getElementById('memberSelectMode');
const existingMemberGroup = document.getElementById('existingMemberGroup');
const newMemberGroup = document.getElementById('newMemberGroup');
const memberSearchInput = document.getElementById('memberSearchInput');
const memberSearchResults = document.getElementById('memberSearchResults');
const issueDateInput = document.getElementById('issueDate');

let currentPage = 1;
const itemsPerPage = 64;
let currentSearch = '';

// Navigation Logic
menuCatalog.addEventListener('click', () => {
    setActiveMenu(menuCatalog, catalogView);
    document.querySelector('.controls-bar').style.display = 'flex'; // Show controls
    document.querySelector('.pagination-controls').style.display = 'flex'; // Show pagination
    loadBooks();
});

menuIssued.addEventListener('click', () => {
    setActiveMenu(menuIssued, issuedView);
    document.querySelector('.controls-bar').style.display = 'none'; // Hide controls for now
    document.querySelector('.pagination-controls').style.display = 'none'; // Hide pagination for now
    loadIssuedBooks();
});

menuMembers.addEventListener('click', () => {
    setActiveMenu(menuMembers, membersView);
    document.querySelector('.controls-bar').style.display = 'none'; // Hide catalog controls
    document.querySelector('.pagination-controls').style.display = 'none'; // Hide pagination
    loadMembers();
});

function setActiveMenu(menuItem, viewItem) {
    [menuCatalog, menuIssued, menuMembers].forEach(m => {
        if (m) m.classList.remove('active');
    });
    [catalogView, issuedView, membersView].forEach(v => {
        if (v) v.style.display = 'none';
    });

    if (menuItem) menuItem.classList.add('active');
    if (viewItem) viewItem.style.display = 'block';
}

// Load books with pagination
async function loadBooks() {
    // Show loading state
    booksTableBody.innerHTML = '<tr><td colspan="6" style="text-align: center;">Loading...</td></tr>';

    const params = {
        page: currentPage,
        limit: itemsPerPage,
        search: currentSearch
    };

    const result = await window.api.getBooks(params);
    const books = result.data;
    const pagination = result.pagination;

    // Update Pagination Controls
    pageInfo.innerText = `Page ${pagination.page} of ${pagination.totalPages || 1}`;
    prevPageBtn.disabled = pagination.page <= 1;
    nextPageBtn.disabled = pagination.page >= pagination.totalPages;

    booksTableBody.innerHTML = '';

    if (books.length === 0) {
        booksTableBody.innerHTML = '<tr><td colspan="6" style="text-align: center; color: var(--text-secondary);">No books found.</td></tr>';
        return;
    }

    books.forEach(book => {
        const row = document.createElement('tr');
        const statusClass = book.status === 'Available' ? 'status-available' : 'status-checked';

        let actionButtons = `
            <button class="action-btn" onclick="window.location.href='details.html?id=${book.id}'" title="View Details">
                <i class="fa-solid fa-eye"></i> View
            </button>
        `;

        // Add Issue button if available
        if (book.status === 'Available') {
            actionButtons += `
                <button class="action-btn" onclick="openIssueModal('${book.id}', '${book.title.replace(/'/g, "\\'")}', '${book.accessionNo || ''}')" title="Issue Book">
                    <i class="fa-solid fa-hand-holding-hand"></i> Issue
                </button>
            `;
        }

        row.innerHTML = `
            <td>${book.accessionNo || '-'}</td>
            <td><strong>${book.title}</strong></td>
            <td>${book.author}</td>
            <td>${book.class || '-'}</td>
            <td><span class="status-badge ${statusClass}">${book.status}</span></td>
            <td>${actionButtons}</td>
        `;
        booksTableBody.appendChild(row);
    });
}

// Load Issued Books
async function loadIssuedBooks() {
    issuedTableBody.innerHTML = '<tr><td colspan="9" style="text-align: center;">Loading...</td></tr>';

    const issuedBooks = await window.api.getIssuedBooks();

    issuedTableBody.innerHTML = '';

    if (issuedBooks.length === 0) {
        issuedTableBody.innerHTML = '<tr><td colspan="9" style="text-align: center; color: var(--text-secondary);">No books currently issued.</td></tr>';
        return;
    }

    issuedBooks.forEach(record => {
        const row = document.createElement('tr');
        const statusClass = record.status === 'Issued' ? 'status-checked' : 'status-available';

        row.innerHTML = `
            <td><strong>${record.bookTitle}</strong></td>
            <td>${record.accessionNo || '-'}</td>
            <td>${record.memberName || record.studentName || '-'}</td>
            <td>${record.memberDisplayId || record.memberId || '-'}</td>
            <td>${record.issueDate}</td>
            <td>${record.dueDate || record.returnDate}</td>
            <td>${record.fine || 0}</td>
            <td><span class="status-badge ${statusClass}">${record.status}</span></td>
            <td>
                <button class="action-btn" onclick="returnBook('${record.id}')" title="Return Book">
                    <i class="fa-solid fa-rotate-left"></i> Return
                </button>
            </td>
        `;
        issuedTableBody.appendChild(row);
    });
}

// Load Members
async function loadMembers() {
    membersTableBody.innerHTML = '<tr><td colspan="6" style="text-align: center;">Loading...</td></tr>';
    const members = await window.api.getMembers('');
    membersTableBody.innerHTML = '';

    if (members.length === 0) {
        membersTableBody.innerHTML = '<tr><td colspan="6" style="text-align: center; color: var(--text-secondary);">No members found.</td></tr>';
        return;
    }

    members.forEach(member => {
        const row = document.createElement('tr');

        row.innerHTML = `
            <td>${member.memberId}</td>
            <td><strong>${member.name}</strong></td>
            <td>${member.type}</td>
            <td>${member.class || '-'}</td>
            <td>${member.rollNo || '-'}</td>
            <td>${member.contact || '-'}</td>
            <td>
                <button class="action-btn" onclick="window.location.href='member-details.html?id=${member.id}'" title="View Details">
                    <i class="fa-solid fa-eye"></i> View
                </button>
            </td>
        `;
        membersTableBody.appendChild(row);
    });
}

// Global function to open Issue Modal
window.openIssueModal = (id, title, accessionNo) => {
    document.getElementById('issueBookId').value = id;
    document.getElementById('issueBookTitle').value = title;
    document.getElementById('issueBookTitleDisplay').value = title;
    document.getElementById('issueBookAccession').value = accessionNo || '';

    // Set Issue Date to Today
    document.getElementById('issueDate').value = new Date().toISOString().split('T')[0];

    // Reset selection mode
    if (memberSelectMode) {
        memberSelectMode.value = 'existing';
        toggleMemberMode();
    }

    // Clear previous search results and input
    if (memberSearchInput) {
        memberSearchInput.value = '';
        memberSearchResults.style.display = 'none';
        memberSearchResults.innerHTML = '';
        // Pre-populate with initial list
        performMemberSearch('');
    }

    issueBookModal.style.display = "block";
};

// Global function to return book
window.returnBook = async (issuanceId) => {
    if (await customConfirm('Are you sure you want to return this book?')) {
        await window.api.returnBook(issuanceId);
        loadIssuedBooks();
    }
};

// Issue Modal - Toggle Mode
if (memberSelectMode) {
    memberSelectMode.addEventListener('change', toggleMemberMode);
}

function toggleMemberMode() {
    if (!memberSelectMode) return;

    if (memberSelectMode.value === 'existing') {
        existingMemberGroup.style.display = 'block';
        newMemberGroup.style.display = 'none';
        document.querySelectorAll('#newMemberGroup input, #newMemberGroup select').forEach(i => i.required = false);
    } else {
        existingMemberGroup.style.display = 'none';
        newMemberGroup.style.display = 'block';
        document.querySelectorAll('#newMemberGroup input, #newMemberGroup select').forEach(i => i.required = true);
    }
}

// Member Search
let memberDebounce;
// Define performMemberSearch in outer scope/globally if needed, or attach to window
let performMemberSearch = async () => { };

if (memberSearchInput) {
    // Unified function to perform search
    performMemberSearch = async (query = '') => {
        try {
            console.log(`[Renderer] Performing member search with query: "${query}"`);
            const members = await window.api.getMembers(query);
            console.log(`[Renderer] Member search results:`, members);

            memberSearchResults.innerHTML = '';
            if (members.length > 0) {
                memberSearchResults.style.display = 'block';
                // Default option
                const defaultOption = document.createElement('option');
                defaultOption.text = "Select a member...";
                defaultOption.disabled = true;
                defaultOption.selected = true;
                memberSearchResults.add(defaultOption);

                members.forEach(m => {
                    const option = document.createElement('option');
                    option.value = m.id; // Use INTERNAL ID
                    option.text = `${m.name} (${m.memberId})`;
                    option.dataset.name = m.name;
                    memberSearchResults.add(option);
                });
                // Auto-size the dropdown, max 10 items
                memberSearchResults.size = Math.min(members.length + 1, 10);
            } else {
                console.log('[Renderer] No members found.');
                memberSearchResults.style.display = 'none';
            }
        } catch (error) {
            console.error('[Renderer] Error searching members:', error);
            await customAlert('Error searching members. Check console.');
        }
    };

    memberSearchInput.addEventListener('input', (e) => {
        clearTimeout(memberDebounce);
        const query = e.target.value;
        memberDebounce = setTimeout(() => {
            performMemberSearch(query);
        }, 300);
    });

    // Show results immediately on focus
    memberSearchInput.addEventListener('focus', () => {
        if (memberSearchResults.options.length === 0 || memberSearchInput.value === '') {
            performMemberSearch(memberSearchInput.value);
        } else {
            memberSearchResults.style.display = 'block';
        }
    });

    // Hide results when clicking outside (optional, but good UX)
    document.addEventListener('click', (e) => {
        if (!memberSearchInput.contains(e.target) && !memberSearchResults.contains(e.target)) {
            memberSearchResults.style.display = 'none';
        }
    });

    memberSearchResults.addEventListener('change', () => {
        const selectedOption = memberSearchResults.options[memberSearchResults.selectedIndex];
        if (selectedOption.disabled) return;

        document.getElementById('selectedMemberId').value = selectedOption.value;
        document.getElementById('selectedMemberName').value = selectedOption.dataset.name;
        memberSearchInput.value = selectedOption.text; // Update input with selected name
        memberSearchResults.style.display = 'none';
    });
}


// Initial Load
loadBooks();

// Search Listener
let debounceTimer;
searchInput.addEventListener('input', (e) => {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
        currentSearch = e.target.value;
        currentPage = 1; // Reset to page 1 on search
        loadBooks();
    }, 300);
});

// Pagination Listeners
prevPageBtn.addEventListener('click', () => {
    if (currentPage > 1) {
        currentPage--;
        loadBooks();
    }
});

nextPageBtn.addEventListener('click', () => {
    currentPage++;
    loadBooks();
});

// Modal Logic - Add Book
addBookBtn.onclick = () => {
    addBookModal.style.display = "block";
}

closeBtn.onclick = () => {
    addBookModal.style.display = "none";
}

// Modal Logic - Issue Book
closeIssueBtn.onclick = () => {
    issueBookModal.style.display = "none";
}

// Modal Logic - Add Member
if (addMemberBtn) {
    addMemberBtn.onclick = () => {
        addMemberModal.style.display = "block";
    }
    closeMemberBtn.onclick = () => {
        addMemberModal.style.display = "none";
    }
}

window.onclick = (event) => {
    if (event.target == addBookModal) {
        addBookModal.style.display = "none";
    }
    if (event.target == issueBookModal) {
        issueBookModal.style.display = "none";
    }
    if (event.target == addMemberModal) {
        addMemberModal.style.display = "none";
    }
}

// Form Submit - Add Book
addBookForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const formData = new FormData(addBookForm);
    const book = {
        title: formData.get('title'),
        author: formData.get('author'),
        accessionNo: formData.get('accessionNo'),
        publisher: formData.get('publisher'),
        year: formData.get('year'),
        subject: formData.get('subject'),
        class: formData.get('class'),
        quantity: formData.get('quantity'),
        shelfNo: formData.get('shelfNo'),
        status: formData.get('status'),
        description: formData.get('description'),
    };

    await window.api.addBook(book);
    addBookModal.style.display = "none";
    addBookForm.reset();
    loadBooks();
});

// Form Submit - Add Member
// Form Submit - Add Member
if (addMemberForm) {
    addMemberForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const formData = new FormData(addMemberForm);
        const member = {
            memberId: formData.get('memberId'),
            name: formData.get('name'),
            type: formData.get('type'),
            class: formData.get('class'),
            rollNo: formData.get('rollNo'),
            contact: formData.get('contact'),
        };
        await window.api.addMember(member);
        addMemberModal.style.display = "none";
        addMemberForm.reset();
        loadMembers(); // Refresh members list if on members tab
    });
}

// Form Submit - Issue Book
issueBookForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const formData = new FormData(issueBookForm);
    const mode = document.getElementById('memberSelectMode').value;

    let memberId, memberName;

    if (mode === 'new') {
        // Add new member first
        const member = {
            memberId: formData.get('newMemberId'),
            name: formData.get('newName'),
            type: formData.get('newType'),
            class: formData.get('newClass'),
            rollNo: formData.get('newRollNo'),
            contact: formData.get('newContact'),
        };
        const newMem = await window.api.addMember(member);
        memberId = newMem.id; // Use INTERNAL ID
        memberName = newMem.name;
    } else {
        memberId = formData.get('selectedMemberId');
        memberName = formData.get('selectedMemberName');
        if (!memberId) {
            await customAlert('Please select a member');
            return;
        }
    }

    const issuance = {
        bookId: formData.get('bookId'),
        bookTitle: formData.get('bookTitle'),
        accessionNo: formData.get('accessionNo'),
        memberId: memberId,
        memberName: memberName,
        issueDate: formData.get('issueDate'),
        dueDate: formData.get('dueDate'),
        fine: formData.get('fine')
    };

    await window.api.issueBook(issuance);
    issueBookModal.style.display = "none";
    issueBookForm.reset();
    loadBooks();
});


