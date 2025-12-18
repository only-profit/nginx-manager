#!/bin/bash

# ===========================================
# Server Proxy Manager - Setup Script
# ===========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  Server Proxy Manager - Setup${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if running as root or with sudo
check_permissions() {
    if [ "$EUID" -ne 0 ]; then
        print_warning "Script is not running as root. Some operations may require sudo."
    fi
}

# Check Docker installation
check_docker() {
    print_info "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed!"
        echo "Please install Docker first: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running!"
        echo "Please start Docker service: sudo systemctl start docker"
        exit 1
    fi
    
    print_success "Docker is installed and running"
}

# Check Docker Compose installation
check_docker_compose() {
    print_info "Checking Docker Compose installation..."
    
    # Check for docker compose (v2) or docker-compose (v1)
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
        print_success "Docker Compose v2 is installed"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
        print_success "Docker Compose v1 is installed"
    else
        print_error "Docker Compose is not installed!"
        echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
}

# Check if ports are available
check_ports() {
    print_info "Checking port availability..."
    
    local ports_in_use=()
    
    for port in 80 443 81; do
        if ss -tuln 2>/dev/null | grep -q ":$port " || netstat -tuln 2>/dev/null | grep -q ":$port "; then
            ports_in_use+=($port)
        fi
    done
    
    if [ ${#ports_in_use[@]} -gt 0 ]; then
        print_warning "The following ports are already in use: ${ports_in_use[*]}"
        echo ""
        echo "Processes using these ports:"
        for port in "${ports_in_use[@]}"; do
            echo "Port $port:"
            sudo lsof -i :$port 2>/dev/null || ss -tlnp 2>/dev/null | grep ":$port " || true
            echo ""
        done
        
        read -p "Do you want to continue anyway? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo "To free up ports, you can:"
            echo "  - Stop existing nginx: sudo systemctl stop nginx"
            echo "  - Stop other containers: docker stop <container_name>"
            echo "  - Kill process on port: sudo fuser -k 80/tcp"
            exit 1
        fi
    else
        print_success "Ports 80, 443, and 81 are available"
    fi
}

# Create Docker network
create_network() {
    print_info "Creating Docker network 'proxy-network'..."
    
    if docker network ls | grep -q "proxy-network"; then
        print_success "Network 'proxy-network' already exists"
    else
        docker network create proxy-network
        print_success "Network 'proxy-network' created"
    fi
}

# Create .env file
create_env_file() {
    print_info "Setting up environment file..."
    
    if [ -f ".env" ]; then
        print_warning ".env file already exists, skipping..."
    else
        cp .env.example .env
        print_success ".env file created from template"
    fi
}

# Create data directories
create_directories() {
    print_info "Creating data directories..."
    
    mkdir -p data
    mkdir -p letsencrypt
    
    print_success "Data directories created"
}

# Start services
start_services() {
    print_info "Starting Nginx Proxy Manager..."
    
    $COMPOSE_CMD up -d
    
    # Wait for container to be healthy
    echo "Waiting for service to be ready..."
    sleep 5
    
    # Check if container is running
    if docker ps | grep -q "nginx-proxy-manager"; then
        print_success "Nginx Proxy Manager is running"
    else
        print_error "Failed to start Nginx Proxy Manager"
        echo "Check logs with: docker logs nginx-proxy-manager"
        exit 1
    fi
}

# Print completion message
print_completion() {
    # Get server IP
    SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "YOUR_SERVER_IP")
    
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}  Setup Complete!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo -e "${BLUE}Admin Panel:${NC}"
    echo "  URL:      http://${SERVER_IP}:81"
    echo ""
    echo -e "${BLUE}Default Credentials:${NC}"
    echo "  Email:    admin@example.com"
    echo "  Password: changeme"
    echo ""
    echo -e "${YELLOW}⚠ IMPORTANT: Change your password immediately after first login!${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "  1. Open the Admin Panel URL in your browser"
    echo "  2. Login with default credentials"
    echo "  3. Change your password"
    echo "  4. Add your first proxy host"
    echo ""
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  View logs:     docker logs -f nginx-proxy-manager"
    echo "  Stop:          $COMPOSE_CMD down"
    echo "  Restart:       $COMPOSE_CMD restart"
    echo "  Update:        $COMPOSE_CMD pull && $COMPOSE_CMD up -d"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo "  - README.md in this directory"
    echo "  - examples/ folder for integration examples"
    echo "  - https://nginxproxymanager.com/guide/"
    echo ""
}

# Main execution
main() {
    print_header
    check_permissions
    check_docker
    check_docker_compose
    check_ports
    create_network
    create_env_file
    create_directories
    start_services
    print_completion
}

# Run main function
main "$@"

