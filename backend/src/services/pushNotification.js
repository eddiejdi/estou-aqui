const admin = require('firebase-admin');
const { Notification, User } = require('../models');

let firebaseInitialized = false;

function initFirebase() {
  if (firebaseInitialized) return;
  if (!process.env.FIREBASE_PROJECT_ID) {
    console.warn('⚠️ Firebase não configurado — push notifications desabilitadas');
    return;
  }

  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    }),
  });
  firebaseInitialized = true;
}

class PushNotificationService {
  /**
   * Envia notificação push para um usuário
   */
  static async sendToUser(userId, { title, body, type, data = {} }) {
    try {
      // Salvar no banco
      const notification = await Notification.create({
        userId,
        title,
        body,
        type,
        data,
        sentAt: new Date(),
      });

      // Enviar via Firebase
      const user = await User.findByPk(userId);
      if (user?.fcmToken) {
        initFirebase();
        if (firebaseInitialized) {
          await admin.messaging().send({
            token: user.fcmToken,
            notification: { title, body },
            data: { ...data, notificationId: notification.id, type },
            android: { priority: 'high' },
            apns: { payload: { aps: { sound: 'default', badge: 1 } } },
          });
        }
      }

      return notification;
    } catch (error) {
      console.error('Erro ao enviar push:', error);
      return null;
    }
  }

  /**
   * Notifica todos os participantes de um evento
   */
  static async notifyEventParticipants(eventId, { title, body, type, data = {} }) {
    const { Checkin } = require('../models');
    const checkins = await Checkin.findAll({
      where: { eventId, isActive: true },
      attributes: ['userId'],
    });

    const userIds = [...new Set(checkins.map((c) => c.userId))];
    const results = await Promise.allSettled(
      userIds.map((userId) => this.sendToUser(userId, { title, body, type, data: { ...data, eventId } })),
    );

    const sent = results.filter((r) => r.status === 'fulfilled' && r.value).length;
    console.log(`📤 Notificações enviadas: ${sent}/${userIds.length}`);
    return { sent, total: userIds.length };
  }

  /**
   * Notifica usuários próximos de um novo evento
   */
  static async notifyNearbyUsers(event, radiusKm = 50) {
    const radiusDeg = radiusKm / 111;
    const { Op } = require('sequelize');
    const users = await User.findAll({
      where: {
        latitude: { [Op.between]: [event.latitude - radiusDeg, event.latitude + radiusDeg] },
        longitude: { [Op.between]: [event.longitude - radiusDeg, event.longitude + radiusDeg] },
        fcmToken: { [Op.not]: null },
      },
    });

    for (const user of users) {
      await this.sendToUser(user.id, {
        title: '📍 Novo evento próximo a você!',
        body: `${event.title} — ${event.address || event.city || 'Ver no mapa'}`,
        type: 'event_nearby',
        data: { eventId: event.id },
      });
    }

    return { notified: users.length };
  }
}

module.exports = PushNotificationService;
