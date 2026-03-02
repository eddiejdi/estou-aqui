/* eslint-env jest */
const request = require('supertest');

jest.mock('axios');
const axios = require('axios');
// Ensure publish resolves in tests so alerting._publishToBus logs success path
axios.post = jest.fn().mockResolvedValue({ data: { message_id: 'msg_test' } });

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

    // Verify we attempted to publish to the agent bus (fallback candidate should be tried)
    expect(axios.post).toHaveBeenCalled();
    const calledUrl = axios.post.mock.calls[0][0];
    expect(calledUrl).toMatch(/communication\/publish$/);
    // should attempt host-gateway candidate when AGENT_BUS_URL is not configured
    expect(calledUrl).toMatch(/(172\.17\.0\.1:8503|127\.0\.0\.1:8503|localhost:8503)/);
  });
});
