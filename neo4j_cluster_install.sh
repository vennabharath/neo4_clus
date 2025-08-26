#!/bin/bash

# Neo4j Cluster Installation Script
# This script installs and configures a Neo4j cluster with core and read replica servers
# Usage: ./install_neo4j_cluster.sh <num_core_servers> <num_read_replica_servers>

set -euo pipefail

# Configuration variables
NEO4J_VERSION="5.15.0"
NEO4J_HOME="/opt/neo4j"
NEO4J_USER="neo4j"
NEO4J_GROUP="neo4j"
CLUSTER_NAME="neo4j-cluster"
INITIAL_PASSWORD="neo4j-admin"
CORE_PORT_BASE=7687
READ_REPLICA_PORT_BASE=8687
HTTP_PORT_BASE=7474
HTTPS_PORT_BASE=7473
BACKUP_PORT_BASE=6362
CLUSTER_PORT_BASE=5000
RAFT_PORT_BASE=7000

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if script is run as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root for security reasons"
        exit 1
    fi
}

# Function to validate input parameters
validate_input() {
    if [[ $# -ne 2 ]]; then
        log_error "Usage: $0 <num_core_servers> <num_read_replica_servers>"
        log_info "Example: $0 3 2"
        exit 1
    fi

    if ! [[ "$1" =~ ^[0-9]+$ ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
        log_error "Both parameters must be positive integers"
        exit 1
    fi

    if [[ $1 -lt 3 ]]; then
        log_error "Minimum 3 core servers required for proper clustering"
        exit 1
    fi

    if [[ $1 -gt 10 ]] || [[ $2 -gt 10 ]]; then
        log_warning "Large cluster detected. Ensure sufficient resources are available"
    fi
}

# Function to detect OS and package manager
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        log_error "Cannot detect OS. This script supports Ubuntu/Debian and RHEL/CentOS"
        exit 1
    fi

    log_info "Detected OS: $OS $VER"
}

# Function to install Java 17 (required for Neo4j 5.x)
install_java() {
    log_info "Installing Java 17..."
    
    if command -v java &> /dev/null; then
        JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
        if [[ "$JAVA_VERSION" -ge 17 ]]; then
            log_success "Java 17+ is already installed"
            return
        fi
    fi

    case "$OS" in
        *"Ubuntu"*|*"Debian"*)
            sudo apt-get update
            sudo apt-get install -y openjdk-17-jdk
            ;;
        *"CentOS"*|*"Red Hat"*|*"Rocky"*|*"AlmaLinux"*)
            sudo yum install -y java-17-openjdk-devel
            ;;
        *)
            log_error "Unsupported OS for automatic Java installation"
            exit 1
            ;;
    esac

    log_success "Java 17 installed successfully"
}

# Function to create Neo4j user and group
create_neo4j_user() {
    log_info "Creating Neo4j user and group..."
    
    if id "$NEO4J_USER" &>/dev/null; then
        log_info "User $NEO4J_USER already exists"
    else
        sudo groupadd -r $NEO4J_GROUP 2>/dev/null || true
        sudo useradd -r -g $NEO4J_GROUP -d $NEO4J_HOME -s /bin/bash $NEO4J_USER
        log_success "Created user $NEO4J_USER"
    fi
}

# Function to download and install Neo4j
install_neo4j() {
    log_info "Downloading and installing Neo4j $NEO4J_VERSION..."
    
    cd /tmp
    NEO4J_PACKAGE="neo4j-enterprise-${NEO4J_VERSION}-unix.tar.gz"
    
    if [[ ! -f "$NEO4J_PACKAGE" ]]; then
        log_info "Downloading Neo4j Enterprise..."
        wget -q "https://neo4j.com/artifact.php?name=${NEO4J_PACKAGE}" -O "$NEO4J_PACKAGE"
    fi
    
    sudo mkdir -p $NEO4J_HOME
    sudo tar -xzf "$NEO4J_PACKAGE" -C /opt/
    sudo mv "/opt/neo4j-enterprise-${NEO4J_VERSION}" "$NEO4J_HOME/current"
    sudo chown -R $NEO4J_USER:$NEO4J_GROUP $NEO4J_HOME
    sudo chmod -R 755 $NEO4J_HOME
    
    # Create symlinks for easier management
    sudo ln -sf $NEO4J_HOME/current/bin/neo4j /usr/local/bin/neo4j
    sudo ln -sf $NEO4J_HOME/current/bin/neo4j-admin /usr/local/bin/neo4j-admin
    
    log_success "Neo4j installed successfully"
}

