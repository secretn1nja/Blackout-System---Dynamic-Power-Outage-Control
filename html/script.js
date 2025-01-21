document.addEventListener('DOMContentLoaded', () => {
    const drawText = document.getElementById('textDraw');
    const drawTextBtn = document.getElementById('drawtext-btn');
    const displayDraw = document.getElementById('drawtext')

    window.addEventListener('message', ({ data }) => {
        switch (data.type) {
            case 'drawtxt':
                drawTextBtn.innerText = `${data.btn}`;
                drawText.innerText = `${data.text}`;
                displayDraw.style.display = 'flex';
                break;
            case 'hidetxt':
                displayDraw.style.display = 'none';
                break;
            case 'notification':
                showNotification(data.title, data.message, data.duration, data.color);
        }
    });

    function showNotification(title, message, duration = 3000, color) {
        const container = document.getElementById("notification-container");

        const notification = document.createElement("div");
        notification.classList.add("notification");

        notification.innerHTML = `
            <div class="notification-title">${title}</div>
            <div class="notification-message">${message}</div>
        `;
        notification.style.borderLeftColor = color;
        notification.style.borderRightColor = color;

        container.appendChild(notification);

        setTimeout(() => {
            notification.classList.add("fade-out");
            setTimeout(() => container.removeChild(notification), 300);
        }, duration);
    }
});