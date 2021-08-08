import fs from 'fs'
import path from 'path'

import axios from 'axios'

// version
let version = 'dev'
try {
  version = fs.readFileSync(path.join(__dirname, '..', 'builtInfo.txt'), 'utf8')
} catch (err) {
  if (err.code !== 'ENOENT') throw err
}

// environment variables
const privateBackendUrl =
  process.env.PRIVATE_BACKEND_URL || 'https://duckduckgo.com'

// handlers
module.exports = {
  version: async (req: any, res: any) => {
    await res
      .status(200)
      .json({ version: version, serverTimeUTC: new Date().toISOString() })
  },
  spec: async (req: any, res: any) => {
    await res.status(200).sendFile(path.join(__dirname, '..', 'openapi.yaml'))
  },
  docs: async (req: any, res: any) => {
    await res.status(200).send(`
      <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <script type="module" src="https://unpkg.com/rapidoc/dist/rapidoc-min.js"></script>
        </head>
        <body>
          <rapi-doc
            spec-url = "/spec"
            theme = "dark"
            show-header = "false"
          ></rapi-doc>
        </body>
        </html>`)
  },
  dnsServers: async (req: any, res: any) => {
    await res.status(200).sendFile('/etc/resolv.conf')
  },
  toBackend: async (req: any, res: any) => {
    await axios
      .get(privateBackendUrl)
      .then((beRes) => {
        res.status(200).json({
          connectedUrl: privateBackendUrl,
          resolvedIp: beRes.request.socket.remoteAddress
        })
      })
      .catch((beErr) => {
        res.status(400).json({
          connectedUrl: privateBackendUrl,
          resolvedIp: beErr.request.socket.remoteAddress,
          errors: beErr
        })
      })
  }
}
