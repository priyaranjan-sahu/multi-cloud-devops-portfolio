#!/bin/bash
set -euo pipefail

INSTANCE_NAME="${instance_name}"
LOG_FILE="/var/log/user-data.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$(date)] Starting user data script for $INSTANCE_NAME"

# Update system
yum update -y

# Install required packages
yum install -y httpd amazon-cloudwatch-agent aws-cli

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWEOF'
{
  "metrics": {
    "namespace": "DevOpsPortfolio",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_iowait"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["used_percent"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "/devops-portfolio/httpd/access",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "/devops-portfolio/httpd/error",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
CWEOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

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
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; color: white; }
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
        <p class="subtitle">Infrastructure deployed with Terraform on LocalStack</p>
        
        <div class="info-grid">
            <div class="info-card">
                <h3>Instance</h3>
                <p id="instance-id">Loading...</p>
            </div>
            <div class="info-card">
                <h3>Availability Zone</h3>
                <p id="az">Loading...</p>
            </div>
            <div class="info-card">
                <h3>Instance Type</h3>
                <p id="instance-type">Loading...</p>
            </div>
            <div class="info-card">
                <h3>Local IPv4</h3>
                <p id="local-ip">Loading...</p>
            </div>
        </div>

        <div style="margin-top: 2rem;">
            <span class="badge">AWS</span>
            <span class="badge">Terraform</span>
            <span class="badge">LocalStack</span>
            <span class="badge">DevOps</span>
            <span class="badge">Portfolio</span>
        </div>

        <div class="footer">
            <p>Deployed via <strong>Terraform</strong> • Running on <strong>LocalStack</strong> • Part of <a href="https://github.com/priyaranjan-sahu/multi-cloud-devops-portfolio" style="color: #a0c4ff;">multi-cloud-devops-portfolio</a></p>
        </div>
    </div>

    <script>
        async function fetchMetadata() {
            try {
                const tokenResp = await fetch('http://169.254.169.254/latest/api/token', {
                    method: 'PUT',
                    headers: { 'X-aws-ec2-metadata-token-ttl-seconds': '21600' }
                });
                const token = await tokenResp.text();
                
                const headers = { 'X-aws-ec2-metadata-token': token };
                
                const [instanceId, az, instanceType, localIp] = await Promise.all([
                    fetch('http://169.254.169.254/latest/meta-data/instance-id', { headers }).then(r => r.text()),
                    fetch('http://169.254.169.254/latest/meta-data/placement/availability-zone', { headers }).then(r => r.text()),
                    fetch('http://169.254.169.254/latest/meta-data/instance-type', { headers }).then(r => r.text()),
                    fetch('http://169.254.169.254/latest/meta-data/local-ipv4', { headers }).then(r => r.text())
                ]);
                
                document.getElementById('instance-id').textContent = instanceId;
                document.getElementById('az').textContent = az;
                document.getElementById('instance-type').textContent = instanceType;
                document.getElementById('local-ip').textContent = localIp;
            } catch (e) {
                document.querySelectorAll('.info-card p').forEach(p => p.textContent = 'Running on LocalStack (mock metadata)');
            }
        }
        fetchMetadata();
    </script>
</body>
</html>
HTMLEOF

# Start and enable httpd
systemctl enable httpd
systemctl start httpd

# Verify service is running
sleep 5
if systemctl is-active --quiet httpd; then
    echo "[$(date)] httpd started successfully"
else
    echo "[$(date)] ERROR: httpd failed to start"
    systemctl status httpd
fi

echo "[$(date)] User data script completed for $INSTANCE_NAME"