# Function to configure firewall
configure_firewall() {
    log_info "Configuring firewall rules..."
    
    # Check if ufw is available (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        sudo ufw --force enable
        # Allow SSH
        sudo ufw allow ssh
        # Allow Neo4j ports range
        sudo ufw allow 7687:7697/tcp  # Bolt protocol
        sudo ufw allow 7474:7484/tcp  # HTTP
        sudo ufw allow 7473:7483/tcp  # HTTPS
        sudo ufw allow 5000:5010/tcp  # Cluster communication
        sudo ufw allow 7000:7010/tcp  # Raft protocol
        sudo ufw allow 6362:6372/tcp  # Backup
        log_success "UFW firewall configured"
    elif command -v firewall-cmd &> /dev/null; then
        sudo systemctl enable firewalld
        sudo systemctl start firewalld
        # Allow Neo4j ports
        for port in $(seq 7687 7697); do sudo firewall-cmd --permanent --add-port=${port}/tcp; done
        for port in $(seq 7474 7484); do sudo firewall-cmd --permanent --add-port=${port}/tcp; done
        for port in $(seq 7473 7483); do sudo firewall-cmd --permanent --add-port=${port}/tcp; done
        for port in $(seq 5000 5010); do sudo firewall-cmd --permanent --add-port=${port}/tcp; done
        for port in $(seq 7000 7010); do sudo firewall-cmd --permanent --add-port=${port}/tcp; done
        for port in $(seq 6362 6372); do sudo firewall-cmd --permanent --add-port=${port}/tcp; done
        sudo firewall-cmd --reload
        log_success "Firewalld configured"
    else
        log_warning "No supported firewall found. Please configure manually."
    fi
}

# Function to get server IP
get_server_ip() {
    # Try to get the primary network interface IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+')
    fi
    echo "$SERVER_IP"
}

# Function to generate core server configuration
generate_core_config() {
    local server_id=$1
    local total_cores=$2
    local server_ip=$(get_server_ip)
    
    local bolt_port=$((CORE_PORT_BASE + server_id - 1))
    local http_port=$((HTTP_PORT_BASE + server_id - 1))
    local https_port=$((HTTPS_PORT_BASE + server_id - 1))
    local cluster_port=$((CLUSTER_PORT_BASE + server_id - 1))
    local raft_port=$((RAFT_PORT_BASE + server_id - 1))
    
    cat > "$NEO4J_HOME/current/conf/neo4j.conf" << EOF
# Neo4j Core Server $server_id Configuration
# Generated on $(date)

# Database mode
dbms.mode=CORE

# Server identification
dbms.default_database=neo4j
dbms.memory.heap.initial_size=2G
dbms.memory.heap.max_size=4G
dbms.memory.pagecache.size=2G

# Network connector configuration
dbms.connectors.default_listen_address=0.0.0.0
dbms.connectors.default_advertised_address=$server_ip

# Bolt connector
dbms.connector.bolt.enabled=true
dbms.connector.bolt.listen_address=0.0.0.0:$bolt_port
dbms.connector.bolt.advertised_address=$server_ip:$bolt_port

# HTTP connector
dbms.connector.http.enabled=true
dbms.connector.http.listen_address=0.0.0.0:$http_port
dbms.connector.http.advertised_address=$server_ip:$http_port

# HTTPS connector
dbms.connector.https.enabled=true
dbms.connector.https.listen_address=0.0.0.0:$https_port
dbms.connector.https.advertised_address=$server_ip:$https_port

# Cluster configuration
causal_clustering.expected_core_cluster_size=$total_cores
causal_clustering.initial_discovery_members=$(generate_discovery_members $total_cores)
causal_clustering.discovery_listen_address=0.0.0.0:$cluster_port
causal_clustering.discovery_advertised_address=$server_ip:$cluster_port
causal_clustering.transaction_listen_address=0.0.0.0:$raft_port
causal_clustering.transaction_advertised_address=$server_ip:$raft_port
causal_clustering.raft_listen_address=0.0.0.0:$raft_port
causal_clustering.raft_advertised_address=$server_ip:$raft_port

# Security
dbms.security.auth_enabled=true
dbms.security.procedures.unrestricted=jwt.*,apoc.*

# Logging
dbms.logs.query.enabled=true
dbms.logs.query.threshold=1s

# Performance tuning
dbms.tx_log.rotation.retention_policy=100M size
dbms.checkpoint.interval.time=30s

# JVM tuning
dbms.jvm.additional=-XX:+UseG1GC
dbms.jvm.additional=-XX:+UnlockExperimentalVMOptions
dbms.jvm.additional=-XX:+UseCGroupMemoryLimitForHeap

# Allow upgrade
dbms.allow_upgrade=true

# Enable metrics
metrics.enabled=true
metrics.csv.enabled=true
metrics.csv.interval=30s
EOF

    log_success "Generated configuration for Core Server $server_id"
}

