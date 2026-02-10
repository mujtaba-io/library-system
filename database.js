const low = require('lowdb');
const FileSync = require('lowdb/adapters/FileSync');
const path = require('path');

// Initialize database
const adapter = new FileSync(path.join(__dirname, 'library.json'));
const db = low(adapter);

// Assuming no uuid for now, sticking to Date.now() + math random for simplicity as per previous code style.

// Set defaults if library.json doesn't exist
db.defaults({ books: [], issuance: [], members: [] }).write();

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
        (book.accessionNo && book.accessionNo.toString().includes(q))
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
  },

  // Issue a book
  issueBook: (issuance) => {
    const newIssuance = {
      ...issuance,
      id: Date.now().toString(),
      status: 'Issued',
      issueDate: new Date().toISOString().split('T')[0] // Store current date (YYYY-MM-DD)
    };

    // Add issuance record
    db.get('issuance').push(newIssuance).write();

    // Update book status
    db.get('books')
      .find({ id: issuance.bookId })
      .assign({ status: 'Checked Out' })
      .write();

    return newIssuance;
  },

  // Get current issued books
  getIssuedBooks: () => {
    const issuances = db.get('issuance').filter({ status: 'Issued' }).value();
    const members = db.get('members').value();

    return issuances.map(issuance => {
      const member = members.find(m => m.id === issuance.memberId);
      if (member) {
        return {
          ...issuance,
          memberName: member.name,
          memberDisplayId: member.memberId, // Store display ID for UI
          contact: member.contact // Optional: current contact info
        };
      }
      return issuance; // Return original if member deleted/not found
    });
  },

  // Return a book
  returnBook: (issuanceId) => {
    // Find issuance record
    const record = db.get('issuance').find({ id: issuanceId }).value();

    if (!record) return null;

    // Update issuance status
    db.get('issuance')
      .find({ id: issuanceId })
      .assign({ status: 'Returned', returnDateActual: new Date().toISOString().split('T')[0] })
      .write();

    // Update book status to Available
    db.get('books')
      .find({ id: record.bookId })
      .assign({ status: 'Available' })
      .write();

    return { success: true };
  },

  // Add a new member
  addMember: (member) => {
    const newMember = { ...member, id: Date.now().toString() };
    db.get('members').push(newMember).write();
    return newMember;
  },

  // Get members with search
  getMembers: (search = '') => {
    let chain = db.get('members');
    if (search) {
      const q = search.toLowerCase();
      chain = chain.filter(member =>
        member.name.toLowerCase().includes(q) ||
        member.memberId.toLowerCase().includes(q) ||
        member.contactNo.includes(q)
      );
    }
    return chain.value();
  },

  // Get member by Internal ID (or Member ID field)
  getMemberById: (id) => {
    return db.get('members').find({ id }).value();
  },

  // Update a member
  updateMember: (id, updates) => {
    db.get('members').find({ id }).assign(updates).write();
    return db.get('members').find({ id }).value();
  },

  // Delete a member
  deleteMember: (id) => {
    db.get('members').remove({ id }).write();
    // Also remove from member id mappings if needed, but for now simple remove is enough.
    return true;
  }
};
