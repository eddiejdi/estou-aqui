/* eslint-env jest */
const request = require('supertest');

jest.mock('axios');
const axios = require('axios');

// Mock the models to avoid real DB connection when server starts
jest.mock('../../src/models', () => ({
  sequelize: {
    authenticate: jest.fn().mockResolvedValue(),
    sync: jest.fn().mockResolvedValue(),
  },
  Sequelize: {},
  User: {},
  Event: {},
  Checkin: {},
  ChatMessage: {},
  CrowdEstimate: {},
  Notification: {},
}));

// Ensure metrics register is clear between tests
afterEach(() => {
  try {
    const promClient = require('prom-client');
    promClient.register.clear();
  } catch (err) {
    // ignore
  }
});

describe('POST /api/alerts/grafana-webhook', () => {
  let app;

  beforeAll(() => {
    const server = require('../../src/server');
    app = server.app;
  });

  it('should accept Grafana webhook and publish to bus', async () => {
    const payload = {
      title: 'High memory usage',
      ruleName: 'HighMemoryUsage',
      state: 'alerting',
      message: 'Memory > 90%',
      evalMatches: [{ metric: 'memory_total', value: 93, tags: { instance: 'homelab' }, time: new Date().toISOString() }],
      tags: { severity: 'critical' },
      ruleUrl: 'http://grafana/alert/1'
    };

    const res = await request(app)
      .post('/api/alerts/grafana-webhook')
      .set('Content-Type', 'application/json')
      .send(payload)
      .expect(200);

    expect(res.body).toHaveProperty('status', 'received');
    expect(res.body).toHaveProperty('processed');

    const alertingService = app.get('alertingService');
    const active = alertingService.getActiveAlerts();
    console.log('DEBUG activeAlerts (test):', active);
    expect(active.some(a => a.name === 'HighMemoryUsage' || a.name === 'High memory usage')).toBe(true);
  });
});
