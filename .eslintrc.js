module.exports = {
  env: {
    'jest/globals': true
  },
  extends: [
    'standard'
  ],
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: '2017',
    sourceType: 'module'
  },
  plugins: [
    'jest',
    '@typescript-eslint'
  ],
  rules: {
  }
}
