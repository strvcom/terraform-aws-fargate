const express = require('express')
const os = require('os')

const hostname = os.hostname()
const app = express()

app.listen(3000, () => console.log(`Example app listening on port 3000! Host: ${hostname}`))

app.get('/', async (req, res) => res.json({
  hostname,
  message: 'Look mommy, I\'m using HTTPS!'
}))
