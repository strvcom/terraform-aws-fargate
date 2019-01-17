'use strict'

const https = require('https')
const { URL } = require('url')

module.exports.handler = async (event, context, cb) => {
  const { detail, region } = event
  const { pipeline, state } = detail

  const slackChannel = process.env.SLACK_CHANNEL
  const slackWebhookUrl = new URL(process.env.SLACK_WEBHOOK_URL)
  const slackUsername = process.env.SLACK_USERNAME

  const payload = {
    channel: slackChannel,
    username: slackUsername,
    text: 'Fargate Module reporter - New CodePipeline State',
    attachments: [],
  }

  const notification = buildNotification(pipeline, state, region)
  payload.attachments.push(notification)

  const stringifiedPayload = JSON.stringify(payload)

  const options = {
    host: slackWebhookUrl.host,
    path: slackWebhookUrl.pathname,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(stringifiedPayload)
    },
    port: 443,
  }

  return new Promise((resolve, reject) => {
    const req = https.request(options, () => {
      return resolve()
    })

    req.on('error', (e) => {
      return reject(e)
    })

    req.write(stringifiedPayload)
    req.end()
  }).then(cb).catch(cb)
}

function buildNotification(pipeline, state, region) {
  const colors = {
    SUCCEEDED: 'good',
    STARTED: '#2178DA', // blue-ish
    FAILED: 'danger',
    CANCELED: 'warning',
  }

  return {
    color: colors[state] || 'nothing',
    fallback: `${pipeline} new state: ${state}`,
    fields: [{
      title: "Pipeline name",
      value: pipeline,
      short: true,
    }, {
      title: "State",
      value: state,
      short: true,
    }, {
      title: "Link to pipeline",
      value: `https://console.aws.amazon.com/codesuite/codepipeline/pipelines/${pipeline}/view?region=${region}`,
      short: false,
    }]
  }
}
