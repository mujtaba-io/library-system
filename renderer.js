const booksTableBody = document.getElementById('booksTableBody');
const searchInput = document.getElementById('searchInput');
const addBookBtn = document.getElementById('addBookBtn');
const addBookModal = document.getElementById('addBookModal');
const closeBtn = document.querySelector('.close');
const addBookForm = document.getElementById('addBookForm');
const prevPageBtn = document.getElementById('prevPageBtn');
const nextPageBtn = document.getElementById('nextPageBtn');
const pageInfo = document.getElementById('pageInfo');

let currentPage = 1;
const itemsPerPage = 8;
let currentSearch = '';

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

        row.innerHTML = `
            <td><strong style="color: white;">${book.title}</strong></td>
            <td>${book.author}</td>
            <td>${book.isbn}</td>
            <td>${book.category}</td>
            <td><span class="status-badge ${statusClass}">${book.status}</span></td>
            <td>
                <button class="action-btn" onclick="window.location.href='details.html?id=${book.id}'">
                    <i class="fa-solid fa-eye"></i>
                </button>
            </td>
        `;
        booksTableBody.appendChild(row);
    });
}

// Initial Load
loadBooks();

// Search Listener (Debounced slightly for performance, though not strictly necessary for local DB)
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

// Modal Logic
addBookBtn.onclick = () => {
    addBookModal.style.display = "block";
}

closeBtn.onclick = () => {
    addBookModal.style.display = "none";
}

window.onclick = (event) => {
    if (event.target == addBookModal) {
        addBookModal.style.display = "none";
    }
}

// Form Submit
addBookForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const formData = new FormData(addBookForm);
    const book = {
        title: formData.get('title'),
        author: formData.get('author'),
        isbn: formData.get('isbn'),
        category: formData.get('category'),
        status: formData.get('status'),
        description: formData.get('description'),
    };

    await window.api.addBook(book);
    addBookModal.style.display = "none";
    addBookForm.reset();
    loadBooks(); // Refresh list
});
