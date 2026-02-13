#!/bin/bash

sudo systemctl stop mern-backend-api 2>/dev/null || true
sleep 2

sudo fuser -k 8000/tcp 2>/dev/null || true
sleep 2

# Also kill any stray node processes
sudo pkill -f "node.*mern-backend-api" 2>/dev/null || true
sleep 2

echo "🚀 DEPLOYING MERN BACKEND API"
echo "=============================="

APP_NAME="mern-backend-api"
APP_DIR="/var/www/$APP_NAME"
PORT=8000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check Node.js version
print_status "Checking Node.js version..."
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 16 ]; then
    print_error "Node.js version $NODE_VERSION too old. Need 16+"
    print_status "Installing Node.js 18..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
else
    print_status "Node.js version: $(node -v)"
fi

# Check MongoDB
print_status "Checking MongoDB..."
if ! systemctl is-active --quiet mongodb; then
    print_warning "MongoDB not running. Starting..."
    sudo systemctl start mongodb
    sudo systemctl enable mongodb
fi
print_status "MongoDB is running"

# Create app directory
print_status "Creating application directory..."
sudo mkdir -p $APP_DIR
sudo chown -R $USER:$USER $APP_DIR

# Copy application files (excluding node_modules and .git)
print_status "Copying application files..."
rsync -av --progress . $APP_DIR --exclude node_modules --exclude .git --exclude .env > /dev/null

# Install dependencies
cd $APP_DIR
print_status "Installing dependencies..."
npm install

# Check if build script exists and run it
if grep -q '"build"' package.json; then
    print_status "Building application..."
    npm run build
fi

# Create .env file (from template or environment)
print_status "Creating environment configuration..."
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        print_warning "Created .env from .env.example - please update with real values!"
    else
        cat > .env << EOL
PORT=$PORT
NODE_ENV=production
MONGODB_URI=mongodb://localhost:27017/mern
JWT_SECRET=$(openssl rand -hex 32)
JWT_EXPIRE=30d
API_URL=http://localhost:$PORT
EOL
        print_status "Generated random JWT_SECRET"
    fi
fi

# Test application
print_status "Testing application..."
node dist/index.js 2>/dev/null || node src/index.js 2>/dev/null || node index.js &
TEST_PID=$!
sleep 5

if curl -s http://localhost:$PORT/api/users > /dev/null 2>&1; then
    print_status "✅ Application test PASSED!"
    kill $TEST_PID 2>/dev/null
else
    print_warning "Test endpoint not available, but server started"
    kill $TEST_PID 2>/dev/null
fi

NODE_PATH=$(which node)
cat > /tmp/mern-service << EOS
[Unit]
Description=MERN Backend API
After=network.target mongodb.service
Wants=mongodb.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
ExecStart=$NODE_PATH $APP_DIR/dist/index.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=JWT_SECRET=5703b4c2f13349d6acc06fde801882c4e2fee69033b8a6b4362ffbec519d82ed

[Install]
WantedBy=multi-user.target
EOS

sudo mv /tmp/mern-service /etc/systemd/system/$APP_NAME.service


# Start service
print_status "Starting service..."
sudo systemctl daemon-reload
sudo systemctl enable $APP_NAME
sudo systemctl restart $APP_NAME

# Wait for service to start
sleep 3

# Verify service is running
if sudo systemctl is-active --quiet $APP_NAME; then
    print_status "✅ SERVICE IS RUNNING!"
    
    # Show service status
    sudo systemctl status $APP_NAME --no-pager | head -10
    
    # Test endpoints
    echo ""
    print_status "Testing API endpoints:"
  
    # Try different endpoints
    ENDPOINTS=("/api/users" "/" "/api/health" "/api")
    for endpoint in "${ENDPOINTS[@]}"; do
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT$endpoint)
        if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "201" ]; then
            print_status "✅ $endpoint - $RESPONSE OK"
        elif [ "$RESPONSE" = "404" ]; then
            print_warning "$endpoint - $RESPONSE Not Found (may need auth)"
        else
            print_warning "$endpoint - $RESPONSE"
        fi
    done
    
else
    print_error "❌ Service failed to start"
    sudo journalctl -u $APP_NAME -n 50 --no-pager
    exit 1
fi

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "================================="
echo "📁 Location: $APP_DIR"
echo "🌐 API URL: http://localhost:$PORT/"
echo "📋 Logs: sudo journalctl -u $APP_NAME -f"
echo "================================="

# Print helpful commands
echo ""
print_status "Useful commands:"
echo "  View logs:        sudo journalctl -u $APP_NAME -f"
echo "  Restart service:  sudo systemctl restart $APP_NAME"
echo "  Check status:     sudo systemctl status $APP_NAME"
echo "  Test API:         curl http://localhost:$PORT/api/users"
echo "================================="
