const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const { User } = require('../models');
const { auth } = require('../middleware/auth');

const router = express.Router();

// POST /api/auth/register
router.post('/register', [
  body('name').trim().isLength({ min: 2, max: 100 }).withMessage('Nome deve ter 2-100 caracteres'),
  body('email').isEmail().normalizeEmail().withMessage('Email inválido'),
  body('password').isLength({ min: 6 }).withMessage('Senha deve ter no mínimo 6 caracteres'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { name, email, password } = req.body;

    const existing = await User.findOne({ where: { email } });
    if (existing) {
      return res.status(409).json({ error: 'Email já cadastrado' });
    }

    const hashedPassword = await bcrypt.hash(password, 12);
    const user = await User.create({ name, email, password: hashedPassword });

    const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, {
      expiresIn: process.env.JWT_EXPIRES_IN || '7d',
    });

    res.status(201).json({
      token,
      user: { id: user.id, name: user.name, email: user.email, role: user.role },
    });
  } catch (error) {
    console.error('Erro no registro:', error);
    res.status(500).json({ error: 'Erro interno ao registrar' });
  }
});

// POST /api/auth/login
router.post('/login', [
  body('email').isEmail().normalizeEmail(),
  body('password').notEmpty(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { email, password } = req.body;
    const user = await User.findOne({ where: { email } });

    if (!user || !user.isActive) {
      return res.status(401).json({ error: 'Credenciais inválidas' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Credenciais inválidas' });
    }

    const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, {
      expiresIn: process.env.JWT_EXPIRES_IN || '7d',
    });

    res.json({
      token,
      user: { id: user.id, name: user.name, email: user.email, role: user.role, avatar: user.avatar },
    });
  } catch (error) {
    console.error('Erro no login:', error);
    res.status(500).json({ error: 'Erro interno ao fazer login' });
  }
});

// POST /api/auth/google
router.post('/google', [
  body('idToken').notEmpty().withMessage('idToken é obrigatório'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { idToken } = req.body;

    // Verificar o token com Google
    const { OAuth2Client } = require('google-auth-library');
    const client = new OAuth2Client();
    let payload;
    try {
      const ticket = await client.verifyIdToken({
        idToken,
        audience: process.env.GOOGLE_CLIENT_ID,
      });
      payload = ticket.getPayload();
    } catch (verifyErr) {
      return res.status(401).json({ error: 'Token Google inválido' });
    }

    const { sub: googleId, email, name, picture } = payload;

    // Buscar ou criar usuário
    let user = await User.findOne({ where: { googleId } });
    if (!user) {
      user = await User.findOne({ where: { email } });
      if (user) {
        // Vincular conta existente ao Google
        await user.update({ googleId, authProvider: 'google', avatar: picture || user.avatar });
      } else {
        // Criar novo usuário
        user = await User.create({
          name: name || email.split('@')[0],
          email,
          googleId,
          authProvider: 'google',
          avatar: picture,
        });
      }
    }

    const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, {
      expiresIn: process.env.JWT_EXPIRES_IN || '7d',
    });

    res.json({
      token,
      user: { id: user.id, name: user.name, email: user.email, role: user.role, avatar: user.avatar },
    });
  } catch (error) {
    console.error('Erro no login Google:', error);
    res.status(500).json({ error: 'Erro interno ao fazer login com Google' });
  }
});

// POST /api/auth/google-access-token
// Fallback para web quando idToken não está disponível
router.post('/google-access-token', [
  body('accessToken').notEmpty().withMessage('accessToken é obrigatório'),
  body('email').isEmail().withMessage('email é obrigatório'),
  body('name').optional().trim(),
  body('avatar').optional().trim(),
  body('googleId').optional().trim(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { accessToken, email, name, avatar, googleId } = req.body;

    // Verificar accessToken chamando a API de userinfo do Google
    let googleProfile;
    try {
      const response = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      if (!response.ok) {
        return res.status(401).json({ error: 'Access token Google inválido' });
      }
      googleProfile = await response.json();
    } catch (fetchErr) {
      console.error('Erro ao verificar access token:', fetchErr);
      return res.status(401).json({ error: 'Não foi possível verificar o access token' });
    }

    // Usar dados do Google profile (mais confiável) com fallback para dados enviados
    const verifiedEmail = googleProfile.email || email;
    const verifiedName = googleProfile.name || name || verifiedEmail.split('@')[0];
    const verifiedAvatar = googleProfile.picture || avatar;
    const verifiedGoogleId = googleProfile.sub || googleId;

    // Buscar ou criar usuário
    let user = null;
    if (verifiedGoogleId) {
      user = await User.findOne({ where: { googleId: verifiedGoogleId } });
    }
    if (!user) {
      user = await User.findOne({ where: { email: verifiedEmail } });
      if (user) {
        await user.update({ 
          googleId: verifiedGoogleId || user.googleId, 
          authProvider: 'google', 
          avatar: verifiedAvatar || user.avatar 
        });
      } else {
        user = await User.create({
          name: verifiedName,
          email: verifiedEmail,
          googleId: verifiedGoogleId,
          authProvider: 'google',
          avatar: verifiedAvatar,
        });
      }
    }

    const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, {
      expiresIn: process.env.JWT_EXPIRES_IN || '7d',
    });

    res.json({
      token,
      user: { id: user.id, name: user.name, email: user.email, role: user.role, avatar: user.avatar },
    });
  } catch (error) {
    console.error('Erro no login Google (access token):', error);
    res.status(500).json({ error: 'Erro interno ao fazer login com Google' });
  }
});

// GET /api/auth/me
router.get('/me', auth, async (req, res) => {
  res.json({
    user: {
      id: req.user.id,
      name: req.user.name,
      email: req.user.email,
      avatar: req.user.avatar,
      bio: req.user.bio,
      role: req.user.role,
    },
  });
});

// PUT /api/auth/profile
router.put('/profile', auth, [
  body('name').optional().trim().isLength({ min: 2, max: 100 }),
  body('bio').optional().trim().isLength({ max: 500 }),
], async (req, res) => {
  try {
    const { name, bio, avatar } = req.body;
    const updates = {};
    if (name) updates.name = name;
    if (bio !== undefined) updates.bio = bio;
    if (avatar) updates.avatar = avatar;

    await req.user.update(updates);
    res.json({ user: { id: req.user.id, name: req.user.name, email: req.user.email, bio: req.user.bio, avatar: req.user.avatar } });
  } catch (error) {
    console.error('Erro ao atualizar perfil:', error);
    res.status(500).json({ error: 'Erro ao atualizar perfil' });
  }
});

// PUT /api/auth/fcm-token
router.put('/fcm-token', auth, async (req, res) => {
  try {
    const { fcmToken } = req.body;
    await req.user.update({ fcmToken });
    res.json({ message: 'Token FCM atualizado' });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao atualizar token FCM' });
  }
});

module.exports = router;
