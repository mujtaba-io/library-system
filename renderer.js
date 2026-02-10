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
const catalogView = document.getElementById('catalog-view');
const issuedView = document.getElementById('issued-view');
const issuedTableBody = document.getElementById('issuedTableBody');
const issueBookModal = document.getElementById('issueBookModal');
const closeIssueBtn = document.querySelector('.close-issue');
const issueBookForm = document.getElementById('issueBookForm');

let currentPage = 1;
const itemsPerPage = 8;
let currentSearch = '';

// Navigation Logic
menuCatalog.addEventListener('click', () => {
    menuCatalog.classList.add('active');
    menuIssued.classList.remove('active');
    catalogView.style.display = 'block';
    issuedView.style.display = 'none';
    document.querySelector('.controls-bar').style.display = 'flex'; // Show controls
    document.querySelector('.pagination-controls').style.display = 'flex'; // Show pagination
    loadBooks();
});

menuIssued.addEventListener('click', () => {
    menuIssued.classList.add('active');
    menuCatalog.classList.remove('active');
    catalogView.style.display = 'none';
    issuedView.style.display = 'block';
    document.querySelector('.controls-bar').style.display = 'none'; // Hide controls for now
    document.querySelector('.pagination-controls').style.display = 'none'; // Hide pagination for now
    loadIssuedBooks();
});

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
                <i class="fa-solid fa-eye"></i>
            </button>
        `;

        // Add Issue button if available
        if (book.status === 'Available') {
            actionButtons += `
                <button class="action-btn" onclick="openIssueModal('${book.id}', '${book.title.replace(/'/g, "\\'")}')" title="Issue Book">
                    <i class="fa-solid fa-hand-holding-hand"></i>
                </button>
            `;
        }

        row.innerHTML = `
            <td>${book.accessionNo || '-'}</td>
            <td><strong style="color: white;">${book.title}</strong></td>
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
    issuedTableBody.innerHTML = '<tr><td colspan="7" style="text-align: center;">Loading...</td></tr>';

    const issuedBooks = await window.api.getIssuedBooks();

    issuedTableBody.innerHTML = '';

    if (issuedBooks.length === 0) {
        issuedTableBody.innerHTML = '<tr><td colspan="7" style="text-align: center; color: var(--text-secondary);">No books currently issued.</td></tr>';
        return;
    }

    issuedBooks.forEach(record => {
        const row = document.createElement('tr');
        const statusClass = record.status === 'Issued' ? 'status-checked' : 'status-available';

        row.innerHTML = `
            <td>${record.studentName}</td>
            <td>${record.studentId}</td>
            <td><strong style="color: white;">${record.bookTitle}</strong></td>
            <td>${record.issueDate}</td>
            <td>${record.returnDate}</td>
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

// Global function to open Issue Modal
window.openIssueModal = (id, title) => {
    document.getElementById('issueBookId').value = id;
    document.getElementById('issueBookTitle').value = title;
    document.getElementById('issueBookTitleDisplay').value = title;
    issueBookModal.style.display = "block";
};

// Global function to return book
window.returnBook = async (issuanceId) => {
    if (confirm('Are you sure you want to return this book?')) {
        await window.api.returnBook(issuanceId);
        loadIssuedBooks();
    }
};

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

window.onclick = (event) => {
    if (event.target == addBookModal) {
        addBookModal.style.display = "none";
    }
    if (event.target == issueBookModal) {
        issueBookModal.style.display = "none";
    }
}

// Form Submit - Add Book
addBookForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const formData = new FormData(addBookForm);
    const book = {
        title: formData.get('title'),
        author: formData.get('author'),
        accessionNo: formData.get('accessionNo'), // New Field
        publisher: formData.get('publisher'), // New Field
        year: formData.get('year'), // New Field
        subject: formData.get('subject'), // New Field
        class: formData.get('class'), // New Field
        quantity: formData.get('quantity'), // New Field
        shelfNo: formData.get('shelfNo'), // New Field
        status: formData.get('status'),
        description: formData.get('description'),
    };

    await window.api.addBook(book);
    addBookModal.style.display = "none";
    addBookForm.reset();
    loadBooks();
});

// Form Submit - Issue Book
issueBookForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const formData = new FormData(issueBookForm);
    const issuance = {
        bookId: formData.get('bookId'),
        bookTitle: formData.get('bookTitle'),
        studentName: formData.get('studentName'),
        studentId: formData.get('studentId'),
        returnDate: formData.get('returnDate'),
    };

    await window.api.issueBook(issuance);
    issueBookModal.style.display = "none";
    issueBookForm.reset();
    loadBooks(); // Refresh catalog to show correct status
});
