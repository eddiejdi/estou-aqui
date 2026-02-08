const CrowdEstimationService = require('../../src/services/crowdEstimation');

// Mock dos modelos
jest.mock('../../src/models', () => ({
  Checkin: {
    count: jest.fn(),
  },
  CrowdEstimate: {
    create: jest.fn().mockResolvedValue({
      id: 'test-id',
      eventId: 'event-1',
      method: 'checkin_count',
      estimatedCount: 100,
      confidence: 0.4,
    }),
  },
}));

describe('CrowdEstimationService', () => {
  describe('jacobsMethod', () => {
    it('deve calcular estimativa por densidade baixa', () => {
      const result = CrowdEstimationService.jacobsMethod(1000, 'low');
      expect(result.estimate).toBe(500); // 1000 × 0.5
    });

    it('deve calcular estimativa por densidade média', () => {
      const result = CrowdEstimationService.jacobsMethod(1000, 'medium');
      expect(result.estimate).toBe(1500); // 1000 × 1.5
    });

    it('deve calcular estimativa por densidade alta', () => {
      const result = CrowdEstimationService.jacobsMethod(1000, 'high');
      expect(result.estimate).toBe(3000); // 1000 × 3.0
    });

    it('deve calcular estimativa por densidade muito alta', () => {
      const result = CrowdEstimationService.jacobsMethod(1000, 'very_high');
      expect(result.estimate).toBe(5000); // 1000 × 5.0
    });

    it('deve retornar range (low, estimate, high)', () => {
      const result = CrowdEstimationService.jacobsMethod(2000, 'medium');
      expect(result.low).toBeLessThan(result.estimate);
      expect(result.estimate).toBeLessThan(result.high);
    });

    it('deve lidar com área zero', () => {
      const result = CrowdEstimationService.jacobsMethod(0, 'high');
      expect(result.estimate).toBe(0);
    });
  });
});
