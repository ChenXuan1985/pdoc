// ============================================
// Lighthouse CI 配置
// 用于性能监控
// ============================================

module.exports = {
  ci: {
    collect: {
      url: [
        'https://pdoc3.github.io/pdoc/',
        'https://pdoc3.github.io/pdoc/staging/',
      ],
      numberOfRuns: 3,
      settings: {
        preset: 'desktop',
        chromeFlags: '--no-sandbox --headless',
      },
    },
    assert: {
      assertions: {
        'categories:performance': ['warn', { minScore: 0.8 }],
        'categories:accessibility': ['error', { minScore: 0.9 }],
        'categories:best-practices': ['warn', { minScore: 0.8 }],
        'categories:seo': ['warn', { minScore: 0.8 }],
        'first-contentful-paint': ['warn', { maxNumericValue: 2000 }],
        'interactive': ['warn', { maxNumericValue: 3500 }],
      },
    },
    upload: {
      target: 'temporary-public-storage',
      outputDir: './lhci-reports',
    },
  },
};
