const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
    getBooks: (params) => ipcRenderer.invoke('get-books', params),
    getBookById: (id) => ipcRenderer.invoke('get-book-by-id', id),
    addBook: (book) => ipcRenderer.invoke('add-book', book),
    updateBook: (id, updates) => ipcRenderer.invoke('update-book', id, updates),
    deleteBook: (id) => ipcRenderer.invoke('delete-book', id),
    issueBook: (issuance) => ipcRenderer.invoke('issue-book', issuance),
    getIssuedBooks: () => ipcRenderer.invoke('get-issued-books'),
    returnBook: (issuanceId) => ipcRenderer.invoke('return-book', issuanceId),
    addMember: (member) => ipcRenderer.invoke('add-member', member),
    getMembers: (search) => ipcRenderer.invoke('get-members', search),
    getMemberById: (id) => ipcRenderer.invoke('get-member-by-id', id)
});
