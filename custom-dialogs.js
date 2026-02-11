/**
 * Custom Dialog System to replace native alert() and confirm()
 * This prevents window focus loss on Windows/Electron environments.
 */

// Inject Styles dynamically if not present in CSS, or rely on styles.css
// Ideally, we add the HTML structure dynamically when needed.

const createDialogOverlay = () => {
    let overlay = document.getElementById('custom-dialog-overlay');
    if (!overlay) {
        overlay = document.createElement('div');
        overlay.id = 'custom-dialog-overlay';
        overlay.className = 'custom-dialog-overlay';
        document.body.appendChild(overlay);
    }
    return overlay;
};

const showDialog = (message, type = 'alert') => {
    return new Promise((resolve) => {
        const overlay = createDialogOverlay();

        // Prevent background scrolling
        document.body.style.overflow = 'hidden';

        // Dialog Content
        const content = document.createElement('div');
        content.className = 'custom-dialog-content';

        const title = document.createElement('h3');
        title.innerText = type === 'confirm' ? 'Confirmation' : 'Alert';

        const msg = document.createElement('p');
        msg.innerText = message;

        const btnContainer = document.createElement('div');
        btnContainer.className = 'custom-dialog-actions';

        // OK Button (for both)
        const okBtn = document.createElement('button');
        okBtn.innerText = 'OK';
        okBtn.className = 'btn-primary';
        okBtn.onclick = () => {
            closeDialog(overlay);
            resolve(true);
        };

        // Cancel Button (for confirm only)
        if (type === 'confirm') {
            const cancelBtn = document.createElement('button');
            cancelBtn.innerText = 'Cancel';
            cancelBtn.className = 'btn-secondary';
            cancelBtn.style.marginRight = '10px';
            cancelBtn.onclick = () => {
                closeDialog(overlay);
                resolve(false);
            };
            btnContainer.appendChild(cancelBtn);
        }

        btnContainer.appendChild(okBtn);

        content.appendChild(title);
        content.appendChild(msg);
        content.appendChild(btnContainer);

        overlay.innerHTML = ''; // Clear previous
        overlay.appendChild(content);

        // Show
        overlay.classList.add('active');

        // Focus core logic
        setTimeout(() => {
            if (type === 'confirm') {
                // Try to focus cancel first to avoid accidental clicks? 
                // Or OK. Let's focus OK for standard behavior
                okBtn.focus();
            } else {
                okBtn.focus();
            }
        }, 50);
    });
};

const closeDialog = (overlay) => {
    overlay.classList.remove('active');
    document.body.style.overflow = '';
    // Restore focus if possible? 
    // The main issue was window losing focus. 
    // By staying in DOM, window focus persists.
};

// Export globally
window.customAlert = async (message) => {
    await showDialog(message, 'alert');
};

window.customConfirm = async (message) => {
    return await showDialog(message, 'confirm');
};
