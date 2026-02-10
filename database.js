const low = require('lowdb');
const FileSync = require('lowdb/adapters/FileSync');
const path = require('path');

// Initialize database
const adapter = new FileSync(path.join(__dirname, 'library.json'));
const db = low(adapter);

// Set defaults if library.json doesn't exist
db.defaults({ books: [] }).write();

module.exports = {
  // Get books with pagination and filtering
  getBooks: (params = {}) => {
    const { page = 1, limit = 10, search = '', category = '', status = '' } = params;

    let chain = db.get('books');

    // Filter by Search
    if (search) {
      const q = search.toLowerCase();
      chain = chain.filter(book =>
        book.title.toLowerCase().includes(q) ||
        book.author.toLowerCase().includes(q) ||
        book.isbn.includes(q)
      );
    }

    // Filter by Category
    if (category && category !== 'All') {
      chain = chain.filter({ category });
    }

    // Filter by Status
    if (status && status !== 'All') {
      chain = chain.filter({ status });
    }

    const total = chain.size().value();
    const totalPages = Math.ceil(total / limit);
    const offset = (page - 1) * limit;

    const data = chain
      .slice(offset, offset + limit)
      .value();

    return {
      data,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total,
        totalPages
      }
    };
  },

  // Get a single book by ID
  getBookById: (id) => {
    return db.get('books').find({ id }).value();
  },

  // Add a new book
  addBook: (book) => {
    // Generate a simple ID (timestamp + random) or use uuid if installed. 
    // Keeping it simple with Date.now() for this demo.
    const newBook = { ...book, id: Date.now().toString() };
    db.get('books').push(newBook).write();
    return newBook;
  },

  // Update a book
  updateBook: (id, updates) => {
    db.get('books').find({ id }).assign(updates).write();
    return db.get('books').find({ id }).value();
  },

  // Delete a book
  deleteBook: (id) => {
    db.get('books').remove({ id }).write();
  }
};
