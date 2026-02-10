const container = document.getElementById('detailsContainer');
const urlParams = new URLSearchParams(window.location.search);
const memberInternalId = urlParams.get('id');

let currentMember = null;

async function loadDetails() {
    if (!memberInternalId) {
        container.innerHTML = '<p>Error: No member ID specified.</p>';
        return;
    }

    currentMember = await window.api.getMemberById(memberInternalId);

    if (!currentMember) {
        container.innerHTML = '<p>Member not found.</p>';
        return;
    }

    renderViewMode();
}

function renderViewMode() {
    container.innerHTML = `
        <div class="member-header">
            <div class="member-title-section">
                <h1>${currentMember.name}</h1>
                <div class="type" style="font-size: 1.2rem; color: var(--accent);">${currentMember.type}</div>
            </div>
            <div class="member-id-badge" style="background: var(--sidebar-bg); padding: 8px 16px; border-radius: 8px; border: 1px solid var(--border);">
                <small style="color: var(--text-secondary); display: block;">Member ID</small>
                <strong>${currentMember.memberId}</strong>
            </div>
        </div>

        <div class="member-meta">
            <div class="meta-item">
                <label>Class/Department</label>
                <span>${currentMember.class || '-'}</span>
            </div>
            <div class="meta-item">
                <label>Roll No</label>
                <span>${currentMember.rollNo || '-'}</span>
            </div>
            <div class="meta-item">
                <label>Contact No</label>
                <span>${currentMember.contact || '-'}</span>
            </div>
        </div>

        <div class="actions-row">
            <button onclick="enableEditMode()" class="btn-primary"><i class="fa-solid fa-pen"></i> Edit Member</button>
            <button onclick="deleteMember()" class="btn-danger"><i class="fa-solid fa-trash"></i> Delete Member</button>
        </div>
    `;
}

function renderEditMode() {
    console.log('[Member Details] Render Edit Mode');
    container.innerHTML = ''; // Force clear
    container.innerHTML = `
        <div class="member-header">
            <div class="member-title-section" style="width: 100%;">
                <label style="color: var(--text-secondary);">Name</label>
                <input type="text" id="editName" class="edit-input" value="${currentMember.name}" style="font-size: 2rem; margin-bottom: 10px;">
                
                <label style="color: var(--text-secondary);">Type</label>
                <select id="editType" class="edit-input" style="width: auto; display: block; margin-top: 5px;">
                    <option value="Student" ${currentMember.type === 'Student' ? 'selected' : ''}>Student</option>
                    <option value="Teacher" ${currentMember.type === 'Teacher' ? 'selected' : ''}>Teacher</option>
                </select>
            </div>
        </div>

        <div class="member-meta">
            <div class="meta-item">
                <label>Member ID</label>
                <input type="text" id="editMemberIdField" class="edit-input" value="${currentMember.memberId}">
            </div>
            <div class="meta-item">
                <label>Class/Department</label>
                <input type="text" id="editClass" class="edit-input" value="${currentMember.class || ''}">
            </div>
            <div class="meta-item">
                <label>Roll No</label>
                <input type="text" id="editRollNo" class="edit-input" value="${currentMember.rollNo || ''}">
            </div>
            <div class="meta-item">
                <label>Contact No</label>
                <input type="text" id="editContact" class="edit-input" value="${currentMember.contact || ''}">
            </div>
        </div>

        <div class="actions-row">
            <button onclick="saveChanges()" class="btn-primary"><i class="fa-solid fa-save"></i> Save Changes</button>
            <button onclick="cancelEdit()" class="btn-secondary">Cancel</button>
        </div>
    `;

    // Fix for focus issue on subsequent edits
    setTimeout(() => {
        const nameInput = document.getElementById('editName');
        if (nameInput) {
            nameInput.focus();
        }
    }, 50);
}

window.enableEditMode = () => {
    renderEditMode();
};

window.cancelEdit = () => {
    renderViewMode();
};

window.saveChanges = async () => {
    const updates = {
        memberId: document.getElementById('editMemberIdField').value,
        name: document.getElementById('editName').value,
        type: document.getElementById('editType').value,
        class: document.getElementById('editClass').value,
        rollNo: document.getElementById('editRollNo').value,
        contact: document.getElementById('editContact').value
    };

    if (!updates.name || !updates.memberId) {
        alert('Name and Member ID are required.');
        return;
    }

    try {
        const updatedMember = await window.api.updateMember(memberInternalId, updates);
        currentMember = updatedMember;
        renderViewMode();
    } catch (error) {
        console.error(error);
        alert('Failed to update member.');
    }
};

window.deleteMember = async () => {
    if (confirm('Are you sure you want to delete this member? This action cannot be undone.')) {
        try {
            await window.api.deleteMember(memberInternalId);
            window.location.href = 'index.html';
        } catch (error) {
            console.error(error);
            alert('Failed to delete member.');
        }
    }
};

// Initial Load
loadDetails();
