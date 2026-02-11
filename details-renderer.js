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
                <label>Accession No</label>
                <span>${currentBook.accessionNo}</span>
            </div>
            <div class="meta-item">
                <label>Publisher</label>
                <span>${currentBook.publisher || '-'}</span>
            </div>
            <div class="meta-item">
                <label>Year</label>
                <span>${currentBook.year || '-'}</span>
            </div>
            <div class="meta-item">
                <label>Subject</label>
                <span>${currentBook.subject || '-'}</span>
            </div>
            <div class="meta-item">
                <label>Class</label>
                <span>${currentBook.class || '-'}</span>
            </div>
            <div class="meta-item">
                <label>Quantity</label>
                <span>${currentBook.quantity || '0'}</span>
            </div>
            <div class="meta-item">
                <label>Shelf No</label>
                <span>${currentBook.shelfNo || '-'}</span>
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
                <label>Accession No</label>
                <input type="text" id="editAccessionNo" class="edit-input" value="${currentBook.accessionNo}">
            </div>
            <div class="meta-item">
                <label>Publisher</label>
                <input type="text" id="editPublisher" class="edit-input" value="${currentBook.publisher || ''}">
            </div>
            <div class="meta-item">
                <label>Year</label>
                <input type="text" id="editYear" class="edit-input" value="${currentBook.year || ''}">
            </div>
            <div class="meta-item">
                <label>Subject</label>
                <input type="text" id="editSubject" class="edit-input" value="${currentBook.subject || ''}">
            </div>
            <div class="meta-item">
                <label>Class</label>
                <select id="editClass" class="edit-input">
                    <option value="FA" ${currentBook.class === 'FA' ? 'selected' : ''}>FA</option>
                    <option value="FSc" ${currentBook.class === 'FSc' ? 'selected' : ''}>FSc</option>
                    <option value="BS" ${currentBook.class === 'BS' ? 'selected' : ''}>BS</option>
                </select>
            </div>
            <div class="meta-item">
                <label>Quantity</label>
                <input type="number" id="editQuantity" class="edit-input" value="${currentBook.quantity || '1'}">
            </div>
            <div class="meta-item">
                <label>Shelf No</label>
                <input type="text" id="editShelfNo" class="edit-input" value="${currentBook.shelfNo || ''}">
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
        accessionNo: document.getElementById('editAccessionNo').value,
        publisher: document.getElementById('editPublisher').value,
        year: document.getElementById('editYear').value,
        subject: document.getElementById('editSubject').value,
        class: document.getElementById('editClass').value,
        quantity: document.getElementById('editQuantity').value,
        shelfNo: document.getElementById('editShelfNo').value,
        status: document.getElementById('editStatus').value,
        description: document.getElementById('editDescription').value
    };

    const updatedBook = await window.api.updateBook(bookId, updates);
    currentBook = updatedBook;
    renderViewMode();
};

window.deleteBook = async () => {
    if (await customConfirm('Are you sure you want to delete this book? This cannot be undone.')) {
        await window.api.deleteBook(bookId);
        window.location.href = 'index.html';
    }
};

loadDetails();
