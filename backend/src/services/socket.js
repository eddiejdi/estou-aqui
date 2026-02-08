const jwt = require('jsonwebtoken');

/**
 * Configura Socket.IO para comunicação em tempo real
 * - Chat por evento
 * - Atualizações de check-in em tempo real
 * - Atualizações de estimativa de público
 */
function setupSocket(io) {
  // Middleware de autenticação para Socket.IO
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    if (!token) {
      return next(new Error('Token não fornecido'));
    }

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId = decoded.id;
      next();
    } catch {
      next(new Error('Token inválido'));
    }
  });

  io.on('connection', (socket) => {
    console.log(`📱 Usuário conectado: ${socket.userId}`);

    // Entrar na sala de um evento
    socket.on('event:join', (eventId) => {
      socket.join(`event:${eventId}`);
      console.log(`👤 ${socket.userId} entrou no evento ${eventId}`);

      // Notificar outros participantes
      socket.to(`event:${eventId}`).emit('participant:joined', {
        userId: socket.userId,
        eventId,
      });
    });

    // Sair da sala de um evento
    socket.on('event:leave', (eventId) => {
      socket.leave(`event:${eventId}`);
      console.log(`👤 ${socket.userId} saiu do evento ${eventId}`);
    });

    // Enviar mensagem de chat (alternativa ao REST)
    socket.on('chat:send', async (data) => {
      const { eventId, content, type = 'text' } = data;
      try {
        const { ChatMessage, User } = require('../models');
        const message = await ChatMessage.create({
          userId: socket.userId,
          eventId,
          content,
          type,
        });

        const fullMessage = await ChatMessage.findByPk(message.id, {
          include: [{ model: User, as: 'user', attributes: ['id', 'name', 'avatar'] }],
        });

        io.to(`event:${eventId}`).emit('chat:message', fullMessage);
      } catch (error) {
        socket.emit('error', { message: 'Erro ao enviar mensagem' });
      }
    });

    // Atualizar localização em tempo real
    socket.on('location:update', (data) => {
      const { eventId, latitude, longitude } = data;
      socket.to(`event:${eventId}`).emit('location:updated', {
        userId: socket.userId,
        latitude,
        longitude,
      });
    });

    // Typing indicator
    socket.on('chat:typing', ({ eventId }) => {
      socket.to(`event:${eventId}`).emit('chat:typing', { userId: socket.userId });
    });

    socket.on('disconnect', () => {
      console.log(`📴 Usuário desconectado: ${socket.userId}`);
    });
  });

  return io;
}

module.exports = setupSocket;
