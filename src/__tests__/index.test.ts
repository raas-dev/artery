import { spawn, ChildProcess } from 'child_process'
import axios, { AxiosInstance } from 'axios'
import waitOn from 'wait-on'

jest.setTimeout(15000)

const serverPort = 8080

describe('HTTP endpoint tests', () => {
  let start: ChildProcess
  let client: AxiosInstance

  beforeAll(async () => {
    client = axios.create({
      baseURL: `http://localhost:${serverPort}`,
      validateStatus: () => true
    })
    const env = process.env
    env.SWAGGER_STATS_USERNAME = 'local'
    env.SWAGGER_STATS_PASSWORD = 'local'
    start = spawn('npm', ['start'], {
      cwd: __dirname,
      env,
      detached: true,
      stdio: 'inherit'
    })
    await waitOn({ resources: ['tcp:localhost:8080'] })
  })

  afterAll(() => {
    if (typeof start.pid !== 'undefined') {
      process.kill(-start.pid)
    }
  })

  test('GET to / responds 200', async () => {
    const res = await client.get('/')
    expect(res.status).toBe(200)
  })

  test('GET to /favicon.ico responds 200', async () => {
    const res = await client.get('/favicon.ico')
    expect(res.status).toBe(200)
  })

  test('GET to /stats responds 200', async () => {
    const res = await client.get('/stats')
    expect(res.status).toBe(200)
  })

  test('GET to non-implemented responds 501', async () => {
    const res = await client.get('/users')
    expect(res.status).toBe(501)
  })

  test('GET to non-existing responds 404', async () => {
    const res = await client.get('/not-found')
    expect(res.status).toBe(404)
  })
})
