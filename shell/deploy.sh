#!/bin/bash

# 设置项目目录、Git 仓库 URL 和分支名称
PROJECT_DIR="/app/api-gateway/"
LOG_DIR="/app/log/"
GIT_REPO="https://github.com/lifengdi/node-api-gateway.git"

# 检查是否提供了分支名称参数，如果没有则使用默认分支 main
if [ -z "$1" ]; then
    BRANCH_NAME="main"
    echo "No branch name provided. Using default branch: $BRANCH_NAME" | tee -a $LOG_FILE
else
    BRANCH_NAME="$1"
fi
echo "Current branch name is: $BRANCH_NAME" | tee -a $LOG_FILE

TIMESTAMP=$(date +"%Y%m%d%H%M%S")
LOG_FILE="$LOG_DIR/deploy_$TIMESTAMP.log"

# 创建项目目录（如果不存在）
mkdir -p $PROJECT_DIR
mkdir -p $LOG_DIR

# 进入项目目录
cd $PROJECT_DIR || exit

# 记录开始时间
echo "Deployment started at $(date)" | tee -a $LOG_FILE

# 检查并安装 Node.js 和 npm
if ! command -v npm &> /dev/null; then
    echo "npm could not be found, installing Node.js and npm..." | tee -a $LOG_FILE
    # 使用包管理器安装 Node.js 和 npm
    if command -v apt-get &> /dev/null; then
        sudo apt-get update 2>&1 | tee -a $LOG_FILE
        sudo apt-get install -y nodejs npm 2>&1 | tee -a $LOG_FILE
    elif command -v yum &> /dev/null; then
        sudo yum install -y nodejs npm 2>&1 | tee -a $LOG_FILE
    elif command -v brew &> /dev/null; then
        brew install node 2>&1 | tee -a $LOG_FILE
    else
        echo "No package manager found to install Node.js and npm. Please install them manually." | tee -a $LOG_FILE
        exit 1
    fi
    # 检查安装是否成功
    if ! command -v npm &> /dev/null; then
        echo "Failed to install Node.js and npm." | tee -a $LOG_FILE
        exit 1
    fi
fi

# 检查并安装 pm2
if ! command -v pm2 &> /dev/null; then
    echo "pm2 could not be found, installing pm2..." | tee -a $LOG_FILE
    npm install -g pm2 2>&1 | tee -a $LOG_FILE
    # 检查安装是否成功
    if ! command -v pm2 &> /dev/null; then
        echo "Failed to install pm2." | tee -a $LOG_FILE
        exit 1
    fi
fi

# 设置 pm2 开机自启
echo "Setting up pm2 to start on boot..." | tee -a $LOG_FILE
sudo env PATH=$PATH:/usr/bin /usr/local/bin/pm2 startup systemd -u $(whoami) --hp /home/$(whoami) 2>&1 | tee -a $LOG_FILE
if [ $? -ne 0 ]; then
    echo "Failed to set up pm2 startup." | tee -a $LOG_FILE
    exit 1
fi

# 克隆代码仓库（如果目录为空）
if [ ! -d "$PROJECT_DIR/.git" ]; then
    echo "Cloning repository from branch $BRANCH_NAME..." | tee -a $LOG_FILE
    git clone -b $BRANCH_NAME $GIT_REPO . 2>&1 | tee -a $LOG_FILE
    if [ $? -ne 0 ]; then
        echo "Failed to clone repository." | tee -a $LOG_FILE
        exit 1
    fi
else
    echo "Repository already exists, pulling latest changes from branch $BRANCH_NAME..." | tee -a $LOG_FILE
    git checkout $BRANCH_NAME 2>&1 | tee -a $LOG_FILE
    git pull origin $BRANCH_NAME 2>&1 | tee -a $LOG_FILE
    if [ $? -ne 0 ]; then
        echo "Failed to pull latest changes." | tee -a $LOG_FILE
        exit 1
    fi
fi

# 检查 package.json 是否存在
if [ ! -f "$PROJECT_DIR/package.json" ]; then
    echo "package.json not found in the project directory." | tee -a $LOG_FILE
    exit 1
fi

# 安装依赖
echo "Installing dependencies..." | tee -a $LOG_FILE
npm install 2>&1 | tee -a $LOG_FILE
if [ $? -ne 0 ]; then
    echo "Failed to install dependencies." | tee -a $LOG_FILE
    exit 1
fi

# 构建项目（如果有构建步骤）
# echo "Building project..." | tee -a $LOG_FILE
# npm run build 2>&1 | tee -a $LOG_FILE
# if [ $? -ne 0 ]; then
#     echo "Failed to build project." | tee -a $LOG_FILE
#     exit 1
# fi

# 检查是否存在 api-gateway 进程
if pm2 list | grep -q "api-gateway"; then
    echo "Stopping existing pm2 processes..." | tee -a $LOG_FILE
    pm2 stop api-gateway 2>&1 | tee -a $LOG_FILE
else
    echo "No existing pm2 process named 'api-gateway' found. Skipping stop command." | tee -a $LOG_FILE
fi

# 启动服务
echo "Starting service with pm2..." | tee -a $LOG_FILE
pm2 start src/index.js --name api-gateway 2>&1 | tee -a $LOG_FILE
if [ $? -ne 0 ]; then
    echo "Failed to start service with pm2." | tee -a $LOG_FILE
    exit 1
fi

# 保存 pm2 进程列表
echo "Saving pm2 process list..." | tee -a $LOG_FILE
pm2 save 2>&1 | tee -a $LOG_FILE

# 记录结束时间
echo "Deployment completed at $(date)" | tee -a $LOG_FILE

# 输出日志
# echo "Deployment log:"
# cat $LOG_FILE
