const container = document.getElementById('detailsContainer');
const urlParams = new URLSearchParams(window.location.search);
const bookId = urlParams.get('id');

let currentBook = null;

async function loadDetails() {
    if (!bookId) {
        container.innerHTML = '<p>Error: No book ID specified.</p>';
        return;
    }

    currentBook = await window.api.getBookById(bookId);

    if (!currentBook) {
        container.innerHTML = '<p>Book not found.</p>';
        return;
    }

    renderViewMode();
}

function renderViewMode() {
    const statusClass = currentBook.status === 'Available' ? 'status-available' : 'status-checked';

    container.innerHTML = `
        <div class="book-header">
            <div class="book-title-section">
                <h1>${currentBook.title}</h1>
                <div class="author" style="font-size: 1.2rem; color: var(--text-secondary);">${currentBook.author}</div>
            </div>
            <span class="status-badge ${statusClass}" style="font-size: 1rem; padding: 6px 16px;">${currentBook.status}</span>
        </div>

        <div class="book-meta">
            <div class="meta-item">
                <label>ISBN</label>
                <span>${currentBook.isbn}</span>
            </div>
            <div class="meta-item">
                <label>Category</label>
                <span>${currentBook.category}</span>
            </div>
            <div class="meta-item" style="grid-column: 1/-1;">
                <label>Description</label>
                <p style="line-height: 1.6;">${currentBook.description || 'No description available.'}</p>
            </div>
        </div>

        <div class="actions-row">
            <button onclick="enableEditMode()" class="btn-primary"><i class="fa-solid fa-pen"></i> Edit Book</button>
            <button onclick="deleteBook()" class="btn-danger"><i class="fa-solid fa-trash"></i> Delete Book</button>
        </div>
    `;
}

function renderEditMode() {
    container.innerHTML = `
        <div class="book-header">
            <div class="book-title-section" style="width: 100%;">
                <label style="color: var(--text-secondary);">Title</label>
                <input type="text" id="editTitle" class="edit-input" value="${currentBook.title}" style="font-size: 2rem; margin-bottom: 10px;">
                
                <label style="color: var(--text-secondary);">Author</label>
                <input type="text" id="editAuthor" class="edit-input" value="${currentBook.author}">
            </div>
        </div>

        <div class="book-meta">
            <div class="meta-item">
                <label>ISBN</label>
                <input type="text" id="editIsbn" class="edit-input" value="${currentBook.isbn}">
            </div>
            <div class="meta-item">
                <label>Category</label>
                <select id="editCategory" class="edit-input">
                    <option value="Fiction" ${currentBook.category === 'Fiction' ? 'selected' : ''}>Fiction</option>
                    <option value="Non-Fiction" ${currentBook.category === 'Non-Fiction' ? 'selected' : ''}>Non-Fiction</option>
                    <option value="Science" ${currentBook.category === 'Science' ? 'selected' : ''}>Science</option>
                    <option value="History" ${currentBook.category === 'History' ? 'selected' : ''}>History</option>
                    <option value="Technology" ${currentBook.category === 'Technology' ? 'selected' : ''}>Technology</option>
                </select>
            </div>
            <div class="meta-item">
                <label>Status</label>
                <select id="editStatus" class="edit-input">
                    <option value="Available" ${currentBook.status === 'Available' ? 'selected' : ''}>Available</option>
                    <option value="Checked Out" ${currentBook.status === 'Checked Out' ? 'selected' : ''}>Checked Out</option>
                </select>
            </div>
            <div class="meta-item" style="grid-column: 1/-1;">
                <label>Description</label>
                <textarea id="editDescription" class="edit-input" rows="5">${currentBook.description || ''}</textarea>
            </div>
        </div>

        <div class="actions-row">
            <button onclick="saveChanges()" class="btn-primary"><i class="fa-solid fa-save"></i> Save Changes</button>
            <button onclick="renderViewMode()" class="btn-secondary">Cancel</button>
        </div>
    `;
}

// Make functions available globally so onclick works (since this is a module scope if not careful, but safely exposed via script tag)
window.enableEditMode = renderEditMode;
window.renderViewMode = renderViewMode;

window.saveChanges = async () => {
    const updates = {
        title: document.getElementById('editTitle').value,
        author: document.getElementById('editAuthor').value,
        isbn: document.getElementById('editIsbn').value,
        category: document.getElementById('editCategory').value,
        status: document.getElementById('editStatus').value,
        description: document.getElementById('editDescription').value
    };

    const updatedBook = await window.api.updateBook(bookId, updates);
    currentBook = updatedBook;
    renderViewMode();
};

window.deleteBook = async () => {
    if (confirm('Are you sure you want to delete this book? This cannot be undone.')) {
        await window.api.deleteBook(bookId);
        window.location.href = 'index.html';
    }
};

loadDetails();
