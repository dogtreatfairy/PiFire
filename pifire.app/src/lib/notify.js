// Function to request notification permission
export function browserNotificationPermission() {
    if ("Notification" in window) {
        // Check the current permission state
        if (Notification.permission === "default") {
            // Ask for permission if it hasn't been granted or denied
            Notification.requestPermission().then((permission) => {
                if (permission === "granted") {
                    console.log("Notification permission granted.");
                } else if (permission === "denied") {
                    console.log("Notification permission denied.");
                }
            });
        } else if (Notification.permission === "granted") {
            console.log("Notification permission already granted.");
        } else {
            console.log("Notification permission already denied.");
        }
    } else {
        console.error("This browser does not support notifications.");
    }
}

export function browserNotification(title, body) {
    if ("Notification" in window) {
        // Check if notification permissions are granted
        if (Notification.permission === "granted") {
            new Notification(title, {
                body,
                icon: "/img/logo_nt_1.svg", // Path to the PiFire logo
                requireInteraction: true // Makes the notification persistent
            });
        } else if (Notification.permission !== "denied") {
            // Request permission if not already denied
            Notification.requestPermission().then((permission) => {
                if (permission === "granted") {
                    new Notification(title, {
                        body,
                        icon: "/static/img/logo_no_text.svg", // Path to the PiFire logo
                        requireInteraction: true // Makes the notification persistent
                    });
                }
            });
        }
    } else {
        console.error("This browser does not support notifications.");
    }
}