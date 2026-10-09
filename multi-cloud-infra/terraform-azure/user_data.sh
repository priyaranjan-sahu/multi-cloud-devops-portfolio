#!/bin/bash
set -euo pipefail

INSTANCE_NAME="${instance_name}"
LOG_FILE="/var/log/user-data.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$(date)] Starting user data script for $INSTANCE_NAME"

# Update system
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y nginx curl jq

# Create health check endpoint
cat > /var/www/html/health << 'HTMLEOF'
OK
HTMLEOF

# Create sample application page
cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DevOps Portfolio - Multi-Cloud Demo</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: linear-gradient(135deg, #0062bc 0%, #0078d4 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; color: white; }
        .container { text-align: center; padding: 2rem; max-width: 800px; }
        h1 { font-size: 3rem; margin-bottom: 1rem; background: linear-gradient(90deg, #fff, #a0c4ff); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
        .subtitle { font-size: 1.5rem; margin-bottom: 2rem; opacity: 0.9; }
        .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1.5rem; margin-top: 2rem; }
        .info-card { background: rgba(255,255,255,0.1); border-radius: 12px; padding: 1.5rem; backdrop-filter: blur(10px); border: 1px solid rgba(255,255,255,0.2); }
        .info-card h3 { font-size: 1.2rem; margin-bottom: 0.5rem; color: #a0c4ff; }
        .info-card p { font-size: 1rem; opacity: 0.8; }
        .badge { display: inline-block; background: rgba(255,255,255,0.2); padding: 0.3rem 0.8rem; border-radius: 20px; font-size: 0.85rem; margin: 0.2rem; }
        .footer { margin-top: 3rem; padding-top: 2rem; border-top: 1px solid rgba(255,255,255,0.1); opacity: 0.6; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Multi-Cloud DevOps Portfolio</h1>
        <p class="subtitle">Infrastructure deployed with Terraform on Azure</p>
        
        <div class="info-grid">
            <div class="info-card">
                <h3>VM Name</h3>
                <p id="vm-name">Loading...</p>
            </div>
            <div class="info-card">
                <h3>Resource Group</h3>
                <p id="resource-group">Loading...</p>
            </div>
            <div class="info-card">
                <h3>Location</h3>
                <p id="location">Loading...</p>
            </div>
            <div class="info-card">
                <h3>Private IP</h3>
                <p id="private-ip">Loading...</p>
            </div>
        </div>

        <div style="margin-top: 2rem;">
            <span class="badge">Azure</span>
            <span class="badge">Terraform</span>
            <span class="badge">DevOps</span>
            <span class="badge">Portfolio</span>
        </div>

        <div class="footer">
            <p>Deployed via <strong>Terraform</strong> • Running on <strong>Azure</strong> • Part of <a href="https://github.com/priyaranjan-sahu/multi-cloud-devops-portfolio" style="color: #a0c4ff;">multi-cloud-devops-portfolio</a></p>
        </div>
    </div>

    <script>
        async function fetchMetadata() {
            try {
                const metadataUrl = 'http://169.254.169.254/metadata/instance?api-version=2021-02-01';
                const resp = await fetch(metadataUrl, {
                    headers: { 'Metadata': 'true' }
                });
                const data = await resp.json();
                
                document.getElementById('vm-name').textContent = data.compute.name;
                document.getElementById('resource-group').textContent = data.compute.resourceGroupName;
                document.getElementById('location').textContent = data.compute.location;
                document.getElementById('private-ip').textContent = data.network.interface[0].ipv4.ipAddress[0].privateIpAddress;
            } catch (e) {
                document.querySelectorAll('.info-card p').forEach(p => p.textContent = 'Running on Azure (metadata unavailable locally)');
            }
        }
        fetchMetadata();
    </script>
</body>
</html>
HTMLEOF

# Start and enable nginx
systemctl enable nginx
systemctl start nginx

# Verify service is running
sleep 5
if systemctl is-active --quiet nginx; then
    echo "[$(date)] nginx started successfully"
else
    echo "[$(date)] ERROR: nginx failed to start"
    systemctl status nginx
fi

echo "[$(date)] User data script completed for $INSTANCE_NAME"