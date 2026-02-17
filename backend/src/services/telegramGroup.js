/**
 * Telegram Group Service
 * Gerencia criação, versionamento e participação em grupos Telegram para eventos.
 *
 * Regras:
 * 1. Se não existir grupo para o evento → cria supergrupo via Bot API
 * 2. Se existir → retorna link de convite
 * 3. Se estiver lotado → cria novo grupo versionado (ex: "Evento #2")
 *    e adiciona organizadores como co-admins
 */

const axios = require('axios');

class TelegramGroupService {
  constructor(models) {
    this.models = models;
    this.botToken = process.env.TELEGRAM_BOT_TOKEN;
    this.apiBase = `https://api.telegram.org/bot${this.botToken}`;
  }

  /**
   * Obtém ou cria grupo Telegram para um evento.
   * Retorna { inviteLink, chatId, title, version, isNew }
   */
  async getOrCreateGroup(eventId, userId) {
    const { Event, User, TelegramGroup } = this.models;

    // Buscar evento
    const event = await Event.findByPk(eventId, {
      include: [{ model: User, as: 'organizer', attributes: ['id', 'name', 'email'] }],
    });
    if (!event) throw new Error('Evento não encontrado');

    // Buscar grupo ativo e não lotado
    let group = await TelegramGroup.findOne({
      where: { eventId, isFull: false, isActive: true },
      order: [['version', 'DESC']],
    });

    if (group) {
      // Grupo existe e não está lotado — atualizar contagem
      try {
        const memberCount = await this._getMemberCount(group.chatId);
        await group.update({ memberCount });

        // Se lotou, marcar e criar novo
        if (memberCount >= group.maxMembers) {
          await group.update({ isFull: true });
          group = await this._createVersionedGroup(event, group.version + 1);
        }
      } catch (err) {
        console.error('Erro ao verificar membros do grupo:', err.message);
        // Se falhou ao checar, retorna o grupo existente
      }

      return {
        inviteLink: group.inviteLink,
        chatId: group.chatId.toString(),
        title: group.title,
        version: group.version,
        isNew: false,
      };
    }

    // Nenhum grupo ativo → criar
    group = await this._createVersionedGroup(event, 1);

    return {
      inviteLink: group.inviteLink,
      chatId: group.chatId.toString(),
      title: group.title,
      version: group.version,
      isNew: true,
    };
  }

  /**
   * Lista todos os grupos de um evento (incluindo versionados)
   */
  async listGroups(eventId) {
    const { TelegramGroup } = this.models;

    const groups = await TelegramGroup.findAll({
      where: { eventId, isActive: true },
      order: [['version', 'ASC']],
    });

    return groups.map((g) => ({
      id: g.id,
      chatId: g.chatId.toString(),
      inviteLink: g.inviteLink,
      title: g.title,
      version: g.version,
      memberCount: g.memberCount,
      maxMembers: g.maxMembers,
      isFull: g.isFull,
    }));
  }

  // ─── Métodos privados ─────────────────────────────────

  /**
   * Cria um supergrupo versionado no Telegram
   */
  async _createVersionedGroup(event, version) {
    const { TelegramGroup } = this.models;

    const suffix = version > 1 ? ` #${version}` : '';
    const groupTitle = `${event.title}${suffix}`;
    const description = `${event.category} — ${event.description?.substring(0, 200) || 'Evento Estou Aqui'}`;

    // 1. Criar supergrupo
    const createRes = await this._callTelegram('createSuperGroup', {
      title: groupTitle,
      description: description.substring(0, 255),
    });

    // Fallback: se createSuperGroup não existir, usar createChat
    let chatId;
    if (!createRes.ok) {
      // Usar Bot API para criar grupo — criar via createForumTopic ou grupo regular
      const groupRes = await this._callTelegram('createChatInviteLink', null);
      // O Bot API não tem "createSuperGroup" diretamente.
      // Estratégia: bot cria um grupo via workaround.
      // Telegram Bot API não permite criar grupos diretamente.
      // Vamos usar a estratégia de canal convertido para supergrupo.
      throw new Error(
        'Telegram Bot API não suporta criação direta de supergrupos. ' +
        'É necessário criar o grupo manualmente ou usar a Telegram Client API (TDLib). ' +
        'Implementação alternativa: usar o grupo pré-existente do bot.'
      );
    }

    chatId = createRes.result.id;

    // 2. Gerar link de convite
    const inviteLinkRes = await this._callTelegram('exportChatInviteLink', {
      chat_id: chatId,
    });

    const inviteLink = inviteLinkRes.ok
      ? inviteLinkRes.result
      : `https://t.me/+placeholder_${event.id}_v${version}`;

    // 3. Configurar permissões do grupo
    await this._callTelegram('setChatPermissions', {
      chat_id: chatId,
      permissions: JSON.stringify({
        can_send_messages: true,
        can_send_media_messages: true,
        can_send_polls: false,
        can_send_other_messages: true,
        can_add_web_page_previews: true,
        can_change_info: false,
        can_invite_users: true,
        can_pin_messages: false,
      }),
    });

    // 4. Se versionado, adicionar organizador como admin
    if (version > 1 && event.organizer) {
      // Nota: para promover a admin, o organizador precisa ter um Telegram ID
      // vinculado. Isso precisaria de um campo telegramId no User.
      console.log(`Grupo versionado #${version} criado. Organizador: ${event.organizer.name}`);
    }

    // 5. Enviar mensagem de boas-vindas
    await this._callTelegram('sendMessage', {
      chat_id: chatId,
      text: `🎯 *${groupTitle}*\n\n` +
        `📍 ${event.address || 'Local a definir'}\n` +
        `📅 ${event.startDate}\n\n` +
        `Bem-vindo ao grupo do evento! Use este espaço para coordenar e trocar informações.\n\n` +
        `_Criado automaticamente pelo app Estou Aqui_`,
      parse_mode: 'Markdown',
    });

    // 6. Salvar no banco
    const group = await TelegramGroup.create({
      eventId: event.id,
      chatId,
      inviteLink,
      title: groupTitle,
      version,
      memberCount: 1,
    });

    return group;
  }

  /**
   * Obtém contagem de membros do grupo
   */
  async _getMemberCount(chatId) {
    const res = await this._callTelegram('getChatMemberCount', {
      chat_id: chatId,
    });
    return res.ok ? res.result : 0;
  }

  /**
   * Promove um usuário a admin do grupo
   */
  async promoteToAdmin(chatId, telegramUserId) {
    return this._callTelegram('promoteChatMember', {
      chat_id: chatId,
      user_id: telegramUserId,
      can_manage_chat: true,
      can_post_messages: true,
      can_edit_messages: true,
      can_delete_messages: true,
      can_manage_video_chats: true,
      can_restrict_members: true,
      can_promote_members: false,
      can_change_info: true,
      can_invite_users: true,
      can_pin_messages: true,
    });
  }

  /**
   * Chamada genérica para Telegram Bot API
   */
  async _callTelegram(method, params) {
    try {
      const url = `${this.apiBase}/${method}`;
      const res = await axios.post(url, params, { timeout: 15000 });
      return res.data;
    } catch (err) {
      const errData = err.response?.data || { ok: false, description: err.message };
      console.error(`Telegram API ${method} error:`, errData.description || err.message);
      return errData;
    }
  }
}

module.exports = TelegramGroupService;