# Function to generate read replica configuration
generate_replica_config() {
    local server_id=$1
    local total_cores=$2
    local server_ip=$(get_server_ip)
    
    local bolt_port=$((READ_REPLICA_PORT_BASE + server_id - 1))
    local http_port=$((HTTP_PORT_BASE + 10 + server_id - 1))
    local https_port=$((HTTPS_PORT_BASE + 10 + server_id - 1))
    local cluster_port=$((CLUSTER_PORT_BASE + 10 + server_id - 1))
    
    cat > "$NEO4J_HOME/current/conf/neo4j.conf" << EOF
# Neo4j Read Replica Server $server_id Configuration
# Generated on $(date)

# Database mode
dbms.mode=READ_REPLICA

# Server identification
dbms.default_database=neo4j
dbms.memory.heap.initial_size=1G
dbms.memory.heap.max_size=2G
dbms.memory.pagecache.size=1G

# Network connector configuration
dbms.connectors.default_listen_address=0.0.0.0
dbms.connectors.default_advertised_address=$server_ip

# Bolt connector
dbms.connector.bolt.enabled=true
dbms.connector.bolt.listen_address=0.0.0.0:$bolt_port
dbms.connector.bolt.advertised_address=$server_ip:$bolt_port

# HTTP connector
dbms.connector.http.enabled=true
dbms.connector.http.listen_address=0.0.0.0:$http_port
dbms.connector.http.advertised_address=$server_ip:$http_port

# HTTPS connector
dbms.connector.https.enabled=true
dbms.connector.https.listen_address=0.0.0.0:$https_port
dbms.connector.https.advertised_address=$server_ip:$https_port

# Cluster configuration
causal_clustering.initial_discovery_members=$(generate_discovery_members $total_cores)
causal_clustering.discovery_listen_address=0.0.0.0:$cluster_port
causal_clustering.discovery_advertised_address=$server_ip:$cluster_port

# Security
dbms.security.auth_enabled=true
dbms.security.procedures.unrestricted=jwt.*,apoc.*

# Logging
dbms.logs.query.enabled=true
dbms.logs.query.threshold=1s

# Performance tuning
dbms.tx_log.rotation.retention_policy=50M size

# JVM tuning
dbms.jvm.additional=-XX:+UseG1GC
dbms.jvm.additional=-XX:+UnlockExperimentalVMOptions
dbms.jvm.additional=-XX:+UseCGroupMemoryLimitForHeap

# Allow upgrade
dbms.allow_upgrade=true

# Enable metrics
metrics.enabled=true
metrics.csv.enabled=true
metrics.csv.interval=30s
EOF

    log_success "Generated configuration for Read Replica Server $server_id"
}

# Function to generate discovery members list
generate_discovery_members() {
    local total_cores=$1
    local members=""
    
    # This assumes you'll replace these IPs with actual server IPs
    for i in $(seq 1 $total_cores); do
        local port=$((CLUSTER_PORT_BASE + i - 1))
        if [[ $i -eq 1 ]]; then
            members="server${i}:${port}"
        else
            members="${members},server${i}:${port}"
        fi
    done
    
    echo "$members"
}

# Function to create systemd service
create_systemd_service() {
    log_info "Creating systemd service..."
    
    sudo tee /etc/systemd/system/neo4j.service > /dev/null << EOF
[Unit]
Description=Neo4j Graph Database
After=network.target
Wants=network.target

[Service]
ExecStart=$NEO4J_HOME/current/bin/neo4j console
Restart=on-failure
User=$NEO4J_USER
Group=$NEO4J_GROUP
Environment=NEO4J_HOME=$NEO4J_HOME/current
Environment=NEO4J_CONF=$NEO4J_HOME/current/conf
LimitNOFILE=60000
TimeoutSec=120

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable neo4j
    log_success "Systemd service created and enabled"
}

# Function to set initial password
set_initial_password() {
    log_info "Setting initial password..."
    
    # Wait for Neo4j to start
    sleep 10
    
    sudo -u $NEO4J_USER $NEO4J_HOME/current/bin/neo4j-admin dbms set-initial-password "$INITIAL_PASSWORD" || true
    log_success "Initial password set to: $INITIAL_PASSWORD"
}

