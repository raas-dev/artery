import fs from 'fs'
import path from 'path'

import express from 'express'
import favicon from 'serve-favicon'
import Helmet from 'helmet'
import morgan from 'morgan'
import swaggerStats from 'swagger-stats'
import * as OpenApiValidator from 'express-openapi-validator'

// environment variables
const instrumentationKey = process.env.APPINSIGHTS_INSTRUMENTATIONKEY
const serverPort = process.env.WEBSITES_PORT || 8080
const swaggerStatsUsername = process.env.SWAGGER_STATS_USERNAME
const swaggerStatsPassword = process.env.SWAGGER_STATS_PASSWORD

// https://docs.microsoft.com/en-us/azure/azure-monitor/app/nodejs
if (instrumentationKey) {
  const appInsights = require('applicationinsights')
  appInsights
    .setup(instrumentationKey)
    .setAutoCollectConsole(true, true)
    .setSendLiveMetrics(true)
    .start()
}

// setup Express
const app = express()
app.use(Helmet())
app.use(favicon(path.join(__dirname, 'favicon.ico')))
app.use(express.json())

// logging - https://github.com/expressjs/morgan#options
app.use(morgan('combined'))

// monitoring - https://github.com/slanatech/swagger-stats
if (swaggerStatsUsername && swaggerStatsPassword) {
  app.use(
    swaggerStats.getMiddleware({
      swaggerSpec: fs.readFileSync(path.join(__dirname, '..', 'openapi.yaml')),
      uriPath: '/stats',
      authentication: true,
      onAuthenticate: function (_: any, username: string, password: string) {
        return (
          username === swaggerStatsUsername && password === swaggerStatsPassword
        )
      }
    })
  )
}

// routing - https://github.com/cdimascio/express-openapi-validator
app.use(
  OpenApiValidator.middleware({
    apiSpec: path.join(__dirname, '..', 'openapi.yaml'),
    operationHandlers: path.join(__dirname),
    validateRequests: {
      allowUnknownQueryParameters: false,
      removeAdditional: true
    },
    validateResponses: {
      onError: (error, body, req) => {
        console.log('Response body fails validation: ', error)
        console.log('Emitted from:', req.originalUrl)
        console.debug(body)
      }
    },
    validateFormats: 'full' // default: "fast"
  })
)

// default handler for not implemented
app.get('/*', async (req: any, res: any) => {
  await res.status(501).json({ error: 'Not implemented' })
})

// generic handler for errors
app.use(async (err: any, req: any, res: any, next: any) => {
  await res.status(err.status || 500).json({
    message: err.message,
    errors: err.errors
  })
})

// start the server
app
  .listen(serverPort, () =>
    console.info(`API listening at http://localhost:${serverPort}`)
  )
  .on('error', function (err) {
    return console.log(`Could not start API: ${err}`)
  })
