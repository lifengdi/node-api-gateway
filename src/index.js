const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const axios = require('axios');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8080;

// 定义默认请求头
const defaultHeaders = {
    'X-APP-PACKAGE-NAME': 'your_default_package_name' // 根据需要添加其他默认请求头
};

// // 全局中间件，为所有请求添加默认请求头
app.use((req, res, next) => {
    req.headers['X-API-GATEWAY'] = 'NODE-1.0';
    next();
});


// 代理 /api/app-api 到 http://app-service:4000
app.use(
    '/api/app-api',
    createProxyMiddleware({
        target: 'http://app-service:4000',
        changeOrigin: true,
        pathRewrite: {
            '^/': '/api/app-api/',
        },
        on: {
            proxyReq: (proxyReq, req, res) => {
                // 检查并添加默认请求头
                Object.keys(defaultHeaders).forEach(key => {
                    if (!proxyReq.getHeader(key)) {
                        proxyReq.setHeader(key, defaultHeaders[key]);
                    }
                });
                // 添加自定义请求头
                // proxyReq.setHeader('X-APP-PACKAGE-NAME', 'werq.asdf');
                console.log('onProxyReq called for /api/app-api');
                console.log('Headers being sent to target:', proxyReq.getHeaders());
            },
        },
    })
);

// 代理 /api/products 到 http://products-service:4000
app.use(
    '/api/products',
    createProxyMiddleware({
        target: 'http://products-service:4000',
        changeOrigin: true,
        pathRewrite: {
            '^/api/products': '', // 重写路径，去掉 /api/products 前缀
        },
    })
);

// 新增接口，接收 HTTP 地址并返回状态码
app.get('/get-status-code', async (req, res) => {
    const url = req.query.url;
    if (!url) {
        return res.status(400).send('URL parameter is required');
    }

    try {
        const response = await axios.head(url); // 使用 HEAD 请求获取状态码
        res.send({ statusCode: response.status });
    } catch (error) {
        if (error.response) {
            // 请求已发出，但服务器响应的状态码不在 2xx 范围内
            res.send({ statusCode: error.response.status });
        } else if (error.request) {
            // 请求已发出，但没有收到响应
            res.status(500).send('No response received from the server');
        } else {
            // 在设置请求时发生了一些事情，触发了错误
            res.status(500).send('Error setting up the request');
        }
    }
});

// 启动服务器
app.listen(PORT, () => {
    console.log(`API Gateway running on port ${PORT}`);
});
