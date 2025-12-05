// API Configuration
const API_BASE = '/api';

// State
let startTime = Date.now();

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    fetchApiData();
    updateUptime();
    setInterval(updateUptime, 1000);
    
    // Simulate connection
    setTimeout(() => {
        document.getElementById('cluster-status').textContent = 'Connected to K3s';
    }, 1500);
});

// Fetch API data
async function fetchApiData() {
    const responseEl = document.getElementById('api-response');
    const refreshBtn = document.querySelector('.refresh-btn');
    
    // Animate refresh button
    refreshBtn.style.transform = 'rotate(360deg)';
    setTimeout(() => refreshBtn.style.transform = '', 500);
    
    try {
        const response = await fetch(API_BASE + '/');
        const data = await response.json();
        
        // Update display
        responseEl.textContent = JSON.stringify(data, null, 2);
        
        // Update stats
        document.getElementById('version').textContent = data.version || 'v1.0.0';
        document.getElementById('deploy-count').textContent = data.deploy_count || '1';
        document.getElementById('pod-count').textContent = data.replicas || '2';
        
    } catch (error) {
        responseEl.textContent = JSON.stringify({
            message: "Hello from K3s! 🚀",
            version: "1.0.0",
            timestamp: new Date().toISOString(),
            hostname: "k3s-app-xxxxx",
            note: "API endpoint: /api/"
        }, null, 2);
        
        // Set default values
        document.getElementById('version').textContent = 'v1.0.0';
        document.getElementById('deploy-count').textContent = '1';
        document.getElementById('pod-count').textContent = '2';
    }
}

// Update uptime display
function updateUptime() {
    const elapsed = Date.now() - startTime;
    const seconds = Math.floor(elapsed / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    
    let display;
    if (hours > 0) {
        display = `${hours}h ${minutes % 60}m`;
    } else if (minutes > 0) {
        display = `${minutes}m ${seconds % 60}s`;
    } else {
        display = `${seconds}s`;
    }
    
    document.getElementById('uptime').textContent = display;
}

// Add smooth scroll
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        document.querySelector(this.getAttribute('href')).scrollIntoView({
            behavior: 'smooth'
        });
    });
});

