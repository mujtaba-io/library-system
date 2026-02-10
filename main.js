const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const db = require('./database');

function createWindow() {
    const win = new BrowserWindow({
        width: 1200,
        height: 800,
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            nodeIntegration: false, // Security best practice
            contextIsolation: true  // Security best practice
        },
        // aesthetic: frame: false for custom title bar if desired, but sticking to standard for stability first unless requested.
        // user asked for premium design, let's keep standard frame for native feel but good content design.
    });

    win.loadFile('index.html');
    // win.webContents.openDevTools(); // Uncomment for debugging
}

app.whenReady().then(() => {
    createWindow();

    app.on('activate', () => {
        if (BrowserWindow.getAllWindows().length === 0) {
            createWindow();
        }
    });
});

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') {
        app.quit();
    }
});

// IPC Handlers for Database Operations
ipcMain.handle('get-books', (event, params) => {
    return db.getBooks(params);
});

ipcMain.handle('get-book-by-id', (event, id) => {
    return db.getBookById(id);
});

ipcMain.handle('add-book', (event, book) => {
    return db.addBook(book);
});

ipcMain.handle('update-book', (event, id, updates) => {
    return db.updateBook(id, updates);
});

ipcMain.handle('delete-book', (event, id) => {
    db.deleteBook(id);
    return { success: true };
});