# Function to create monitoring script
create_monitoring_script() {
    log_info "Creating cluster monitoring script..."
    
    cat > "$NEO4J_HOME/cluster_monitor.sh" << 'EOF'
#!/bin/bash

# Neo4j Cluster Monitoring Script
NEO4J_HOME="/opt/neo4j/current"
LOG_FILE="/var/log/neo4j/cluster_monitor.log"

check_cluster_status() {
    echo "$(date): Checking cluster status..." >> $LOG_FILE
    
    # Check if Neo4j is running
    if ! pgrep -f "neo4j" > /dev/null; then
        echo "$(date): ERROR - Neo4j is not running!" >> $LOG_FILE
        sudo systemctl start neo4j
        return 1
    fi
    
    # Check cluster health via HTTP API
    local http_port=$(grep "dbms.connector.http.listen_address" $NEO4J_HOME/conf/neo4j.conf | cut -d':' -f2)
    local health_check=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${http_port}/db/manage/server/core/available" || echo "000")
    
    if [[ "$health_check" == "200" ]]; then
        echo "$(date): Cluster status OK" >> $LOG_FILE
        return 0
    else
        echo "$(date): WARNING - Cluster health check failed (HTTP $health_check)" >> $LOG_FILE
        return 1
    fi
}

# Run the check
check_cluster_status
EOF

    chmod +x "$NEO4J_HOME/cluster_monitor.sh"
    chown $NEO4J_USER:$NEO4J_GROUP "$NEO4J_HOME/cluster_monitor.sh"
    
    # Add to crontab for regular monitoring
    (crontab -u $NEO4J_USER -l 2>/dev/null; echo "*/5 * * * * $NEO4J_HOME/cluster_monitor.sh") | sudo -u $NEO4J_USER crontab -
    
    log_success "Monitoring script created and scheduled"
}

# Function to display cluster information
display_cluster_info() {
    local num_cores=$1
    local num_replicas=$2
    local server_ip=$(get_server_ip)
    
    log_success "Neo4j Cluster Installation Complete!"
    echo
    echo "=== Cluster Configuration ==="
    echo "Core Servers: $num_cores"
    echo "Read Replica Servers: $num_replicas"
    echo "Server IP: $server_ip"
    echo "Initial Password: $INITIAL_PASSWORD"
    echo
    echo "=== Connection Information ==="
    echo "Bolt Protocol: bolt://$server_ip:7687"
    echo "HTTP Interface: http://$server_ip:7474"
    echo "HTTPS Interface: https://$server_ip:7473"
    echo
    echo "=== Important Notes ==="
    echo "1. Update /etc/hosts on all servers with actual hostnames and IPs"
    echo "2. Replace 'server1', 'server2', etc. in discovery members with actual hostnames"
    echo "3. Ensure all servers can communicate on the configured ports"
    echo "4. Change the initial password after first login"
    echo "5. Configure SSL certificates for production use"
    echo
    echo "=== Useful Commands ==="
    echo "Start Neo4j: sudo systemctl start neo4j"
    echo "Stop Neo4j: sudo systemctl stop neo4j"
    echo "Status: sudo systemctl status neo4j"
    echo "Logs: sudo journalctl -u neo4j -f"
    echo "Admin CLI: neo4j-admin"
    echo
}

# Main execution function
main() {
    log_info "Starting Neo4j Cluster Installation"
    
    # Validate input
    validate_input "$@"
    NUM_CORES=$1
    NUM_REPLICAS=$2
    
    log_info "Installing cluster with $NUM_CORES core servers and $NUM_REPLICAS read replicas"
    
    # Check prerequisites
    check_root
    detect_os
    
    # Installation steps
    install_java
    create_neo4j_user
    install_neo4j
    configure_firewall
    
    # Prompt user for server type
    echo
    log_info "Select server type for this machine:"
    echo "1) Core Server"
    echo "2) Read Replica Server"
    read -p "Enter choice (1 or 2): " server_type
    
    case $server_type in
        1)
            read -p "Enter core server ID (1-$NUM_CORES): " server_id
            if [[ $server_id -ge 1 ]] && [[ $server_id -le $NUM_CORES ]]; then
                generate_core_config $server_id $NUM_CORES
            else
                log_error "Invalid server ID"
                exit 1
            fi
            ;;
        2)
            read -p "Enter replica server ID (1-$NUM_REPLICAS): " server_id
            if [[ $server_id -ge 1 ]] && [[ $server_id -le $NUM_REPLICAS ]]; then
                generate_replica_config $server_id $NUM_CORES
            else
                log_error "Invalid server ID"
                exit 1
            fi
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
    
    # Create systemd service
    create_systemd_service
    
    # Create monitoring
    create_monitoring_script
    
    # Start Neo4j
    log_info "Starting Neo4j service..."
    sudo systemctl start neo4j
    
    # Set initial password
    set_initial_password
    
    # Display information
    display_cluster_info $NUM_CORES $NUM_REPLICAS
    
    log_success "Installation completed successfully!"
}

# Execute main function with all arguments
main "$@"