require('dotenv').config();

const express = require('express');
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
const setupSocket = require('./services/socket');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Disponibilizar io para as rotas
app.set('io', io);

// Rotas
app.use('/api/auth', authRoutes);
app.use('/api/events', eventRoutes);
app.use('/api/checkins', checkinRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/estimates', estimateRoutes);
app.use('/api/notifications', notificationRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString(), service: 'estou-aqui-api' });
});

// 404
app.use((req, res) => {
  res.status(404).json({ error: 'Rota não encontrada' });
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

start();

module.exports = { app, server, io };
