const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
    getBooks: (params) => ipcRenderer.invoke('get-books', params),
    getBookById: (id) => ipcRenderer.invoke('get-book-by-id', id),
    addBook: (book) => ipcRenderer.invoke('add-book', book),
    updateBook: (id, updates) => ipcRenderer.invoke('update-book', id, updates),
    deleteBook: (id) => ipcRenderer.invoke('delete-book', id)
});
