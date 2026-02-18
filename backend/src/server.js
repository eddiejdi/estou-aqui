require('dotenv').config();

const express = require('express');
const path = require('path');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const http = require('http');
const { Server } = require('socket.io');

const { sequelize } = require('./models');
const authRoutes = require('./routes/auth');
const eventRoutes = require('./routes/events');
const checkinRoutes = require('./routes/checkins');
const chatRoutes = require('./routes/chat');
const estimateRoutes = require('./routes/estimates');
const notificationRoutes = require('./routes/notifications');
const alertRoutes = require('./routes/alerts');
const telegramGroupRoutes = require('./routes/telegram-groups');
const betaSignupRoutes = require('./routes/beta-signup');
const coalitionRoutes = require('./routes/coalitions');
const webchatRoutes = require('./routes/webchat');
const setupSocket = require('./services/socket');
const setupAlertSocket = require('./services/alert-socket');
const AlertingService = require('./services/alerting');

// Expor métricas Prometheus via prom-client
let promClient;
try {
  promClient = require('prom-client');
  // coletar métricas padrão (CPU, heap etc.)
  promClient.collectDefaultMetrics({ timeout: 5000 });
} catch (err) {
  console.warn('prom-client not available - metrics endpoint disabled');
}

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
});

// Middleware
app.use(helmet({
  crossOriginOpenerPolicy: { policy: 'same-origin-allow-popups' },
  crossOriginEmbedderPolicy: false,
  contentSecurityPolicy: false,
}));
app.use(cors({
  origin: '*',
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
// Morgan: log detalhado em dev, compacto em produção
if (process.env.NODE_ENV === 'production') {
  app.use(morgan('combined', {
    skip: (req) => req.url === '/health', // não logar health checks
  }));
} else {
  app.use(morgan('dev'));
}
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Disponibilizar io para as rotas
app.set('io', io);

// Inicializar AlertingService
const alertingService = new AlertingService(io);
app.set('alertingService', alertingService);

// Rotas
app.use('/api/auth', authRoutes);
app.use('/api/events', eventRoutes);
app.use('/api/checkins', checkinRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/estimates', estimateRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/alerts', alertRoutes);
app.use('/api/telegram-groups', telegramGroupRoutes);
app.use('/api/beta-signup', betaSignupRoutes);
app.use('/api/coalitions', coalitionRoutes);
app.use('/api/webchat', webchatRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString(), service: 'estou-aqui-api' });
});

// Metrics endpoint (Prometheus)
if (promClient) {
  app.get('/metrics', async (req, res) => {
    try {
      res.set('Content-Type', promClient.register.contentType);
      const body = await promClient.register.metrics();
      res.send(body);
    } catch (err) {
      res.status(500).send(err.message);
    }
  });
}

// Servir arquivos estáticos do Flutter web build
const publicPath = path.join(__dirname, '..', 'public');
app.use(express.static(publicPath));

// 404 para rotas da API
app.use('/api', (req, res) => {
  res.status(404).json({ error: 'Rota não encontrada' });
});

// SPA fallback — rotas não-API servem index.html (Flutter web)
app.use((req, res) => {
  const indexPath = path.join(publicPath, 'index.html');
  res.sendFile(indexPath, (err) => {
    if (err) {
      res.status(404).json({ error: 'Rota não encontrada' });
    }
  });
});

// Error handler
app.use((err, req, res, _next) => {
  console.error('Erro:', err);
  res.status(err.status || 500).json({
    error: process.env.NODE_ENV === 'production' ? 'Erro interno' : err.message,
  });
});

// Socket.IO
setupSocket(io);
setupAlertSocket(io);

const PORT = process.env.PORT || 3000;

async function start() {
  try {
    await sequelize.authenticate();
    console.log('✅ Banco de dados conectado');

    await sequelize.sync({ alter: process.env.NODE_ENV === 'development' });
    console.log('✅ Modelos sincronizados');

    server.listen(PORT, () => {
      console.log(`🚀 Estou Aqui API rodando na porta ${PORT}`);
    });
  } catch (error) {
    console.error('❌ Falha ao iniciar servidor:', error);
    process.exit(1);
  }
}

// Start only when executed directly. This prevents the server from auto-listening during tests
if (require.main === module && process.env.NODE_ENV !== 'test') {
  start();
}

module.exports = { app, server, io, start };
